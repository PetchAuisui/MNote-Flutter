import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/app/mnote_app.dart';
import 'package:mnote/features/workspace/data/device_image_picker.dart';
import 'package:mnote/features/workspace/domain/document_repository.dart';
import 'package:mnote/features/workspace/presentation/markdown_workspace_page.dart';
import 'package:mnote/features/workspace/presentation/mermaid/mermaid_diagram_view.dart';
import 'package:mnote/features/workspace/presentation/workspace_toolbar_metrics.dart';
import 'package:mnote/screens/note_list_screen.dart';

import 'helpers/fakes.dart';

Widget _buildWorkspaceApp([DocumentRepository? repository]) {
  final repo = repository ?? FakeDocumentRepository();
  return MnoteApp(
    documentRepository: repo,
    home: MarkdownWorkspacePage(repository: repo),
  );
}

void main() {
  testWidgets('loads and renders the bundled Welcome showcase on iPad', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_buildWorkspaceApp());
    await tester.pumpAndSettle();

    expect(find.text('Welcome.md'), findsOneWidget);
    expect(find.textContaining('ยินดีต้อนรับสู่ Mnote'), findsOneWidget);
    final switcher = find.byKey(const Key('workspace-mode-switcher'));
    expect(tester.getCenter(switcher).dx, closeTo(512, 0.5));
    expect(
      tester.getSize(find.byKey(const Key('workspace-header'))).height,
      68,
    );

    await tester.tap(find.text('แสดงผล'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('markdown-preview')), findsOneWidget);
    expect(find.byType(Image, skipOffstage: false), findsOneWidget);
    expect(find.byType(MermaidDiagramView), findsOneWidget);
    expect(find.text('หัวข้อระดับ H4', findRichText: true), findsOneWidget);
    expect(
      find.textContaining('Hello, Mnote!', findRichText: true),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('document returns to full height after keyboard closes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1194, 834);
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(bottom: 20);
    tester.view.padding = const FakeViewPadding(bottom: 20);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_buildWorkspaceApp());
    final editor = find.byKey(const Key('markdown-editor'));
    final initialBottom = tester.getBottomLeft(editor).dy;
    expect(834 - initialBottom, lessThan(80));
    final surface = find.byKey(const Key('document-surface'));
    expect(tester.getBottomLeft(surface).dy, closeTo(834 - 20 - 8, 0.1));
    expect(
      tester
          .getRect(surface)
          .contains(
            tester.getCenter(find.byKey(const Key('document-statistics'))),
          ),
      isTrue,
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    tester.view.padding = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(editor).dy, lessThanOrEqualTo(834 - 320));
    tester.view.viewInsets = FakeViewPadding.zero;
    tester.view.padding = const FakeViewPadding(bottom: 20);
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(editor).dy, closeTo(initialBottom, 0.1));
    expect(tester.getBottomLeft(surface).dy, closeTo(834 - 20 - 8, 0.1));
    await tester.tap(find.text('แสดงผล'));
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(surface).dy, closeTo(834 - 20 - 8, 0.1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('gutter baseline matches the rendered editor baseline', (
    tester,
  ) async {
    await tester.pumpWidget(_buildWorkspaceApp());
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
      _buildWorkspaceApp(),
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
      _buildWorkspaceApp(),
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
      _buildWorkspaceApp(),
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
      _buildWorkspaceApp(),
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
      _buildWorkspaceApp(),
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
      _buildWorkspaceApp(),
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
      _buildWorkspaceApp(),
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
      _buildWorkspaceApp(),
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
      _buildWorkspaceApp(),
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
      _buildWorkspaceApp(),
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
      _buildWorkspaceApp(),
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
      _buildWorkspaceApp(),
    );

    await tester.enterText(
      find.byKey(const Key('markdown-editor')),
      '# Hello Mnote',
    );
    await tester.tap(find.text('แสดงผล'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('markdown-preview')), findsOneWidget);
    expect(find.text('Hello Mnote'), findsOneWidget);
    expect(find.text('บันทึกแล้ว'), findsOneWidget);
  });

  testWidgets('fits the editor on a compact phone screen', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _buildWorkspaceApp(),
    );

    expect(find.byKey(const Key('markdown-editor')), findsOneWidget);
    final toolbar = tester.getRect(
      find.byKey(const Key('markdown-formatting-toolbar')),
    );
    expect(toolbar.height, workspaceToolbarControlSize);
    final more = find.byKey(const Key('toolbar-more'));
    expect(more.hitTestable(), findsOneWidget);
    await tester.tap(more);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ตัวหนา'));
    await tester.pumpAndSettle();
    final editor = tester.widget<TextField>(
      find.byKey(const Key('markdown-editor')),
    );
    expect(editor.controller!.text, '**ข้อความตัวหนา**');
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
      _buildWorkspaceApp(),
    );

    expect(find.byKey(const Key('toolbar-bold')), findsOneWidget);
    expect(
      tester
          .getCenter(
            find.byWidgetPredicate((widget) => widget is SegmentedButton),
          )
          .dx,
      closeTo(512, 1),
    );
    expect(find.byKey(const Key('toolbar-italic')), findsOneWidget);
    expect(find.byKey(const Key('toolbar-list')), findsOneWidget);

    expect(find.byKey(const Key('toolbar-line-break')), findsOneWidget);
    expect(find.byKey(const Key('toolbar-horizontal-rule')), findsOneWidget);

    expect(find.byKey(const Key('toolbar-image')), findsOneWidget);
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

  testWidgets('MnoteApp defaults to NoteListScreen and navigates into MarkdownWorkspacePage and back', (tester) async {
    final repo = FakeDocumentRepository();
    await tester.pumpWidget(
      MnoteApp(documentRepository: repo),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NoteListScreen), findsOneWidget);
    expect(find.text('เอกสาร'), findsOneWidget);

    // Create a new markdown file via "+ ใหม่"
    await tester.tap(find.text('ใหม่'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เอกสาร Markdown ใหม่ (.md)'));
    await tester.pumpAndSettle();

    // Confirm creation dialog
    await tester.tap(find.text('สร้างไฟล์'));
    await tester.pumpAndSettle();

    // Now in MarkdownWorkspacePage!
    expect(find.byType(MarkdownWorkspacePage), findsOneWidget);
    expect(find.byKey(const Key('markdown-editor')), findsOneWidget);

    // Can navigate back
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(NoteListScreen), findsOneWidget);
  });

  testWidgets(
      'toolbar image button inserts image and more actions menu supports import file',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = FakeDocumentRepository();
    final imagePicker = FakeDeviceImagePicker(
      MarkdownImageReference(alt: 'photo', uri: Uri.parse('photo.png')),
    );
    await tester.pumpWidget(
      MnoteApp(
        documentRepository: repo,
        home: MarkdownWorkspacePage(
          repository: repo,
          imagePicker: imagePicker,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify redundant toolbar-add-button does not exist
    expect(find.byKey(const Key('toolbar-add-button')), findsNothing);

    // Tap toolbar image button directly
    final imageButton = find.byKey(const Key('toolbar-image'));
    expect(imageButton, findsOneWidget);
    await tester.tap(imageButton);
    await tester.pumpAndSettle();

    expect(imagePicker.pickCount, 1);
    expect(find.textContaining('![photo](photo.png)'), findsOneWidget);

    // Tap more actions menu and select import file
    await tester.tap(find.byTooltip('คำสั่งเพิ่มเติม'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('toolbar-add-file')), findsOneWidget);
    expect(find.text('แทรกเนื้อหาจากไฟล์'), findsOneWidget);
    await tester.tap(find.byKey(const Key('toolbar-add-file')));
    await tester.pumpAndSettle();

    expect(repo.openCalls, 1);
  });
}

Finder _lineNumberLabel(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.properties.label == label,
  );
}
