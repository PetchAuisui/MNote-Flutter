import 'package:flutter/material.dart';
import 'package:mnote/core/theme/app_theme.dart';
import 'package:mnote/features/workspace/data/device_document_storage.dart';
import 'package:mnote/features/workspace/data/local_document_repository.dart';
import 'package:mnote/features/workspace/domain/document_repository.dart';
import 'package:mnote/screens/note_list_screen.dart';

class MnoteApp extends StatelessWidget {
  const MnoteApp({super.key, this.documentRepository});

  final DocumentRepository? documentRepository;

  /// Global notifier to switch theme mode (Light / Dark / System)
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  @override
  Widget build(BuildContext context) {
    final effectiveRepository = documentRepository ??
        const LocalDocumentRepository(DeviceDocumentStorage());

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, currentThemeMode, _) {
        return MaterialApp(
          title: 'Mnote',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: currentThemeMode,
          home: NoteListScreen(
            repository: effectiveRepository,
          ),
        );
      },
    );
  }
}