import 'package:flutter/material.dart';
import 'package:mnote/core/theme/app_theme.dart';
import 'package:mnote/features/auth/domain/auth_repository.dart';
import 'package:mnote/features/auth/presentation/app_guide_page.dart';
import 'package:mnote/features/auth/presentation/splash_page.dart';
import 'package:mnote/features/workspace/data/device_document_storage.dart';
import 'package:mnote/features/workspace/data/local_document_repository.dart';
import 'package:mnote/features/workspace/domain/document_repository.dart';
import 'package:mnote/screens/note_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MnoteApp extends StatelessWidget {
  const MnoteApp({
    super.key,
    this.documentRepository,
    this.skipAuth,
    this.home,
    this.authRepository,
  });

  final DocumentRepository? documentRepository;
  final bool? skipAuth;
  final Widget? home;

  /// When null, only the offline flow is available (no email login/register).
  final AuthRepository? authRepository;

  /// Global notifier to switch theme mode (Light / Dark / System)
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  /// Global notifier to switch app font family
  static final ValueNotifier<AppFontFamily> fontNotifier =
      ValueNotifier<AppFontFamily>(AppFontFamily.prompt);

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
  Widget build(BuildContext context) {
    final effectiveRepository =
        documentRepository ??
        const LocalDocumentRepository(DeviceDocumentStorage());

    final destination = NoteListScreen(
      repository: effectiveRepository,
      authRepository: authRepository,
    );
    final shouldSkipAuth = skipAuth ?? (documentRepository != null);

    final guidePage = AppGuidePage(
      repository: effectiveRepository,
      nextPage: destination,
    );

    final defaultHome = shouldSkipAuth
        ? destination
        : SplashPage(
            repository: effectiveRepository,
            nextPage: guidePage,
            authRepository: authRepository,
            signedInPage: destination,
          );

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, currentThemeMode, _) {
        return ValueListenableBuilder<AppFontFamily>(
          valueListenable: fontNotifier,
          builder: (context, currentFont, _) {
            return MaterialApp(
              title: 'Mnote',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.theme(Brightness.light, font: currentFont),
              darkTheme: AppTheme.theme(Brightness.dark, font: currentFont),
              themeMode: currentThemeMode,
              home: home ?? defaultHome,
            );
          },
        );
      },
    );
  }
}
