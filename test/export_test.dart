import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/app/mnote_app.dart';
import 'package:mnote/features/workspace/domain/markdown_document.dart';
import 'package:mnote/features/workspace/presentation/document_page_render.dart';
import 'package:mnote/features/workspace/presentation/export_sheet.dart';
import 'package:mnote/features/workspace/presentation/ink_session.dart';
import 'package:mnote/features/workspace/presentation/markdown_zip_export.dart';
import 'package:mnote/features/workspace/presentation/markdown_workspace_page.dart';

import 'package:scribble/scribble.dart';

import 'helpers/fakes.dart';

/// Pumps frames, letting real I/O and image encoding run in between, until
/// [done] holds. Exports render the page off screen, which takes both.
Future<void> pumpUntil(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 300 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(done(), isTrue, reason: 'export did not finish');
}

int pdfPageCount(Uint8List pdf) =>
    RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(pdf)).length;

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
    testWidgets(
      'importing file appends text without overwriting existing content',
      (tester) async {
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

        final editorFinder = find.byKey(
          const Key('markdown-live-block-editor'),
        );
        expect(editorFinder, findsOneWidget);

        // Tap more actions button and select แทรกเนื้อหาจากไฟล์
        await tester.tap(find.byTooltip('คำสั่งเพิ่มเติม'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('toolbar-add-file')));
        await tester.pumpAndSettle();

        expect(
          find.textContaining(
            'Appended content from external file',
            findRichText: true,
          ),
          findsWidgets,
        );
        expect(
          find.textContaining('แทรกเนื้อหาจาก Extra.md เรียบร้อยแล้ว'),
          findsOneWidget,
        );
      },
    );
  });

  group('Export Sheet and Formats', () {
    testWidgets(
      'export button displays upload icon and opens Goodnotes-style sheet',
      (tester) async {
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
              initialDocument: MarkdownDocument.example(
                'ยินดีต้อนรับสู่ Mnote',
              ),
              exportSaver: mockExportSaver,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify export button has upload icon
        final exportBtn = find.byKey(const Key('toolbar-export-button'));
        expect(exportBtn, findsOneWidget);
        expect(
          find.descendant(
            of: exportBtn,
            matching: find.byIcon(Icons.upload_rounded),
          ),
          findsOneWidget,
        );

        // Tap export button to open sheet
        await tester.tap(exportBtn);
        await tester.pumpAndSettle();

        // Check all 4 options are displayed
        expect(find.text('ส่งออกเอกสาร'), findsOneWidget);
        expect(find.byKey(const Key('export-option-pdf')), findsOneWidget);
        expect(find.byKey(const Key('export-option-markdown')), findsOneWidget);
        expect(
          find.byKey(const Key('export-option-plaintext')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('export-option-image')), findsOneWidget);

        // Tap Markdown export option and verify drill-down options
        await tester.tap(find.byKey(const Key('export-option-markdown')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('export-save-button')), findsOneWidget);
        expect(find.byKey(const Key('export-share-button')), findsOneWidget);
        await tester.tap(find.byKey(const Key('export-save-button')));
        await tester.pumpAndSettle();

        expect(savedExt, 'zip');
        expect(savedFileName, 'Welcome.zip');
        final zip = ZipDecoder().decodeBytes(savedBytes!);
        expect(
          utf8.decode(zip.findFile('Welcome.md')!.content),
          contains('ยินดีต้อนรับสู่ Mnote'),
        );
        expect(
          find.textContaining('ส่งออกไฟล์ Welcome.zip สำเร็จ'),
          findsOneWidget,
        );

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
        await tester.tap(find.byKey(const Key('export-save-button')));
        await pumpUntil(tester, () => savedExt == 'pdf');

        expect(savedExt, 'pdf');
        expect(savedFileName, 'Welcome.pdf');
        expect(savedBytes, isNotNull);
        expect(savedBytes!.isNotEmpty, isTrue);
      },
    );
  });

  group('Full-page export', () {
    // Far longer than any viewport, in Thai, so a capture of the screen or a
    // text-only fallback that drops Thai would both show.
    final longNote = [
      '# บันทึกยาว',
      for (var i = 0; i < 60; i++)
        'ย่อหน้าที่ $i ภาษาไทยยาวพอที่จะขึ้นบรรทัดใหม่ในหน้ากระดาษ '
            'เพื่อทดสอบการส่งออกทั้งเอกสาร',
    ].join('\n\n');

    String inkSnapshot() {
      final session = InkSession();
      session.pen.setSketch(
        sketch: const Sketch(
          lines: [
            SketchLine(
              points: [Point(40, 40), Point(400, 2000)],
              color: 0xFFB3261E,
              width: 6,
            ),
          ],
        ),
      );
      final snapshot = session.encode();
      session.dispose();
      return snapshot;
    }

    Future<({String? ext, Uint8List? bytes})> export(
      WidgetTester tester, {
      required Key option,
      bool continuous = false,
      bool includeInk = true,
    }) async {
      String? ext;
      Uint8List? saved;
      final repo = FakeDocumentRepository();
      await tester.pumpWidget(
        MnoteApp(
          documentRepository: repo,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showExportBottomSheet(
                  context,
                  document: MarkdownDocument(
                    name: 'Long.md',
                    content: longNote,
                    savedName: 'Long.md',
                    savedContent: longNote,
                  ),
                  inkLoader: () async => inkSnapshot(),
                  exportSaver:
                      ({
                        required String fileName,
                        required Uint8List bytes,
                        required String extension,
                      }) async {
                        ext = extension;
                        saved = bytes;
                        return Uri.file('/tmp/$fileName');
                      },
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(option));
      await tester.pumpAndSettle();
      if (continuous) {
        await tester.tap(find.text('ต่อเนื่อง'));
        await tester.pumpAndSettle();
      }
      if (!includeInk) {
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const Key('export-save-button')));
      await pumpUntil(tester, () => ext != null);
      return (ext: ext, bytes: saved);
    }

    testWidgets('A4 PDF spreads a long note over several pages', (
      tester,
    ) async {
      final result = await export(
        tester,
        option: const Key('export-option-pdf'),
      );
      expect(result.ext, 'pdf');
      expect(pdfPageCount(result.bytes!), greaterThan(1));
    });

    testWidgets('continuous PDF keeps the note on one page', (tester) async {
      final result = await export(
        tester,
        option: const Key('export-option-pdf'),
        continuous: true,
      );
      expect(result.ext, 'pdf');
      expect(pdfPageCount(result.bytes!), 1);
    });

    testWidgets('PDF without ink still renders the Thai text', (tester) async {
      final result = await export(
        tester,
        option: const Key('export-option-pdf'),
        includeInk: false,
      );
      expect(result.ext, 'pdf');
      expect(pdfPageCount(result.bytes!), greaterThan(1));
    });
  });

  group('paginate', () {
    test('breaks between blocks and never past a page', () {
      final spans = paginate(2500, 1000, [0, 300, 900, 1100, 1900, 2400]);
      expect(spans, [
        (top: 0.0, bottom: 900.0),
        (top: 900.0, bottom: 1900.0),
        (top: 1900.0, bottom: 2500.0),
      ]);
    });

    test('cuts a block taller than a page', () {
      expect(paginate(2500, 1000, [0]), [
        (top: 0.0, bottom: 1000.0),
        (top: 1000.0, bottom: 2000.0),
        (top: 2000.0, bottom: 2500.0),
      ]);
    });
  });

  group('buildMarkdownZip', () {
    test('puts the note at the top and its pictures in img/', () async {
      final dir = await Directory.systemTemp.createTemp('mnote_zip');
      addTearDown(() => dir.delete(recursive: true));
      await File('${dir.path}/photo one.png').writeAsBytes([1, 2, 3]);
      const pixel =
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
      const note =
          '# รูป\n\n![a](photo%20one.png#120x80)\n\n![b]($pixel)\n\n'
          '![web](https://example.com/x.png)\n\n![gone](missing.png)\n\n'
          '<img src="photo%20one.png" width="40">\n';

      final bytes = await buildMarkdownZip(
        markdown: note,
        fileName: 'Pictures',
        imageDirectory: dir.uri.toString(),
      );
      final zip = ZipDecoder().decodeBytes(bytes);
      final names = zip.files.map((f) => f.name).toSet();
      expect(names, {
        'img/',
        'Pictures.md',
        'img/photo-one.png',
        'img/image.png',
      });
      expect(zip.findFile('img/photo-one.png')!.content, [1, 2, 3]);

      final md = utf8.decode(zip.findFile('Pictures.md')!.content);
      expect(md, contains('![a](img/photo-one.png#120x80)'));
      expect(md, contains('![b](img/image.png)'));
      expect(md, contains('![web](https://example.com/x.png)'));
      expect(md, contains('![gone](missing.png)'));
      expect(md, contains('<img src="img/photo-one.png" width="40">'));
    });
  });
}
