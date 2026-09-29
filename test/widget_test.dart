import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/app/mnote_app.dart';

import 'helpers/fakes.dart';

void main() {
  testWidgets('shows the empty Markdown workspace', (tester) async {
    await tester.pumpWidget(
      MnoteApp(documentRepository: FakeDocumentRepository()),
    );

    expect(find.text('Untitled.md'), findsOneWidget);
    expect(find.text('แก้ไข'), findsOneWidget);
    expect(find.text('แสดงผล'), findsOneWidget);
    expect(find.text('Read Markdown. Write freely.'), findsOneWidget);
    expect(find.byKey(const Key('markdown-editor')), findsOneWidget);
    expect(find.byKey(const Key('line-number-gutter')), findsOneWidget);
    expect(
      find.byKey(const Key('markdown-formatting-toolbar')),
      findsOneWidget,
    );
    expect(_lineNumberLabel('เลขบรรทัด 1'), findsOneWidget);
  });

  testWidgets('applies a heading level to the current line', (tester) async {
    await tester.pumpWidget(
      MnoteApp(documentRepository: FakeDocumentRepository()),
    );
    await tester.enterText(
      find.byKey(const Key('markdown-editor')),
      'Project title',
    );

    await tester.tap(find.byKey(const Key('toolbar-heading')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('หัวข้อ 2'));
    await tester.pumpAndSettle();

    final editor = tester.widget<TextField>(
      find.byKey(const Key('markdown-editor')),
    );
    expect(editor.controller?.text, '## Project title');
  });

  testWidgets('supports four Markdown heading levels', (tester) async {
    await tester.pumpWidget(
      MnoteApp(documentRepository: FakeDocumentRepository()),
    );
    await tester.enterText(
      find.byKey(const Key('markdown-editor')),
      'Small heading',
    );

    await tester.tap(find.byKey(const Key('toolbar-heading')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('หัวข้อ 4'));
    await tester.pumpAndSettle();

    final editor = tester.widget<TextField>(
      find.byKey(const Key('markdown-editor')),
    );
    expect(editor.controller?.text, '#### Small heading');
  });

  testWidgets('formats multiple selected lines as a list', (tester) async {
    await tester.pumpWidget(
      MnoteApp(documentRepository: FakeDocumentRepository()),
    );
    await tester.enterText(
      find.byKey(const Key('markdown-editor')),
      'first\nsecond',
    );
    final editor = tester.widget<TextField>(
      find.byKey(const Key('markdown-editor')),
    );
    editor.controller?.selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 12,
    );

    await tester.tap(find.byKey(const Key('toolbar-list')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('รายการหัวข้อ'));
    await tester.pumpAndSettle();

    expect(editor.controller?.text, '- first\n- second');
  });

  testWidgets('formats multiple selected lines as an ordered list', (
    tester,
  ) async {
    await tester.pumpWidget(
      MnoteApp(documentRepository: FakeDocumentRepository()),
    );
    await tester.enterText(
      find.byKey(const Key('markdown-editor')),
      'first\nsecond\nthird',
    );
    final editor = tester.widget<TextField>(
      find.byKey(const Key('markdown-editor')),
    );
    editor.controller?.selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 18,
    );

    await tester.tap(find.byKey(const Key('toolbar-list')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('รายการตัวเลข'));
    await tester.pumpAndSettle();

    expect(editor.controller?.text, '1. first\n2. second\n3. third');
  });

  testWidgets('inserts BR and HR Markdown tokens', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MnoteApp(documentRepository: FakeDocumentRepository()),
    );
    await tester.enterText(find.byKey(const Key('markdown-editor')), 'first');

    await tester.drag(
      find.byKey(const Key('markdown-formatting-toolbar')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('toolbar-line-break')));
    await tester.pump();
    await tester.drag(
      find.byKey(const Key('markdown-formatting-toolbar')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('toolbar-horizontal-rule')));
    await tester.pump();

    final editor = tester.widget<TextField>(
      find.byKey(const Key('markdown-editor')),
    );
    expect(editor.controller?.text, 'first<br>\n---\n');
  });

  testWidgets('updates line numbers while editing Markdown', (tester) async {
    await tester.pumpWidget(
      MnoteApp(documentRepository: FakeDocumentRepository()),
    );

    await tester.enterText(
      find.byKey(const Key('markdown-editor')),
      '# Title\n\nParagraph',
    );
    await tester.pump();

    expect(_lineNumberLabel('เลขบรรทัด 1 ถึง 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renames a document from the app bar', (tester) async {
    await tester.pumpWidget(
      MnoteApp(documentRepository: FakeDocumentRepository()),
    );

    await tester.tap(find.byKey(const Key('document-title')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('document-title-field')),
      'Project notes',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.text('Project notes.md'), findsOneWidget);
    expect(find.text('ยังไม่ได้บันทึก'), findsOneWidget);
    expect(find.byKey(const Key('document-title-field')), findsNothing);
  });

  testWidgets('edits Markdown and renders a preview', (tester) async {
    await tester.pumpWidget(
      MnoteApp(documentRepository: FakeDocumentRepository()),
    );

    await tester.enterText(
      find.byKey(const Key('markdown-editor')),
      '# Hello Mnote',
    );
    await tester.tap(find.text('แสดงผล'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('markdown-preview')), findsOneWidget);
    expect(find.text('Hello Mnote'), findsOneWidget);
    expect(find.text('ยังไม่ได้บันทึก'), findsOneWidget);
  });

  testWidgets('fits the editor on a compact phone screen', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MnoteApp(documentRepository: FakeDocumentRepository()),
    );

    expect(find.byKey(const Key('markdown-editor')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows labeled toolbar actions on an iPad-sized screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 1366);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MnoteApp(documentRepository: FakeDocumentRepository()),
    );

    expect(find.text('ตัวหนา'), findsOneWidget);
    expect(find.text('ตัวเอียง'), findsOneWidget);
    expect(find.text('รายการ'), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('markdown-formatting-toolbar')),
      const Offset(-700, 0),
    );
    await tester.pumpAndSettle();

    expect(find.text('ขึ้นบรรทัด'), findsOneWidget);
    expect(find.text('เส้นคั่น'), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('markdown-formatting-toolbar')),
      const Offset(-700, 0),
    );
    await tester.pumpAndSettle();

    expect(find.text('รูปภาพ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Finder _lineNumberLabel(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.properties.label == label,
  );
}
