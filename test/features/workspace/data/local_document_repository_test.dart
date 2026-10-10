import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/workspace/data/document_storage.dart';
import 'package:mnote/features/workspace/data/local_document_repository.dart';
import 'package:mnote/features/workspace/domain/document_repository.dart';
import 'package:mnote/features/workspace/domain/markdown_document.dart';
import 'package:mnote/models/note_item.dart';

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

  test('delegates file delete to storage', () async {
    final uri = Uri.file('/tmp/deleted.md');
    await repository.delete(uri);
    expect(storage.deletedUris, contains(uri));
  });

  test('reads document content from storage', () async {
    final uri = Uri.file('/tmp/hello.md');
    await storage.write(uri, Uint8List.fromList('Hello World'.codeUnits));
    final content = await repository.readDocument(uri);
    expect(content, 'Hello World');
  });

  test('saves and loads library metadata round-trip', () async {
    final metadata = LibraryMetadata(
      folders: [
        FolderItem(
          id: 'f1',
          name: 'โฟลเดอร์ทดสอบ',
          updatedAt: DateTime(2026, 1, 1),
          isStarred: true,
        ),
      ],
      documents: [
        DocumentItem(
          id: 'd1',
          name: 'test.md',
          content: 'hello',
          updatedAt: DateTime(2026, 1, 2),
          folderId: 'f1',
          uri: Uri.file('/tmp/test.md'),
          isStarred: false,
          isTrash: false,
        ),
      ],
    );

    await repository.saveMetadata(metadata);
    expect(storage.metadataContent, isNotNull);

    final loaded = await repository.loadMetadata();
    expect(loaded?.folders.length, 1);
    expect(loaded?.folders.first.name, 'โฟลเดอร์ทดสอบ');
    expect(loaded?.folders.first.isStarred, isTrue);
    expect(loaded?.documents.length, 1);
    expect(loaded?.documents.first.name, 'test.md');
    expect(loaded?.documents.first.uri, Uri.file('/tmp/test.md'));
  });

  test(
    'returns null when write throws and fallback createDocument returns null',
    () async {
      final failingStorage = _FailingDocumentStorage();
      final repo = LocalDocumentRepository(failingStorage);
      final doc = MarkdownDocument.opened(
        name: 'notes.md',
        content: 'hello',
        uri: Uri.file('/tmp/notes.md'),
      ).edit('changed');

      final result = await repo.save(doc);

      expect(result, isNull);
    },
  );
}

class _FailingDocumentStorage extends FakeDocumentStorage {
  @override
  Future<void> write(Uri uri, Uint8List bytes) async {
    throw Exception('Disk error');
  }

  @override
  Future<Uri?> createDocument({
    required String name,
    required Uint8List bytes,
  }) async {
    return null;
  }
}
