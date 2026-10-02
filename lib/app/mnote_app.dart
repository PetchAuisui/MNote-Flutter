import 'package:flutter/material.dart';
import 'package:mnote/core/theme/app_theme.dart';
import 'package:mnote/features/auth/presentation/splash_page.dart';
import 'package:mnote/features/workspace/data/device_document_storage.dart';
import 'package:mnote/features/workspace/data/local_document_repository.dart';
import 'package:mnote/features/workspace/domain/document_repository.dart';
import 'package:mnote/features/workspace/presentation/markdown_workspace_page.dart';

class MnoteApp extends StatelessWidget {
  const MnoteApp({
    super.key,
    this.documentRepository,
    this.skipAuth = false,
    this.home,
  });

  final DocumentRepository? documentRepository;
  final bool skipAuth;
  final Widget? home;

  @override
  Widget build(BuildContext context) {
    final repository = documentRepository ??
        const LocalDocumentRepository(DeviceDocumentStorage());

    final defaultHome = skipAuth
        ? MarkdownWorkspacePage(repository: repository)
        : SplashPage(repository: repository);

    return MaterialApp(
      title: 'Mnote',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: home ?? defaultHome,
    );
  }
}
