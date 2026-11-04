import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/workspace/presentation/markdown_live_editor.dart';
import 'package:mnote/features/workspace/presentation/markdown_workspace_page.dart';

import '../helpers/harness.dart';

/// End-to-end: the user creates a note in the library, writes in it, goes
/// back, closes the app, and finds the note and its text again on the next
/// start. Runs the real repository, files on disk and SQLite index.
void main() {
  final editor = find.byKey(const Key('markdown-live-block-editor'));

  Future<void> createNote(WidgetTester tester, String name) async {
    await tester.tap(find.byTooltip('สร้างใหม่หรือดึงไฟล์'));
    await settle(tester);
    await tester.tap(find.text('เอกสาร Markdown ใหม่ (.md)'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, name);
    await tester.tap(find.widgetWithText(FilledButton, 'สร้างไฟล์'));
    await settle(tester);
  }

  Future<void> goBack(WidgetTester tester) async {
    await tester.tap(find.byType(BackButton));
    await settle(tester);
  }

  testWidgets('a new note is written, saved to disk and survives a restart', (
    tester,
  ) async {
    prepareDevice(tester);
    final storage = await createStorage(tester);

    // First launch: the library opens with only the bundled Welcome note.
    await launchApp(tester, storage);
    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('Lecture'), findsNothing);

    // Create a note; it opens straight in the editor.
    await createNote(tester, 'Lecture');
    expect(find.byType(MarkdownWorkspacePage), findsOneWidget);

    await tester.enterText(editor, '# Week 1\nIntegration testing in Flutter');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<MarkdownLiveEditor>(find.byType(MarkdownLiveEditor))
          .controller
          .text,
      contains('Integration testing'),
    );

    // Going back saves the note and lists it.
    await goBack(tester);
    expect(find.byType(MarkdownWorkspacePage), findsNothing);
    expect(find.text('Lecture'), findsOneWidget);

    // The text really is on disk, as a Markdown file.
    final file = File('${storage.directory.path}/Lecture.md');
    expect(await file.exists(), isTrue);
    expect(await file.readAsString(), contains('Integration testing'));

    // And the SQLite index knows about it.
    final indexed = (await storage.library()).documents.map((d) => d.name);
    expect(indexed, contains('Lecture.md'));

    // Restart: a fresh app on the same folder, database reopened from disk.
    await storage.reopen();
    await launchApp(tester, storage);
    expect(find.text('Lecture'), findsOneWidget);

    await tester.tap(find.text('Lecture'));
    await settle(tester);
    expect(find.byType(MarkdownWorkspacePage), findsOneWidget);
    expect(
      tester
          .widget<MarkdownLiveEditor>(find.byType(MarkdownLiveEditor))
          .controller
          .text,
      contains('Integration testing in Flutter'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing an existing note updates the same file', (tester) async {
    prepareDevice(tester);
    final storage = await createStorage(tester);
    await launchApp(tester, storage);

    await createNote(tester, 'Todo');
    await tester.enterText(editor, '- buy milk');
    await tester.pumpAndSettle();
    await goBack(tester);

    await tester.tap(find.text('Todo'));
    await settle(tester);
    // A note with text opens as a rendered page; tapping a line edits it.
    await tester.tap(find.text('buy milk', findRichText: true));
    await settle(tester);
    await tester.enterText(editor, '- buy milk\n- submit project');
    await tester.pumpAndSettle();
    await goBack(tester);

    final files = storage.directory
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.md'))
        .map((f) => f.uri.pathSegments.last)
        .toList();
    // Saving again rewrote Todo.md instead of making a copy.
    expect(files.where((n) => n.startsWith('Todo')), ['Todo.md']);
    expect(
      await File('${storage.directory.path}/Todo.md').readAsString(),
      contains('submit project'),
    );
  });
}
