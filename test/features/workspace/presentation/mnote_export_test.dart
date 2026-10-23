import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/workspace/domain/markdown_document.dart';
import 'package:mnote/features/workspace/domain/mnote_bundle.dart';
import 'package:mnote/features/workspace/presentation/export_sheet.dart';

void main() {
  testWidgets('exports markdown and ink together as a .mnote file', (
    tester,
  ) async {
    String? savedExt;
    String? savedName;
    Uint8List? savedBytes;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExportBottomSheet(
            document: MarkdownDocument.example('# Hi'),
            inkLoader: () async => '{"format":"mnote-ink","version":1}',
            exportSaver:
                ({
                  required String fileName,
                  required Uint8List bytes,
                  required String extension,
                }) async {
                  savedName = fileName;
                  savedBytes = bytes;
                  savedExt = extension;
                  return Uri.file('/tmp/$fileName');
                },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('export-option-mnote')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('export-save-button')));
    await tester.pumpAndSettle();

    expect(savedExt, 'mnote');
    expect(savedName, 'Welcome.mnote');
    final bundle = MnoteBundle.decode(savedBytes!);
    expect(bundle.name, 'Welcome.md');
    expect(bundle.markdown, '# Hi');
    expect(bundle.ink, contains('mnote-ink'));
  });
}
