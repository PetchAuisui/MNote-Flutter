import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/app/mnote_app.dart';

import 'helpers/fakes.dart';

void main() {
  testWidgets('gutter baseline matches the rendered editor baseline', (
    tester,
  ) async {
    await tester.pumpWidget(
      MnoteApp(documentRepository: FakeDocumentRepository()),
    );
    await tester.enterText(find.byKey(const Key('markdown-editor')), 'Hello');
    await tester.pump();
    final editable = tester
        .state<EditableTextState>(find.byType(EditableText))
        .renderEditable;
    final gutterFinder = find.byKey(const Key('line-number-gutter'));
    final dynamic gutter = tester.widget<CustomPaint>(gutterFinder).painter;
    final painter = TextPainter(
      text: TextSpan(text: 'Hello', style: gutter.editorStyle as TextStyle),
      textDirection: TextDirection.ltr,
      textScaler: gutter.textScaler as TextScaler,
      strutStyle: StrutStyle.fromTextStyle(gutter.editorStyle as TextStyle),
    )..layout(maxWidth: gutter.textWidth as double);
    final expected =
        tester.getTopLeft(gutterFinder).dy +
        16 +
        painter.computeLineMetrics().first.baseline;
    final actual =
        editable.localToGlobal(Offset.zero).dy +
        editable.getDryBaseline(editable.constraints, TextBaseline.alphabetic)!;
    // Paragraph and editable layout may round to different subpixel positions.
    expect(actual, closeTo(expected, 0.5));
    painter.dispose();
  });

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
    expect(find.byKey(const Key('toolbar-indent-list')), findsOneWidget);
    expect(find.byKey(const Key('toolbar-outdent-list')), findsOneWidget);
    final undo = tester.widget<IconButton>(
      find.byKey(const Key('toolbar-undo')),
    );
    final redo = tester.widget<IconButton>(
      find.byKey(const Key('toolbar-redo')),
    );
    expect(undo.onPressed, isNull);
    expect(redo.onPressed, isNull);
    expect(_lineNumberLabel('เลขบรรทัด 1'), findsOneWidget);
  });

  testWidgets('undoes and redoes editor changes', (tester) async {
    await tester.pumpWidget(
      MnoteApp(documentRepository: FakeDocumentRepository()),
    );
    final editorFinder = find.byKey(const Key('markdown-editor'));
    await tester.tap(editorFinder);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.enterText(editorFinder, 'Draft');
    await tester.pump(const Duration(milliseconds: 600));

    var undo = tester.widget<IconButton>(find.byKey(const Key('toolbar-undo')));
    expect(undo.onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('toolbar-undo')));
    await tester.pump();

    var editor = tester.widget<TextField>(editorFinder);
    expect(editor.controller?.text, isEmpty);

    final redo = tester.widget<IconButton>(
      find.byKey(const Key('toolbar-redo')),
    );
    expect(redo.onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('toolbar-redo')));
    await tester.pump();

    editor = tester.widget<TextField>(editorFinder);
    expect(editor.controller?.text, 'Draft');
  });

  testWidgets('undoes a formatting toolbar action', (tester) async {
    await tester.pumpWidget(
      MnoteApp(documentRepository: FakeDocumentRepository()),
    );
    final editorFinder = find.byKey(const Key('markdown-editor'));
    await tester.tap(editorFinder);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.enterText(editorFinder, 'word');
    await tester.pump(const Duration(milliseconds: 600));
    final editor = tester.widget<TextField>(editorFinder);
    editor.controller?.selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 4,
    );

    await tester.tap(find.byKey(const Key('toolbar-bold')));
    await tester.pump(const Duration(milliseconds: 600));
    expect(editor.controller?.text, '**word**');

    await tester.tap(find.byKey(const Key('toolbar-undo')));
    await tester.pump();

    expect(editor.controller?.text, 'word');
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

  testWidgets('indents and outdents a nested list item', (tester) async {
    await tester.pumpWidget(
      MnoteApp(documentRepository: FakeDocumentRepository()),
    );
    await tester.enterText(
      find.byKey(const Key('markdown-editor')),
      '- parent\n- child',
    );
    final editor = tester.widget<TextField>(
      find.byKey(const Key('markdown-editor')),
    );
    editor.controller?.selection = const TextSelection(
      baseOffset: 9,
      extentOffset: 16,
    );

    await tester.tap(find.byKey(const Key('toolbar-indent-list')));
    await tester.pump();

    expect(editor.controller?.text, '- parent\n  - child');

    await tester.tap(find.byKey(const Key('toolbar-outdent-list')));
    await tester.pump();

    expect(editor.controller?.text, '- parent\n- child');
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

    await tester.tap(find.byKey(const Key('toolbar-line-break')));
    await tester.pump();
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
    expect(
      tester
          .getCenter(
            find.byWidgetPredicate((widget) => widget is SegmentedButton),
          )
          .dx,
      closeTo(512, 1),
    );
    expect(find.text('ตัวเอียง'), findsOneWidget);
    expect(find.text('รายการ'), findsOneWidget);

    expect(find.text('ขึ้นบรรทัด'), findsOneWidget);
    expect(find.text('เส้นคั่น'), findsOneWidget);

    expect(find.text('รูปภาพ'), findsOneWidget);
    final toolbarRect = tester.getRect(
      find.byKey(const Key('markdown-formatting-toolbar')),
    );
    final imageRect = tester.getRect(find.byKey(const Key('toolbar-image')));
    expect(toolbarRect.contains(imageRect.topLeft), isTrue);
    expect(
      toolbarRect.contains(imageRect.bottomRight - const Offset(0.1, 0.1)),
      isTrue,
    );
    expect(
      find.byKey(const Key('toolbar-image')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Finder _lineNumberLabel(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.properties.label == label,
  );
}
