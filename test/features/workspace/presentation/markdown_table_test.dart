import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/app/mnote_app.dart';
import 'package:mnote/features/workspace/domain/markdown_document.dart';
import 'package:mnote/features/workspace/presentation/markdown_document_canvas.dart';
import 'package:mnote/features/workspace/presentation/markdown_live_editor.dart';
import 'package:mnote/features/workspace/presentation/markdown_rendered_block.dart';
import 'package:mnote/features/workspace/presentation/markdown_table_editor.dart';
import 'package:mnote/features/workspace/presentation/markdown_workspace_page.dart';
import '../../../helpers/fakes.dart';

void main() {
  const source = '| Name | Value |\n| --- | --- |\n| One | Two |';
  test('table ranges preserve surrounding lines and fenced code', () {
    const document = 'Before\n\n$source\n\nAfter\n```\n$source\n```';
    expect(
      markdownBlockRanges(document).map((range) => range.textInside(document)),
      ['Before', source, 'After', '```\n$source\n```'],
    );
  });
  for (final table in [source, '| Name |\n| --- |\n| One |']) {
    testWidgets('renders table in document and edits it as one block: $table', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MarkdownDocumentSurface(
                markdown: table,
                height: 100,
                selectable: true,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(Table), findsOneWidget);
      final controller = TextEditingController(text: table);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownLiveEditor(controller: controller, onChanged: (_) {}),
          ),
        ),
      );
      expect(find.byType(Table), findsOneWidget);
      await tester.tap(find.text('Name', findRichText: true));
      await tester.pumpAndSettle();
      // Opening a table shows its cells, with the tapped one focused, and
      // leaves the Markdown untouched.
      final cell = tester.widget<TextField>(
        find.byKey(const Key('markdown-table-cell-0-0')),
      );
      expect(cell.controller!.text, 'Name');
      expect(cell.focusNode!.hasFocus, isTrue);
      expect(controller.text, table);
      await tester.tap(find.byKey(const Key('markdown-table-edit-markdown')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const Key('markdown-live-block-editor')),
            )
            .controller!
            .text,
        table,
      );
      expect(find.byKey(const Key('markdown-live-active-block')), findsOne);
      // And back to the cells without closing the block.
      await tester.tap(find.byKey(const Key('markdown-table-edit-cells')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('markdown-table-cell-0-0')), findsOne);
      expect(find.byKey(const Key('markdown-live-block-editor')), findsNothing);
      expect(controller.text, table);
    });
  }

  group('MarkdownTable', () {
    test('parses cells, alignment and escaped pipes', () {
      final table = MarkdownTable.parse(
        'A | B | C\n:-- | :-: | --:\n| a \\| b | | c |',
      )!;
      expect(table.rows, [
        ['A', 'B', 'C'],
        ['a | b', '', 'c'],
      ]);
      expect(table.alignments, [':---', ':---:', '---:']);
      expect(
        table.format(),
        '| A | B | C |\n| :--- | :---: | ---: |\n| a \\| b |  | c |',
      );
    });

    test('rejects blocks that are not exactly one table', () {
      expect(MarkdownTable.parse('Before\n$source'), isNull);
      expect(MarkdownTable.parse('$source\nAfter'), isNull);
      expect(MarkdownTable.parse('| just | pipes |'), isNull);
    });

    test('follows GFM on which blocks are tables', () {
      // A setext heading, and a separator that does not match the header.
      expect(MarkdownTable.parse('Name | Price\n---'), isNull);
      expect(MarkdownTable.parse('| A | B |\n| --- |\n| 1 | 2 |'), isNull);
      // Cells past the header are hidden, so rewriting would reveal them.
      expect(
        MarkdownTable.parse('| A | B |\n| --- | --- |\n| 1 | 2 | 3 |'),
        isNull,
      );
      final short = MarkdownTable.parse('| A | B |\n| --- | --- |\n| 1 |')!;
      expect(short.rows[1], ['1', '']);
      expect(short.hasSource(1, 0), isTrue);
      expect(short.hasSource(1, 1), isFalse);
    });

    test('a backslash before a pipe stays in its cell', () {
      for (final text in [r'a\|b', r'a\\|b', r'end\']) {
        final table = MarkdownTable(
          [
            ['A', 'B'],
            [text, 'x'],
          ],
          ['---', '---'],
        );
        final parsed = MarkdownTable.parse(table.format())!;
        expect(parsed.rows, table.rows, reason: table.format());
      }
    });

    test('maps source offsets to cells and back', () {
      final table = MarkdownTable.parse(source)!;
      final offset = source.indexOf('Two') + 2;
      expect(table.cellAt(offset), (1, 1, 2));
      expect(table.sourceOffset(1, 1, 2), offset);
    });
  });

  testWidgets('cell edits and row/column tools rewrite the Markdown', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'Intro\n\n$source');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarkdownLiveEditor(controller: controller, onChanged: (_) {}),
        ),
      ),
    );
    await tester.tap(find.text('Two', findRichText: true));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('markdown-table-cell-1-1')))
          .focusNode!
          .hasFocus,
      isTrue,
    );
    await tester.enterText(
      find.byKey(const Key('markdown-table-cell-1-1')),
      'a|b',
    );
    await tester.pump();
    expect(
      controller.text,
      'Intro\n\n| Name | Value |\n| --- | --- |\n| One | a\\|b |',
    );

    await tester.tap(find.byKey(const Key('markdown-table-add-row')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('markdown-table-cell-2-1')),
      'Three',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('markdown-table-add-column')));
    await tester.pumpAndSettle();
    expect(
      controller.text,
      'Intro\n\n| Name | Value |  |\n| --- | --- | --- |\n'
      '| One | a\\|b |  |\n|  | Three |  |',
    );

    await tester.tap(find.byKey(const Key('markdown-table-delete-column')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('markdown-table-cell-2-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('markdown-table-delete-row')));
    await tester.pumpAndSettle();
    expect(
      controller.text,
      'Intro\n\n| Name | Value |\n| --- | --- |\n| One | a\\|b |',
    );
    // Still editing: the tools keep the block open.
    expect(find.byKey(const Key('markdown-table-cell-0-0')), findsOne);
  });
  Future<TextEditingController> pumpEditor(
    WidgetTester tester,
    String text,
  ) async {
    final controller = TextEditingController(text: text);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarkdownLiveEditor(controller: controller, onChanged: (_) {}),
        ),
      ),
    );
    return controller;
  }

  bool cellFocused(WidgetTester tester, int y, int x) => tester
      .widget<TextField>(find.byKey(Key('markdown-table-cell-$y-$x')))
      .focusNode!
      .hasFocus;

  testWidgets('tools work after the Markdown removed the tapped row', (
    tester,
  ) async {
    final controller = await pumpEditor(
      tester,
      '| A |\n| --- |\n| One |\n| Two |\n| Three |',
    );
    await tester.tap(find.text('Three', findRichText: true));
    await tester.pumpAndSettle();
    expect(cellFocused(tester, 3, 0), isTrue);
    await tester.tap(find.byKey(const Key('markdown-table-edit-markdown')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('markdown-live-block-editor')),
      '| A |\n| --- |\n| One |',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('markdown-table-edit-cells')));
    await tester.pumpAndSettle();
    expect(cellFocused(tester, 1, 0), isTrue);
    await tester.tap(find.byKey(const Key('markdown-table-add-row')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(controller.text, '| A |\n| --- |\n| One |\n|  |');
  });

  testWidgets('Enter moves straight down a column', (tester) async {
    await pumpEditor(tester, '| A | B |\n| --- | --- |\n| 1 | 2 |\n| 3 | 4 |');
    await tester.tap(find.text('1', findRichText: true));
    await tester.pumpAndSettle();
    expect(cellFocused(tester, 1, 0), isTrue);
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    expect(cellFocused(tester, 2, 0), isTrue);
    expect(cellFocused(tester, 1, 1), isFalse);
  });

  testWidgets('a cell missing from a short row maps into the source', (
    tester,
  ) async {
    final controller = await pumpEditor(
      tester,
      '| A | B |\n| --- | --- |\n| 1 |',
    );
    await tester.tap(find.text('1', findRichText: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('markdown-table-cell-1-1')));
    await tester.pumpAndSettle();
    // Focusing it writes the row out, with the selection inside the cell.
    expect(controller.text, '| A | B |\n| --- | --- |\n| 1 |  |');
    expect(controller.selection, const TextSelection.collapsed(offset: 30));
  });

  testWidgets('table tool inserts selected dimensions and supports undo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeDocumentRepository();
    await tester.pumpWidget(
      MnoteApp(
        documentRepository: repo,
        home: MarkdownWorkspacePage(
          repository: repo,
          initialDocument: MarkdownDocument.example('Before'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Before', findRichText: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('toolbar-table')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('table-columns')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('insert-table-confirm')));
    await tester.pumpAndSettle();
    final editor = tester.widget<MarkdownLiveEditor>(
      find.byType(MarkdownLiveEditor),
    );
    expect(
      editor.controller.text,
      contains('| หัวข้อ 1 | หัวข้อ 2 | หัวข้อ 3 |'),
    );
    expect(
      editor.controller.text
          .split('\n')
          .where((line) => line.contains('ข้อมูล'))
          .length,
      2,
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(find.byType(Table), findsOneWidget);
    await tester.tap(find.byKey(const Key('toolbar-undo')));
    await tester.pumpAndSettle();
    expect(editor.controller.text, 'Before');
    await tester.tap(find.byKey(const Key('toolbar-table')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();
    expect(editor.controller.text, 'Before');
  });
}
