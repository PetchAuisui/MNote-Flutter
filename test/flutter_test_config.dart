import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/workspace/presentation/markdown_workspace_page.dart';
import 'package:mnote/features/workspace/presentation/workspace_controller.dart';

/// Production opens documents in writing mode; most tests exercise the
/// Markdown editor, so they start there unless they ask otherwise.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  // The tests look for Thai text, so the test device speaks Thai.
  setUp(
    () => binding.platformDispatcher.localesTestValue = [const Locale('th')],
  );
  MarkdownWorkspacePage.defaultMode = WorkspaceMode.split;
  await testMain();
}
