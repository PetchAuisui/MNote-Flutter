import 'dart:async';

import 'package:mnote/features/workspace/presentation/markdown_workspace_page.dart';
import 'package:mnote/features/workspace/presentation/workspace_controller.dart';

/// Production opens documents in writing mode; most tests exercise the
/// Markdown editor, so they start there unless they ask otherwise.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  MarkdownWorkspacePage.defaultMode = WorkspaceMode.split;
  await testMain();
}
