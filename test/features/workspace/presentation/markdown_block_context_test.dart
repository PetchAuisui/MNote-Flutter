import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/workspace/presentation/markdown_live_editor.dart';
import 'package:mnote/features/workspace/presentation/markdown_rendered_block.dart';
import 'package:mnote/features/workspace/presentation/markdown_document_canvas.dart';

void main() {
  test('ordered counters preserve nesting, starts and separate lists', () {
    const source =
        '5. First\n  1. Nested\n  1. Nested again\n1. Second\n\nParagraph\n\n3. Restart';
    final context = MarkdownBlockContext(source, markdownBlockRanges(source));
    expect(context.orderedNumbers.values, [5, 1, 2, 6, 3]);
  });

  test(
    'reference context excludes fenced definitions and keeps first definition',
    () {
      const source =
          '```\n[bad]: https://bad.example\n```\n\n[id]: https://first.example\n\n[id]: https://second.example';
      final context = MarkdownBlockContext(source, markdownBlockRanges(source));
      expect(context.references.containsKey('bad'), isFalse);
      expect(context.references['id']!.destination, 'https://first.example');
    },
  );

  Future<void> show(
    WidgetTester tester,
    String source, {
    void Function(String, String?, String?)? link,
  }) async {
    final controller = TextEditingController(text: source);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarkdownLiveEditor(
            controller: controller,
            onChanged: (_) {},
            onTapLink: link,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final live in [true, false]) {
    testWidgets('multiline Markdown renders correctly (live: $live)', (
      tester,
    ) async {
      const source = 'Title\n=====\n\n**first\nsecond**';
      if (live) {
        await show(tester, source);
      } else {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MarkdownDocumentSurface(
                markdown: source,
                height: 300,
                selectable: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }
      expect(find.text('Title', findRichText: true), findsOneWidget);
      expect(find.text('=====', findRichText: true), findsNothing);
      expect(find.text('first second', findRichText: true), findsOneWidget);
      expect(find.text('**first', findRichText: true), findsNothing);
      if (live) {
        await tester.tap(find.text('first second', findRichText: true));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('markdown-live-block-editor')),
          '**changed\nparagraph**',
        );
        final editor = tester.widget<MarkdownLiveEditor>(
          find.byType(MarkdownLiveEditor),
        );
        expect(
          editor.controller.text,
          'Title\n=====\n\n**changed\nparagraph**',
        );
      }
    });
  }

  test('paragraph ranges stop at Markdown block boundaries', () {
    const source =
        'first\nsecond\n\n# Heading\n\nTitle\n---\n\n1. Item\n2. Next\n\n```\ncode\n```';
    expect(
      markdownBlockRanges(source).map((range) => range.textInside(source)),
      [
        'first\nsecond',
        '# Heading',
        'Title\n---',
        '1. Item',
        '2. Next',
        '```\ncode\n```',
      ],
    );
  });

  testWidgets('parenthesis list preserves indentation and numbering', (
    tester,
  ) async {
    const source = '5) Parent\n   1) Child\n   1) Child two\n1) Next';
    await show(tester, source);
    expect(find.text('5.'), findsOneWidget);
    expect(find.text('6.'), findsOneWidget);
    expect(find.text('2.'), findsOneWidget);
    final child = find.byWidgetPredicate(
      (widget) =>
          widget is MarkdownRenderedBlock && widget.markdown == '   1) Child',
    );
    final padding = tester.widget<Padding>(
      find.descendant(of: child, matching: find.byType(Padding)).first,
    );
    expect((padding.padding as EdgeInsets).left, greaterThan(0));
  });

  testWidgets('ordered list retains successive numbers', (tester) async {
    await show(tester, '1. First\n1. Second\n1. Third');
    expect(find.text('2.'), findsOneWidget);
    expect(find.text('3.'), findsOneWidget);
  });

  testWidgets('reference link resolves document definition', (tester) async {
    String? opened;
    await show(
      tester,
      '[Site][id]\n\n[id]: https://example.com',
      link: (_, href, _) => opened = href,
    );
    expect(find.text('Site', findRichText: true), findsOneWidget);
    await tester.tap(find.text('Site', findRichText: true));
    expect(opened, 'https://example.com');
  });

  testWidgets('document surface shares numbering and reference titles', (
    tester,
  ) async {
    String? opened;
    String? title;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MarkdownDocumentSurface(
              markdown:
                  '1. First\n1. Second\n\n[**Site**][ID]\n\n[id]: https://example.com\n  \'A "quoted" title\'',
              height: 300,
              selectable: true,
              onTapLink: (_, href, linkTitle) {
                opened = href;
                title = linkTitle;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('2.'), findsOneWidget);
    await tester.tap(find.text('Site', findRichText: true));
    expect(opened, 'https://example.com');
    // The Markdown package normalizes title quotes as HTML entities.
    expect(title, 'A &quot;quoted&quot; title');
  });
}
