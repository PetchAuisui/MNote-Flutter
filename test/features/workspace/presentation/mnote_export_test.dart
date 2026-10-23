import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/app/mnote_app.dart';
import 'package:mnote/features/workspace/data/ink_file_storage.dart';
import 'package:mnote/features/workspace/domain/markdown_document.dart';
import 'package:mnote/features/workspace/domain/mnote_bundle.dart';
import 'package:mnote/features/workspace/presentation/export_sheet.dart';
import 'package:mnote/features/workspace/presentation/ink_session.dart';
import 'package:mnote/features/workspace/presentation/ink_storage_scope.dart';
import 'package:mnote/features/workspace/presentation/markdown_workspace_page.dart';

import '../../../helpers/fakes.dart';

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

  testWidgets('opening a .mnote restores the markdown and its ink', (
    tester,
  ) async {
    final ink = jsonEncode({
      'format': 'mnote-ink',
      'version': 1,
      'width': InkSession.pageWidth,
      'height': 1400.0,
      'sketch': {'lines': []},
    });
    final bytes = MnoteBundle(
      name: 'trip.md',
      markdown: '# Trip',
      ink: ink,
    ).encode();
    final repo = FakeDocumentRepository();
    final storage = _MemoryInkStorage();
    await tester.pumpWidget(
      InkStorageScope(
        storage: storage,
        child: MnoteApp(
          documentRepository: repo,
          home: MarkdownWorkspacePage(
            repository: repo,
            initialDocument: MarkdownDocument.example('old'),
            mnotePicker: () async => bytes,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('คำสั่งเพิ่มเติม'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('toolbar-open-mnote')));
    await tester.pumpAndSettle();

    expect(find.textContaining('เปิดโน้ต trip แล้ว'), findsOneWidget);
    expect(jsonDecode(utf8.decode(storage.saved['trip.md']!)), jsonDecode(ink));
  });
}

class _MemoryInkStorage implements InkFileStorage {
  final saved = <String, Uint8List>{};

  @override
  Future<bool> autoSave({
    required String name,
    required Uint8List bytes,
  }) async {
    saved[name] = bytes;
    return true;
  }

  @override
  Future<Uint8List?> autoLoad({required String name}) async => saved[name];

  @override
  Future<bool> save({required String name, required Uint8List bytes}) async =>
      true;

  @override
  Future<Uint8List?> open() async => null;

  @override
  Future<List<String>> listNames() async => saved.keys.toList();

  @override
  Future<void> deleteAll() async => saved.clear();
}
