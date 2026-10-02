import 'package:flutter/material.dart';
import 'package:mnote/core/theme/app_theme.dart';
import 'package:mnote/features/workspace/data/device_document_storage.dart';
import 'package:mnote/features/workspace/data/local_document_repository.dart';
import 'package:mnote/features/workspace/domain/document_repository.dart';
import 'package:mnote/screens/note_list_screen.dart';

class MnoteApp extends StatelessWidget {
  const MnoteApp({
    super.key,
    this.documentRepository,
    this.home,
  });

  final DocumentRepository? documentRepository;
  final Widget? home;

  /// Global notifier to switch theme mode (Light / Dark / System)
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  /// Global notifier to switch app font family
  static final ValueNotifier<AppFontFamily> fontNotifier =
      ValueNotifier<AppFontFamily>(AppFontFamily.prompt);

  @override
  Widget build(BuildContext context) {
    final effectiveRepository = documentRepository ??
        const LocalDocumentRepository(DeviceDocumentStorage());

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
              home: home ??
                  NoteListScreen(
                    repository: effectiveRepository,
                  ),
            );
          },
        );
      },
    );
  }
}