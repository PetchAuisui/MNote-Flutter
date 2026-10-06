import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/app/mnote_app.dart';
import 'package:mnote/features/workspace/domain/markdown_document.dart';
import 'package:mnote/features/workspace/presentation/markdown_document_canvas.dart';
import 'package:mnote/features/workspace/presentation/markdown_live_editor.dart';
import 'package:mnote/features/workspace/presentation/markdown_rendered_block.dart';
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
      expect(
        tester
            .widget<TextField>(
              find.byKey(const Key('markdown-live-block-editor')),
            )
            .controller!
            .text,
        table,
      );
    });
  }
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
