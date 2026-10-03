import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/app/mnote_app.dart';
import 'package:mnote/features/workspace/presentation/markdown_workspace_page.dart';

import '../../../../helpers/fakes.dart';

void main() {
  const markdownDoc =
      '```mermaid\n'
      'graph TD\n'
      '  A --> B\n'
      '```\n'
      '\n'
      '```dart\n'
      'final a = 1;\n'
      '```';

  Future<void> setupWorkspaceWithMarkdown(WidgetTester tester) async {
    final repo = FakeDocumentRepository();
    await tester.pumpWidget(
      MnoteApp(
        documentRepository: repo,
        home: MarkdownWorkspacePage(repository: repo),
      ),
    );
    await tester.pumpAndSettle();

    final editorFinder = find.byKey(const Key('markdown-editor'));
    expect(editorFinder, findsOneWidget);
    await tester.enterText(editorFinder, markdownDoc);
    await tester.pump();
  }

  testWidgets(
    'เปิดหน้า workspace พิมพ์บล็อก mermaid สลับไปแท็บแสดงผล ต้องแสดง fallback และโค้ดอื่นไม่กระทบ',
    (tester) async {
      await setupWorkspaceWithMarkdown(tester);

      final previewTabFinder = find.text('แสดงผล');
      expect(previewTabFinder, findsOneWidget);
      await tester.tap(previewTabFinder);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('markdown-preview')), findsOneWidget);
      expect(find.byKey(const Key('mermaid-diagram-fallback')), findsOneWidget);
      expect(find.textContaining('final a = 1;'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'เปิดหน้า workspace พิมพ์บล็อก mermaid สลับไปแท็บจด ต้องแสดง fallback และโค้ดอื่นไม่กระทบ',
    (tester) async {
      await setupWorkspaceWithMarkdown(tester);

      final inkTabFinder = find.text('จด');
      expect(inkTabFinder, findsOneWidget);
      await tester.tap(inkTabFinder);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mermaid-diagram-fallback')), findsOneWidget);
      expect(find.textContaining('final a = 1;'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
