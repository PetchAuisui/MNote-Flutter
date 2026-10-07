import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/app/mnote_app.dart';
import 'package:mnote/features/workspace/domain/markdown_document.dart';
import 'package:mnote/features/workspace/presentation/export_sheet.dart';
import 'package:mnote/features/workspace/presentation/markdown_workspace_page.dart';

import 'helpers/fakes.dart';

void main() {
  group('stripMarkdown', () {
    test('removes headers, bold, italics, links, and code blocks', () {
      const md = '''# Title
Here is **bold** and *italic* text.
Check [link](https://example.com) and ![alt](image.png).
> Quote block
- item 1
- item 2
`dart
void main() {}
`
---
The end.''';

      final stripped = stripMarkdown(md);
      expect(stripped, contains('Title'));
      expect(stripped, contains('Here is bold and italic text.'));
      expect(stripped, contains('Check link and alt.'));
      expect(stripped, contains('Quote block'));
      expect(stripped, contains('item 1'));
      expect(stripped, contains('item 2'));
      expect(stripped, contains('The end.'));
      expect(stripped, isNot(contains('# ')));
      expect(stripped, isNot(contains('**')));
      expect(stripped, isNot(contains('`')));
    });
  });

  group('Import Append Behavior', () {
    testWidgets('importing file appends text without overwriting existing content', (tester) async {
      final repo = FakeDocumentRepository();
      repo.openResult = MarkdownDocument.opened(
        name: 'Extra.md',
        content: 'Appended content from external file',
        uri: Uri.file('/tmp/Extra.md'),
      );

      await tester.pumpWidget(
        MnoteApp(
          documentRepository: repo,
          home: MarkdownWorkspacePage(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      final editorFinder = find.byKey(const Key('markdown-editor'));
      expect(editorFinder, findsOneWidget);
      final initialText = tester.widget<TextField>(editorFinder).controller!.text;

      // Tap add button and select เลือกไฟล์
      await tester.tap(find.byKey(const Key('toolbar-add-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('toolbar-add-file')));
      await tester.pumpAndSettle();

      final updatedText = tester.widget<TextField>(editorFinder).controller!.text;
      expect(updatedText, contains(initialText));
      expect(updatedText, contains('Appended content from external file'));
      expect(find.textContaining('แทรกเนื้อหาจาก Extra.md เรียบร้อยแล้ว'), findsOneWidget);
    });
  });

  group('Export Sheet and Formats', () {
    testWidgets('export button displays upload icon and opens Goodnotes-style sheet', (tester) async {
      final repo = FakeDocumentRepository();
      String? savedFileName;
      Uint8List? savedBytes;
      String? savedExt;

      Future<Uri?> mockExportSaver({
        required String fileName,
        required Uint8List bytes,
        required String extension,
      }) async {
        savedFileName = fileName;
        savedBytes = bytes;
        savedExt = extension;
        return Uri.file('/tmp/$fileName');
      }

      await tester.pumpWidget(
        MnoteApp(
          documentRepository: repo,
          home: MarkdownWorkspacePage(
            repository: repo,
            initialDocument: MarkdownDocument.example('ยินดีต้อนรับสู่ Mnote'),
            exportSaver: mockExportSaver,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify export button has upload icon
      final exportBtn = find.byKey(const Key('toolbar-export-button'));
      expect(exportBtn, findsOneWidget);
      expect(
        find.descendant(of: exportBtn, matching: find.byIcon(Icons.upload_rounded)),
        findsOneWidget,
      );

      // Tap export button to open sheet
      await tester.tap(exportBtn);
      await tester.pumpAndSettle();

      // Check all 4 options are displayed
      expect(find.text('ส่งออกเอกสาร'), findsOneWidget);
      expect(find.byKey(const Key('export-option-pdf')), findsOneWidget);
      expect(find.byKey(const Key('export-option-markdown')), findsOneWidget);
      expect(find.byKey(const Key('export-option-plaintext')), findsOneWidget);
      expect(find.byKey(const Key('export-option-image')), findsOneWidget);

      // Tap Markdown export option and verify drill-down options
      await tester.tap(find.byKey(const Key('export-option-markdown')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('export-save-button')), findsOneWidget);
      expect(find.byKey(const Key('export-share-button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('export-save-button')));
      await tester.pumpAndSettle();

      expect(savedExt, 'md');
      expect(savedFileName, 'Welcome.md');
      expect(utf8.decode(savedBytes!), contains('ยินดีต้อนรับสู่ Mnote'));
      expect(find.textContaining('ส่งออกไฟล์ Welcome.md สำเร็จ'), findsOneWidget);

      // Tap export button again and choose Plain Text
      await tester.tap(exportBtn);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('export-option-plaintext')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('export-save-button')));
      await tester.pumpAndSettle();

      expect(savedExt, 'txt');
      expect(savedFileName, 'Welcome.txt');
      expect(utf8.decode(savedBytes!), isNot(contains('# ')));

      // Tap export button again and choose PDF
      await tester.tap(exportBtn);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('export-option-pdf')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('export-pdf-ink-switch')), findsOneWidget);
      expect(find.byKey(const Key('export-pdf-page-format')), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('export-save-button')));
        await Future.delayed(const Duration(milliseconds: 500));
      });
      await tester.pumpAndSettle();

      expect(savedExt, 'pdf');
      expect(savedFileName, 'Welcome.pdf');
      expect(savedBytes, isNotNull);
      expect(savedBytes!.isNotEmpty, isTrue);
    });
  });
}
