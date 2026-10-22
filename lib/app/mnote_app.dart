import 'package:flutter/material.dart';
import 'package:mnote/core/theme/app_theme.dart';
import 'package:mnote/features/auth/domain/auth_repository.dart';
import 'package:mnote/features/auth/presentation/app_guide_page.dart';
import 'package:mnote/features/auth/presentation/splash_page.dart';
import 'package:mnote/features/sync/data/firestore_library_store.dart';
import 'package:mnote/features/sync/data/firestore_ink_store.dart';
import 'package:mnote/features/sync/data/synced_document_repository.dart';
import 'package:mnote/features/sync/data/synced_ink_file_storage.dart';
import 'package:mnote/features/sync/domain/sync_settings.dart';
import 'package:mnote/features/workspace/data/device_document_storage.dart';
import 'package:mnote/features/workspace/data/local_document_repository.dart';
import 'package:mnote/features/workspace/data/ink_file_storage.dart';
import 'package:mnote/features/workspace/domain/document_repository.dart';
import 'package:mnote/features/workspace/presentation/ink_storage_scope.dart';
import 'package:mnote/screens/note_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MnoteApp extends StatefulWidget {
  const MnoteApp({
    super.key,
    this.documentRepository,
    this.skipAuth,
    this.home,
    this.authRepository,
    this.syncSettings,
  });

  final DocumentRepository? documentRepository;
  final bool? skipAuth;
  final Widget? home;

  /// When null, only the offline flow is available (no email login/register).
  final AuthRepository? authRepository;

  /// Cloud sync choices; defaults are used when not provided.
  final SyncSettings? syncSettings;

  /// Global notifier to switch theme mode (Light / Dark / System)
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  /// Global notifier to switch app font family
  static final ValueNotifier<AppFontFamily> fontNotifier =
      ValueNotifier<AppFontFamily>(AppFontFamily.prompt);

  /// Global notifier to switch the app accent color (blue by default)
  static final ValueNotifier<AppAccent> accentNotifier =
      ValueNotifier<AppAccent>(AppAccent.blue);

  static const _themePrefKey = 'mnote_theme_mode';

  static Future<void> loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_themePrefKey);
      if (saved != null) {
        themeModeNotifier.value = ThemeMode.values.firstWhere(
          (m) => m.name == saved,
          orElse: () => ThemeMode.system,
        );
      }
    } catch (e) {
      debugPrint('Failed to load theme mode: $e');
    }
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themePrefKey, mode.name);
    } catch (e) {
      debugPrint('Failed to save theme mode: $e');
    }
  }

  @override
  State<MnoteApp> createState() => _MnoteAppState();
}

class _MnoteAppState extends State<MnoteApp> {
  /// Local storage, mirrored to the account's cloud library when signed in
  /// through Firebase.
  DocumentRepository _defaultRepository(SyncedInkFileStorage? ink) {
    const local = LocalDocumentRepository(DeviceDocumentStorage());
    final auth = widget.authRepository;
    if (auth == null) return local;
    final repository = SyncedDocumentRepository(
      inner: local,
      store: FirestoreLibraryStore(),
      uidProvider: () => auth.currentUser?.uid,
      settings: _syncSettings,
      companions: [?ink],
    );
    ink?.policy = repository.allowsInk;
    return repository;
  }

  SyncedInkFileStorage? _syncedInk() {
    final auth = widget.authRepository;
    if (auth == null || widget.documentRepository != null) return null;
    return SyncedInkFileStorage(
      inner: const DeviceInkFileStorage(),
      store: FirestoreInkStore(),
      uidProvider: () => auth.currentUser?.uid,
    );
  }

  // Built once: they own Firestore listeners, so rebuilding the app widget
  // must not create (and leak) new ones.
  late final SyncSettings _syncSettings = widget.syncSettings ?? SyncSettings();
  late final SyncedInkFileStorage? _ink = _syncedInk();
  late final DocumentRepository _repository =
      widget.documentRepository ?? _defaultRepository(_ink);

  @override
  Widget build(BuildContext context) {
    final ink = _ink;
    final effectiveRepository = _repository;

    final destination = NoteListScreen(
      repository: effectiveRepository,
      authRepository: widget.authRepository,
    );
    final shouldSkipAuth =
        widget.skipAuth ?? (widget.documentRepository != null);

    final guidePage = AppGuidePage(
      repository: effectiveRepository,
      nextPage: destination,
    );

    final defaultHome = shouldSkipAuth
        ? destination
        : SplashPage(
            repository: effectiveRepository,
            nextPage: guidePage,
            authRepository: widget.authRepository,
            signedInPage: destination,
          );

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: MnoteApp.themeModeNotifier,
      builder: (context, currentThemeMode, _) {
        return ValueListenableBuilder<AppFontFamily>(
          valueListenable: MnoteApp.fontNotifier,
          builder: (context, currentFont, _) {
            return ValueListenableBuilder<AppAccent>(
              valueListenable: MnoteApp.accentNotifier,
              builder: (context, currentAccent, _) {
                return MaterialApp(
                  title: 'Mnote',
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.theme(
                    Brightness.light,
                    font: currentFont,
                    accent: currentAccent,
                  ),
                  darkTheme: AppTheme.theme(
                    Brightness.dark,
                    font: currentFont,
                    accent: currentAccent,
                  ),
                  themeMode: currentThemeMode,
                  builder: ink == null
                      ? null
                      : (context, child) =>
                            InkStorageScope(storage: ink, child: child!),
                  home: widget.home ?? defaultHome,
                );
              },
            );
          },
        );
      },
    );
  }
}
