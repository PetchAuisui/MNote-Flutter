import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/workspace/data/database/library_database.dart';
import 'package:mnote/models/note_item.dart';

void main() {
  late LibraryDatabase db;

  setUp(() => db = LibraryDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  final updated = DateTime.utc(2026, 5, 1, 10);

  test('starts empty', () async {
    expect(await db.isEmpty(), isTrue);
    final library = await db.loadLibrary();
    expect(library.folders, isEmpty);
    expect(library.documents, isEmpty);
  });

  test('round-trips folders and documents', () async {
    await db.replaceLibrary(
      LibraryMetadata(
        folders: [
          FolderItem(
            id: 'f1',
            name: 'Work',
            updatedAt: updated,
            isStarred: true,
            colorValue: 0xFF112233,
          ),
        ],
        documents: [
          DocumentItem(
            id: 'd1',
            name: 'a.md',
            content: '# Hi',
            updatedAt: updated,
            folderId: 'f1',
            isStarred: true,
            uri: Uri.parse('file:///docs/a.md'),
            isTrash: true,
            syncMode: SyncMode.never,
          ),
        ],
      ),
    );

    expect(await db.isEmpty(), isFalse);
    final library = await db.loadLibrary();
    final folder = library.folders.single;
    expect(folder.name, 'Work');
    expect(folder.isStarred, isTrue);
    expect(folder.colorValue, 0xFF112233);
    final doc = library.documents.single;
    expect(doc.content, '# Hi');
    expect(doc.folderId, 'f1');
    expect(doc.uri, Uri.parse('file:///docs/a.md'));
    expect(doc.isTrash, isTrue);
    expect(doc.syncMode, SyncMode.never);
    expect(doc.updatedAt.toUtc(), updated);
  });

  test('replaceLibrary drops rows that are no longer present', () async {
    DocumentItem item(String id) =>
        DocumentItem(id: id, name: '$id.md', content: '', updatedAt: updated);
    await db.replaceLibrary(LibraryMetadata(documents: [item('a'), item('b')]));
    await db.replaceLibrary(LibraryMetadata(documents: [item('b')]));

    final library = await db.loadLibrary();
    expect(library.documents.map((d) => d.id), ['b']);
  });

  test('imports an index saved as JSON by an earlier version', () async {
    await db.importLegacyJson(
      '{"folders":[{"id":"f","name":"Old","updatedAt":"2026-01-01T00:00:00.000Z"}],'
      '"documents":[{"id":"d","name":"n.md","content":"x","updatedAt":"2026-01-01T00:00:00.000Z"}]}',
    );

    final library = await db.loadLibrary();
    expect(library.folders.single.name, 'Old');
    expect(library.documents.single.syncMode, SyncMode.auto);
  });

  test('keeps milliseconds so sync can compare times', () async {
    final precise = DateTime.utc(2026, 5, 1, 10, 0, 0, 123);
    await db.replaceLibrary(
      LibraryMetadata(
        documents: [
          DocumentItem(id: 'a', name: 'a.md', content: '', updatedAt: precise),
        ],
      ),
    );

    final doc = (await db.loadLibrary()).documents.single;
    expect(doc.updatedAt.toUtc(), precise);
  });

  test('saves a note whose folder is missing', () async {
    await db.replaceLibrary(
      LibraryMetadata(
        documents: [
          DocumentItem(
            id: 'a',
            name: 'a.md',
            content: '',
            updatedAt: updated,
            folderId: 'gone',
          ),
        ],
      ),
    );

    expect((await db.loadLibrary()).documents.single.folderId, 'gone');
  });

  test('an unchanged library is not rewritten', () async {
    final library = LibraryMetadata(
      documents: [
        DocumentItem(id: 'a', name: 'a.md', content: 'x', updatedAt: updated),
      ],
    );
    await db.replaceLibrary(library);

    var writes = 0;
    final sub = db
        .tableUpdates(TableUpdateQuery.onTable(db.documents))
        .listen((_) => writes++);
    await db.replaceLibrary(library);
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(writes, 0);
  });
}
