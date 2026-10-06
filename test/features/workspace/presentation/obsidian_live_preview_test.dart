import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:scribble/scribble.dart';
import 'package:mnote/features/workspace/presentation/ink_page.dart';
import 'package:mnote/features/workspace/presentation/markdown_document_canvas.dart';
import 'package:mnote/features/workspace/presentation/markdown_rendered_block.dart';
import 'package:mnote/features/workspace/presentation/mermaid/mermaid_element_builder.dart';
import 'package:mnote/features/workspace/presentation/mermaid/mermaid_diagram_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/app/mnote_app.dart';
import 'package:mnote/features/workspace/domain/document_repository.dart';
import 'package:mnote/features/workspace/domain/markdown_document.dart';
import 'package:mnote/features/workspace/presentation/markdown_live_editor.dart';
import 'package:mnote/features/workspace/presentation/markdown_editor_decorations.dart';
import 'package:mnote/features/workspace/presentation/markdown_workspace_page.dart';
import 'package:mnote/features/workspace/presentation/obsidian_markdown_controller.dart';

import '../../../helpers/fakes.dart';

Widget _buildApp({DocumentRepository? repository}) {
  final repo = repository ?? FakeDocumentRepository();
  return MnoteApp(
    documentRepository: repo,
    home: MarkdownWorkspacePage(
      repository: repo,
      initialDocument: MarkdownDocument.example(
        '# Live heading\n\nKeep **this** paragraph.\n\n## Mermaid\n',
      ),
    ),
  );
}

void main() {
  testWidgets('live preview opens links and still edits ordinary text', (
    tester,
  ) async {
    final controller = TextEditingController(
      text: '[Open site](https://example.com)\n\nOrdinary paragraph',
    );
    addTearDown(controller.dispose);
    String? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarkdownLiveEditor(
            controller: controller,
            onChanged: (_) {},
            onTapLink: (_, href, _) => opened = href,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open site', findRichText: true));
    await tester.pumpAndSettle();
    expect(opened, 'https://example.com');
    expect(find.byKey(const Key('markdown-live-block-editor')), findsNothing);
    await tester.tap(find.text('Ordinary paragraph', findRichText: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('markdown-live-block-editor')), findsOneWidget);
  });

  testWidgets(
    'writing mode draws ink and preserves it across Markdown switches',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('markdown-live-preview')), findsOneWidget);
      await tester.tap(find.byTooltip('เขียน'));
      await tester.pumpAndSettle();
      final canvas = find.byType(Scribble);
      final gesture = await tester.startGesture(
        tester.getTopLeft(canvas) + const Offset(80, 80),
        kind: PointerDeviceKind.stylus,
      );
      await gesture.moveBy(const Offset(30, 20));
      await gesture.up();
      await tester.pumpAndSettle();
      final pen = tester.widget<Scribble>(canvas).notifier as ScribbleNotifier;
      expect(pen.currentSketch.lines, hasLength(1));
      await tester.tap(find.byTooltip('Markdown'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('เขียน'));
      await tester.pumpAndSettle();
      final restored =
          tester.widget<Scribble>(find.byType(Scribble)).notifier
              as ScribbleNotifier;
      expect(restored.currentSketch.lines, hasLength(1));
      await tester.tap(find.byTooltip('ย้อนกลับหมึก'));
      await tester.pumpAndSettle();
      expect(restored.currentSketch.lines, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Markdown mode and writing mode have identical card, toolbar and content margins and positions',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      final markdownCardRect = tester.getRect(
        find.byKey(const Key('document-surface')),
      );
      final markdownToolbarRect = tester.getRect(
        find.byKey(const Key('markdown-toolbar-surface')),
      );
      final markdownFirstBlockRect = tester.getRect(
        find.byType(MarkdownRenderedBlock).first,
      );

      // Margins in Markdown mode are symmetric
      final markdownLeftMargin =
          markdownFirstBlockRect.left - markdownCardRect.left;
      final markdownRightMargin =
          markdownCardRect.right - markdownFirstBlockRect.right;
      expect(
        (markdownLeftMargin - markdownRightMargin).abs(),
        lessThanOrEqualTo(1.0),
      );

      await tester.tap(find.byTooltip('เขียน'));
      await tester.pumpAndSettle();

      final inkCardRect = tester.getRect(
        find.byKey(const Key('document-surface')),
      );
      final inkToolbarRect = tester.getRect(
        find.byKey(const Key('ink-toolbar')),
      );
      final inkFirstBlockRect = tester.getRect(
        find.byType(MarkdownRenderedBlock).first,
      );

      expect(inkCardRect, markdownCardRect);
      expect(inkToolbarRect.size, markdownToolbarRect.size);
      expect(inkToolbarRect.topLeft, markdownToolbarRect.topLeft);

      // Margins in Ink mode are symmetric and match Markdown mode
      final inkLeftMargin = inkFirstBlockRect.left - inkCardRect.left;
      final inkRightMargin = inkCardRect.right - inkFirstBlockRect.right;
      expect((inkLeftMargin - inkRightMargin).abs(), lessThanOrEqualTo(1.0));
      expect(inkFirstBlockRect.left, markdownFirstBlockRect.left);
      expect(inkFirstBlockRect.width, markdownFirstBlockRect.width);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'moving between blocks preserves editor focus and leaving restores preview',
    (tester) async {
      final controller = TextEditingController(
        text: '# Title\n\n- Main\n  - Nested\n\nLast paragraph',
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownLiveEditor(controller: controller, onChanged: (_) {}),
          ),
        ),
      );
      await tester.tap(
        find.text('Title', findRichText: true),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('Nested', findRichText: true),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.byKey(const Key('markdown-live-block-editor')),
      );
      expect(field.focusNode!.hasFocus, isTrue);
      expect(field.controller!.text, contains('- Nested'));
      expect(
        find.byKey(const Key('markdown-live-active-block')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const Key('markdown-live-block-editor')),
        '  - Changed',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('markdown-live-block-editor')),
        findsOneWidget,
      );
      field.focusNode!.unfocus();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('markdown-live-block-editor')), findsNothing);
      expect(find.byKey(const Key('markdown-live-active-block')), findsNothing);
      expect(find.text('Changed', findRichText: true), findsOneWidget);
      expect(find.text('เสร็จ'), findsNothing);
      expect(
        controller.text,
        '# Title\n\n- Main\n  - Changed\n\nLast paragraph',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'writing and preview have identical block geometry including images and Mermaid',
    (tester) async {
      tester.view.physicalSize = const Size(1008, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final source = File('assets/examples/welcome.md').readAsStringSync();
      final controller = TextEditingController(text: source);
      addTearDown(controller.dispose);
      final builders = {'code': MermaidElementBuilder()};
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MarkdownDocumentSurface(
                markdown: source,
                height: 0,
                selectable: false,
                builders: builders,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      List<Rect> rectangles() =>
          find.byType(MarkdownRenderedBlock).evaluate().map((e) {
            final box = e.renderObject! as RenderBox;
            return box.localToGlobal(Offset.zero) & box.size;
          }).toList();
      final previewRects = rectangles();
      expect(find.byType(Image), findsOneWidget);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownLiveEditor(
              controller: controller,
              onChanged: (_) {},
              builders: builders,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(rectangles(), previewRects);
      expect(find.byKey(const Key('line-number-gutter')), findsNothing);
      expect(find.byKey(const Key('markdown-live-block-editor')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  group('ObsidianMarkdownEditingController tests', () {
    late ObsidianMarkdownEditingController controller;

    setUp(() {
      controller = ObsidianMarkdownEditingController();
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('styles H1 heading with bold, larger font, and muted hash', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              controller.text = '# Heading 1';
              final span = controller.buildTextSpan(
                context: context,
                style: const TextStyle(fontSize: 15),
                withComposing: false,
              );
              expect(span.children, isNotEmpty);
              final hashSpan = span.children![0] as TextSpan;
              expect(hashSpan.text, '# ');

              final textSpan = span.children![1] as TextSpan;
              expect(textSpan.text, 'Heading 1');
              expect(textSpan.style?.fontWeight, FontWeight.bold);
              expect(textSpan.style?.fontSize, greaterThan(15));
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('styles bold, italic, inline code, and strikethrough', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              controller.text =
                  'This is **bold**, *italic*, `code`, and ~~deleted~~';
              final span = controller.buildTextSpan(
                context: context,
                style: const TextStyle(fontSize: 15),
                withComposing: false,
              );
              final allTexts = span.children!
                  .map((s) => (s as TextSpan).text)
                  .toList();
              expect(allTexts, contains('bold'));
              expect(allTexts, contains('italic'));
              expect(allTexts, contains('code'));
              expect(allTexts, contains('deleted'));

              // Find bold span
              final boldSpan =
                  span.children!.firstWhere(
                        (s) => (s as TextSpan).text == 'bold',
                      )
                      as TextSpan;
              expect(boldSpan.style?.fontWeight, FontWeight.bold);

              // Find inline code span
              final codeSpan =
                  span.children!.firstWhere(
                        (s) => (s as TextSpan).text == 'code',
                      )
                      as TextSpan;
              expect(codeSpan.style?.fontFamily, 'monospace');

              // Find strikethrough span
              final strikeSpan =
                  span.children!.firstWhere(
                        (s) => (s as TextSpan).text == 'deleted',
                      )
                      as TextSpan;
              expect(strikeSpan.style?.decoration, TextDecoration.lineThrough);

              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('styles code blocks with monospace font and background', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              controller.text = '```dart\nfinal x = 42;\n```';
              final span = controller.buildTextSpan(
                context: context,
                style: const TextStyle(fontSize: 15),
                withComposing: false,
              );
              expect(span.toPlainText(), controller.text);
              final codeContentSpan = span.children!
                  .cast<TextSpan>()
                  .firstWhere((s) => s.text == 'final x = 42;\n');
              expect(codeContentSpan.style?.fontFamily, 'monospace');
              expect(codeContentSpan.style?.backgroundColor, isNotNull);
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('styles links with underline and primary link color', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              controller.text = 'Check [Flutter](https://flutter.dev) now';
              final span = controller.buildTextSpan(
                context: context,
                style: const TextStyle(fontSize: 15),
                withComposing: false,
              );
              final linkSpan =
                  span.children!.firstWhere(
                        (s) => (s as TextSpan).text == 'Flutter',
                      )
                      as TextSpan;
              expect(linkSpan.style?.decoration, TextDecoration.underline);
              return const SizedBox();
            },
          ),
        ),
      );
    });
  });

  testWidgets(
    'rules and list decorations retain source and reveal markers on the selected line',
    (tester) async {
      const source = '- item\n  + nested\n\n---\n* * *\n___';
      final controller = ObsidianMarkdownEditingController(
        text: source,
        hideInactiveSyntax: true,
      );
      final scroll = ScrollController();
      addTearDown(controller.dispose);
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownEditorDecorations(
              controller: controller,
              scrollController: scroll,
              child: TextField(
                controller: controller,
                scrollController: scroll,
                maxLines: null,
              ),
            ),
          ),
        ),
      );
      TextSpan span() => controller.buildTextSpan(
        context: tester.element(find.byType(TextField)),
        style: const TextStyle(fontSize: 17),
        withComposing: false,
      );
      TextSpan marker(String text) =>
          span().children!.cast<TextSpan>().firstWhere((s) => s.text == text);
      for (final text in ['-', '+', '---', '* * *', '___']) {
        expect(marker(text).style!.fontSize, 0);
      }
      expect(span().toPlainText(), source);
      controller.editorHasFocus = true;
      controller.selection = const TextSelection.collapsed(offset: 3);
      await tester.pump();
      expect(marker('- ').style!.fontSize, 17);
      expect(marker('---').style!.fontSize, 0);
      controller.selection = TextSelection.collapsed(
        offset: source.indexOf('---') + 1,
      );
      await tester.pump();
      expect(marker('---').style!.fontSize, 17);
      expect(marker('-').style!.fontSize, 0);
      expect(controller.text, source);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'syntax follows the cursor and disappears when focus leaves the editor',
    (tester) async {
      const source =
          '# Heading\n**bold** and [link](https://example.com)\nPlain text';
      final controller = ObsidianMarkdownEditingController(
        text: source,
        hideInactiveSyntax: true,
      );
      final focus = FocusNode();
      void syncFocus() => controller.editorHasFocus = focus.hasFocus;
      focus.addListener(syncFocus);
      addTearDown(() {
        focus.removeListener(syncFocus);
        focus.dispose();
        controller.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              controller: controller,
              focusNode: focus,
              maxLines: null,
            ),
          ),
        ),
      );
      TextSpan span() => controller.buildTextSpan(
        context: tester.element(find.byType(TextField)),
        style: const TextStyle(fontSize: 17),
        withComposing: true,
      );
      TextSpan marker(String text) =>
          span().children!.cast<TextSpan>().firstWhere((s) => s.text == text);
      expect(marker('# ').style!.fontSize, 0);
      expect(marker('**').style!.fontSize, 0);
      focus.requestFocus();
      controller.selection = const TextSelection.collapsed(offset: 4);
      await tester.pump();
      expect(marker('# ').style!.fontSize, greaterThan(0));
      expect(marker('**').style!.fontSize, 0);
      controller.selection = const TextSelection.collapsed(offset: 14);
      await tester.pump();
      expect(marker('# ').style!.fontSize, 0);
      expect(marker('**').style!.fontSize, 17);
      focus.unfocus();
      await tester.pump();
      expect(marker('**').style!.fontSize, 0);
      expect(marker('](https://example.com)').style!.fontSize, 0);
      expect(span().toPlainText(), source);
      expect(controller.text, source);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'block edits, toolbar changes and undo preserve surrounding Markdown',
    (tester) async {
      const original = '# Title\n\nFirst **paragraph**.\n\nLast paragraph.\n';
      final controller = TextEditingController(text: original);
      final undo = UndoHistoryController();
      addTearDown(controller.dispose);
      addTearDown(undo.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownLiveEditor(
              controller: controller,
              undoController: undo,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.tap(
        find.text('First paragraph.', findRichText: true),
        warnIfMissed: false,
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('markdown-live-block-editor')),
        'Changed paragraph.',
      );
      await tester.pump();
      expect(
        controller.text,
        '# Title\n\nChanged paragraph.\n\nLast paragraph.\n',
      );
      controller.value = controller.value.copyWith(
        text: '# Title\n\n**Changed** paragraph.\n\nLast paragraph.\n',
        selection: const TextSelection(baseOffset: 11, extentOffset: 18),
      );
      await tester.pump();
      final field = tester.widget<TextField>(
        find.byKey(const Key('markdown-live-block-editor')),
      );
      expect(field.controller!.text, '**Changed** paragraph.');
      undo.undo();
      await tester.pump();
      expect(
        controller.text,
        '# Title\n\nChanged paragraph.\n\nLast paragraph.\n',
      );
      undo.redo();
      await tester.pump();
      expect(controller.text, contains('**Changed**'));
      await tester.tap(
        find.text('Changed paragraph.', findRichText: true),
        warnIfMissed: false,
      );
      await tester.pump();
      tester
          .widget<TextField>(
            find.byKey(const Key('markdown-live-block-editor')),
          )
          .focusNode!
          .unfocus();
      await tester.pumpAndSettle();
      await tester.pump();
      expect(find.byKey(const Key('markdown-live-block-editor')), findsNothing);
      expect(find.text('Last paragraph.', findRichText: true), findsOneWidget);
    },
  );

  testWidgets(
    'empty document can be written and fenced code remains one editable block',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownLiveEditor(controller: controller, onChanged: (_) {}),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('markdown-live-block-editor')),
        '```dart\nfirst\n\nsecond\n```\n\nTail',
      );
      await tester.pump();
      tester
          .widget<TextField>(
            find.byKey(const Key('markdown-live-block-editor')),
          )
          .focusNode!
          .unfocus();
      await tester.pumpAndSettle();
      await tester.pump();
      await tester.tap(
        find.textContaining('first', findRichText: true),
        warnIfMissed: false,
      );
      await tester.pump();
      final field = tester.widget<TextField>(
        find.byKey(const Key('markdown-live-block-editor')),
      );
      expect(field.controller!.text, '```dart\nfirst\n\nsecond\n```');
      expect(find.text('Tail', findRichText: true), findsOneWidget);
    },
  );

  testWidgets(
    'appending a block keeps the editor visible after a paragraph without a newline',
    (tester) async {
      final controller = TextEditingController(text: 'Existing paragraph');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownLiveEditor(controller: controller, onChanged: (_) {}),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('append-live-block')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('markdown-live-block-editor')),
        'New paragraph',
      );
      await tester.pump();
      expect(controller.text, 'Existing paragraph\n\nNew paragraph');
      expect(
        find.byKey(const Key('markdown-live-block-editor')),
        findsOneWidget,
      );
      expect(
        find.text('Existing paragraph', findRichText: true),
        findsOneWidget,
      );
    },
  );

  group('Unified live preview', () {
    for (final width in [400.0, 1024.0]) {
      testWidgets('edits rendered blocks in one document at width $width', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Markdown'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('markdown-live-preview')), findsOneWidget);
        final modes = tester.widget<SegmentedButton>(
          find.byKey(const Key('workspace-mode-switcher')),
        );
        expect(modes.segments, hasLength(2));
        expect(find.byTooltip('แสดงผล Markdown'), findsNothing);
        expect(find.byTooltip('จดด้วยปากกา'), findsNothing);
        expect(find.byKey(const Key('markdown-editor')), findsNothing);
        await tester.tap(
          find.text('Live heading', findRichText: true),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('markdown-live-block-editor')),
          '# Updated heading\n\n',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('เขียน'));
        await tester.pumpAndSettle();
        final ink = tester.widget<InkPage>(find.byType(InkPage));
        expect(ink.markdown, startsWith('# Updated heading'));
        expect(ink.markdown, contains('Mermaid'));
        expect(find.byType(Scribble), findsOneWidget);
        await tester.tap(find.byTooltip('Markdown'));
        await tester.pumpAndSettle();
        expect(
          find.text('Updated heading', findRichText: true),
          findsOneWidget,
        );
      });
    }
  });

  testWidgets(
    'focuses lines line-by-line without bundling blank lines and keeps code box unified',
    (tester) async {
      const doc =
          '# Header\n\nLine Alpha\nLine Beta\n\n```dart\nline 1\n\nline 2\n```\n\nFooter';
      final controller = TextEditingController(text: doc);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownLiveEditor(controller: controller, onChanged: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Line Alpha - only Line Alpha is focused, Line Beta remains rendered
      await tester.tap(
        find.text('Line Alpha', findRichText: true),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.byKey(const Key('markdown-live-block-editor')),
      );
      expect(field.controller!.text, 'Line Alpha');
      expect(find.text('Line Beta', findRichText: true), findsOneWidget);

      // Tap Line Beta - switches focus to Line Beta alone
      await tester.tap(
        find.text('Line Beta', findRichText: true),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      final betaField = tester.widget<TextField>(
        find.byKey(const Key('markdown-live-block-editor')),
      );
      expect(betaField.controller!.text, 'Line Beta');

      // Tap code box - code box is unified with internal blank lines
      await tester.tap(
        find.textContaining('line 1', findRichText: true),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      final codeField = tester.widget<TextField>(
        find.byKey(const Key('markdown-live-block-editor')),
      );
      expect(codeField.controller!.text, '```dart\nline 1\n\nline 2\n```');
    },
  );

  testWidgets(
    'tapping Mermaid diagram activates block editor with source and unfocusing restores preview',
    (tester) async {
      const doc = '# Doc\n\n```mermaid\nflowchart LR\n  A --> B\n```\n\nAfter';
      final controller = TextEditingController(text: doc);
      addTearDown(controller.dispose);
      final builders = {'code': MermaidElementBuilder()};
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownLiveEditor(
              controller: controller,
              onChanged: (_) {},
              builders: builders,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Mermaid rendered block is present
      expect(find.byType(MermaidDiagramView), findsOneWidget);

      // Tap on the Mermaid diagram area
      await tester.tap(find.byType(MermaidDiagramView), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Block editor is now active with the Mermaid code
      final editor = tester.widget<TextField>(
        find.byKey(const Key('markdown-live-block-editor')),
      );
      expect(
        editor.controller!.text,
        '```mermaid\nflowchart LR\n  A --> B\n```',
      );

      // Unfocus restores Mermaid view
      editor.focusNode!.unfocus();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('markdown-live-block-editor')), findsNothing);
      expect(find.byType(MermaidDiagramView), findsOneWidget);
    },
  );
}
