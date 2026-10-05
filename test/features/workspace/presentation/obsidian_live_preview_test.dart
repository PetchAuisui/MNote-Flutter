import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/app/mnote_app.dart';
import 'package:mnote/features/workspace/domain/document_repository.dart';
import 'package:mnote/features/workspace/domain/markdown_document.dart';
import 'package:mnote/features/workspace/presentation/markdown_live_editor.dart';
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
              expect(span.children!.length, 3);
              final codeContentSpan = span.children![1] as TextSpan;
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
      await tester.tap(find.text('First paragraph.', findRichText: true));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('markdown-live-block-editor')),
        'Changed paragraph.\n\n',
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
      expect(field.controller!.text, '**Changed** paragraph.\n\n');
      undo.undo();
      await tester.pump();
      expect(
        controller.text,
        '# Title\n\nChanged paragraph.\n\nLast paragraph.\n',
      );
      undo.redo();
      await tester.pump();
      expect(controller.text, contains('**Changed**'));
      await tester.tap(find.text('Changed paragraph.', findRichText: true));
      await tester.pump();
      await tester.tap(find.byKey(const Key('finish-live-block')));
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
      await tester.tap(find.byKey(const Key('finish-live-block')));
      await tester.pump();
      await tester.tap(find.textContaining('first', findRichText: true));
      await tester.pump();
      final field = tester.widget<TextField>(
        find.byKey(const Key('markdown-live-block-editor')),
      );
      expect(field.controller!.text, '```dart\nfirst\n\nsecond\n```\n\n');
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
        await tester.tap(find.byTooltip('เขียน'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('markdown-live-preview')), findsOneWidget);
        final modes = tester.widget<SegmentedButton>(
          find.byKey(const Key('workspace-mode-switcher')),
        );
        expect(modes.segments, hasLength(2));
        expect(find.byTooltip('แสดงผล Markdown'), findsNothing);
        expect(find.byTooltip('จดด้วยปากกา'), findsNothing);
        expect(find.byKey(const Key('markdown-editor')), findsNothing);
        await tester.tap(find.text('Live heading', findRichText: true));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('markdown-live-block-editor')),
          '# Updated heading\n\n',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Markdown'));
        await tester.pumpAndSettle();
        final editor = tester.widget<TextField>(
          find.byKey(const Key('markdown-editor')),
        );
        expect(editor.controller!.text, startsWith('# Updated heading'));
        expect(editor.controller!.text, contains('Mermaid'));
      });
    }
  });
}
