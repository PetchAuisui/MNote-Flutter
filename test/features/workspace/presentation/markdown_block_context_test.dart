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
