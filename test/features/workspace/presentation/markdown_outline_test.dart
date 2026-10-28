import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/workspace/data/ink_file_storage.dart';
import 'package:mnote/features/workspace/presentation/ink_page.dart';
import 'package:mnote/features/workspace/presentation/ink_session.dart';
import 'package:mnote/features/workspace/presentation/markdown_live_editor.dart';
import 'package:mnote/features/workspace/presentation/markdown_outline.dart';
import 'package:mnote/features/workspace/presentation/markdown_outline_panel.dart';
import 'package:mnote/l10n/l10n.dart';

void main() {
  group('parseMarkdownHeadings', () {
    test('reads ATX and setext headings with their levels', () {
      const source =
          '# One\n\ntext\n\n## **Two** ##\n\nThree\n=====\n\nFour\n---';
      final headings = parseMarkdownHeadings(source);
      expect(headings.map((h) => (h.level, h.title)), [
        (1, 'One'),
        (2, 'Two'),
        (1, 'Three'),
        (2, 'Four'),
      ]);
      expect(headings.first.offset, 0);
      expect(source.substring(headings[1].offset), startsWith('## **Two**'));
    });

    test('ignores # lines inside code fences and non headings', () {
      const source = '```\n# not a heading\n```\n\n#nospace\n\n####### seven';
      expect(parseMarkdownHeadings(source), isEmpty);
    });

    test('reads a setext heading written over several lines', () {
      final headings = parseMarkdownHeadings('First line\nsecond line\n===');
      expect(headings.map((h) => (h.level, h.title)), [
        (1, 'First line second line'),
      ]);
      // A list followed by a rule is not a heading.
      expect(parseMarkdownHeadings('- item\n- next\n---'), isEmpty);
    });

    test('keeps an empty heading and strips link syntax', () {
      final headings = parseMarkdownHeadings('#\n\n## See [docs](https://x.y)');
      expect(headings.map((h) => h.title), ['', 'See docs']);
    });
  });

  testWidgets('tapping an outline item scrolls the editor to that heading', (
    tester,
  ) async {
    final filler = List.generate(40, (i) => 'Paragraph $i').join('\n\n');
    final controller = TextEditingController(
      text: '# Top\n\n$filler\n\n## Far away\n\n$filler',
    );
    final outline = MarkdownOutlineController();
    addTearDown(controller.dispose);
    addTearDown(outline.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Row(
            children: [
              Expanded(
                child: MarkdownLiveEditor(
                  controller: controller,
                  outline: outline,
                  onChanged: (_) {},
                ),
              ),
              SizedBox(
                width: 280,
                child: MarkdownOutlinePanel(
                  textController: controller,
                  outline: outline,
                  onSelected: (heading) =>
                      outline.scrollToOffset(heading.offset),
                  onClose: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(outline.activeOffset.value, 0);

    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const Key('markdown-live-preview')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.pixels, 0);

    final far = parseMarkdownHeadings(controller.text)[1];
    await tester.tap(find.byKey(ValueKey('outline-item-${far.offset}')));
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, greaterThan(500));
    expect(outline.activeOffset.value, far.offset);

    // Scrolling back by hand moves the highlight back to the first heading.
    scrollable.position.jumpTo(0);
    await tester.pumpAndSettle();
    expect(outline.activeOffset.value, 0);
  });

  testWidgets('the outline jumps to a heading on the writing page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final filler = List.generate(40, (i) => 'Paragraph $i').join('\n\n');
    final markdown = '# Top\n\n$filler\n\n## Far away\n\n$filler';
    final session = InkSession();
    final outline = MarkdownOutlineController();
    final transform = TransformationController();
    addTearDown(session.dispose);
    addTearDown(outline.dispose);
    addTearDown(transform.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InkPage(
            session: session,
            markdown: markdown,
            name: 'notes.md',
            fileStorage: const DeviceInkFileStorage(),
            transformationController: transform,
            showToolbar: false,
            outline: outline,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(outline.activeOffset.value, 0);
    expect(transform.value.getTranslation().y, 0);

    final far = parseMarkdownHeadings(markdown)[1];
    unawaited(outline.scrollToOffset(far.offset));
    await tester.pumpAndSettle();
    expect(transform.value.getTranslation().y, lessThan(-500));
    expect(outline.activeOffset.value, far.offset);

    // A second jump before the first ends takes over: the page settles at the
    // top heading and keeps following the reader afterwards.
    unawaited(outline.scrollToOffset(0));
    await tester.pump(const Duration(milliseconds: 100));
    unawaited(outline.scrollToOffset(far.offset));
    await tester.pump(const Duration(milliseconds: 50));
    unawaited(outline.scrollToOffset(0));
    await tester.pumpAndSettle();
    expect(transform.value.getTranslation().y, greaterThan(-50));
    expect(outline.activeOffset.value, 0);
    transform.value = transform.value.clone()
      ..setTranslationRaw(transform.value.getTranslation().x, -100000, 0);
    await tester.pump();
    expect(outline.activeOffset.value, far.offset);
  });
}
