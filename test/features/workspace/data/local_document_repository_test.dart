import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/workspace/data/document_storage.dart';
import 'package:mnote/features/workspace/data/local_document_repository.dart';
import 'package:mnote/features/workspace/domain/document_repository.dart';
import 'package:mnote/features/workspace/domain/markdown_document.dart';

import '../../../helpers/fakes.dart';

void main() {
  late FakeDocumentStorage storage;
  late LocalDocumentRepository repository;

  setUp(() {
    storage = FakeDocumentStorage();
    repository = LocalDocumentRepository(storage);
  });

  test('opens UTF-8 Markdown and removes a byte order mark', () async {
    storage.selectedFile = SelectedDocumentFile(
      name: 'ภาษาไทย.md',
      uri: Uri.file('/tmp/ภาษาไทย.md'),
      bytes: Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode('# สวัสดี')]),
    );

    final document = await repository.open();

    expect(document?.name, 'ภาษาไทย.md');
    expect(document?.content, '# สวัสดี');
    expect(document?.isDirty, isFalse);
  });

  test('rejects a document that is not valid UTF-8', () async {
    storage.selectedFile = SelectedDocumentFile(
      name: 'broken.md',
      uri: Uri.file('/tmp/broken.md'),
      bytes: Uint8List.fromList([0xFF]),
    );

    expect(repository.open(), throwsA(isA<DocumentReadException>()));
  });

  test('writes an edited file URI without opening Save As', () async {
    final uri = Uri.file('/tmp/notes.md');
    final document = MarkdownDocument.opened(
      name: 'notes.md',
      content: 'before',
      uri: uri,
    ).edit('after');

    final saved = await repository.save(document);

    expect(storage.writtenUri, uri);
    expect(utf8.decode(storage.writtenBytes!), 'after');
    expect(storage.saveAsCalls, 0);
    expect(saved?.isDirty, isFalse);
  });

  test('falls back to Save As for a non-file URI', () async {
    storage.saveUri = Uri.parse('content://documents/new-note.md');
    final document = MarkdownDocument.opened(
      name: 'note.md',
      content: 'before',
      uri: Uri.parse('content://documents/note.md'),
    ).edit('after');

    final saved = await repository.save(document);

    expect(storage.saveAsCalls, 1);
    expect(saved?.uri, storage.saveUri);
    expect(saved?.isDirty, isFalse);
  });

  test('uses Save As when an opened document is renamed', () async {
    storage.saveUri = Uri.file('/tmp/renamed.md');
    final document = MarkdownDocument.opened(
      name: 'notes.md',
      content: 'content',
      uri: Uri.file('/tmp/notes.md'),
    ).rename('renamed.md');

    final saved = await repository.save(document);

    expect(storage.saveAsCalls, 1);
    expect(storage.savedAsName, 'renamed.md');
    expect(storage.writtenUri, isNull);
    expect(saved?.name, 'renamed.md');
    expect(saved?.isDirty, isFalse);
  });
}
