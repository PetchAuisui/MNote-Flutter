import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:mnote/models/note_item.dart';

part 'library_database.g.dart';

class Folders extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isStarred => boolean().withDefault(const Constant(false))();
  BoolColumn get isTrash => boolean().withDefault(const Constant(false))();
  IntColumn get colorValue => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'documents_folder', columns: {#folderId})
@TableIndex(name: 'documents_trash', columns: {#isTrash})
class Documents extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get content => text().withDefault(const Constant(''))();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get folderId => text().nullable()();
  BoolColumn get isStarred => boolean().withDefault(const Constant(false))();
  TextColumn get uri => text().nullable()();
  BoolColumn get isTrash => boolean().withDefault(const Constant(false))();
  TextColumn get syncMode => text().withDefault(const Constant('auto'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// The on-device library index (folders and note records) in SQLite.
///
/// Markdown files stay on disk where the user can reach them; this holds the
/// catalogue around them: names, folders, stars, trash and sync choice.
@DriftDatabase(tables: [Folders, Documents])
class LibraryDatabase extends _$LibraryDatabase {
  LibraryDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  // No foreign key from documents.folderId to folders.id on purpose: a note
  // synced before its folder, or after the folder was removed, must still
  // save rather than fail the whole write.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    // Add one step per schemaVersion bump here, never drop user data.
    onUpgrade: (m, from, to) async {},
  );

  /// Whether nothing has been stored yet, so a legacy JSON index may be
  /// imported.
  Future<bool> isEmpty() async {
    final folders = await select(this.folders).get();
    final documents = await select(this.documents).get();
    return folders.isEmpty && documents.isEmpty;
  }

  Future<LibraryMetadata> loadLibrary() async {
    final folderRows = await select(folders).get();
    final documentRows = await select(documents).get();
    return LibraryMetadata(
      folders: [
        for (final f in folderRows)
          FolderItem(
            id: f.id,
            name: f.name,
            updatedAt: f.updatedAt,
            isStarred: f.isStarred,
            isTrash: f.isTrash,
            colorValue: f.colorValue,
          ),
      ],
      documents: [
        for (final d in documentRows)
          DocumentItem(
            id: d.id,
            name: d.name,
            content: d.content,
            updatedAt: d.updatedAt,
            folderId: d.folderId,
            isStarred: d.isStarred,
            uri: d.uri == null ? null : Uri.tryParse(d.uri!),
            isTrash: d.isTrash,
            syncMode: SyncMode.fromName(d.syncMode),
          ),
      ],
    );
  }

  /// Makes the stored library equal to [library], writing only the rows that
  /// changed. Runs in one transaction, so a crash never leaves half of an
  /// update behind.
  Future<void> replaceLibrary(LibraryMetadata library) {
    return transaction(() async {
      final oldFolders = {for (final f in await select(folders).get()) f.id: f};
      final oldDocs = {for (final d in await select(documents).get()) d.id: d};

      final newFolders = {
        for (final f in library.folders)
          f.id: Folder(
            id: f.id,
            name: f.name,
            updatedAt: f.updatedAt,
            isStarred: f.isStarred,
            isTrash: f.isTrash,
            colorValue: f.colorValue,
          ),
      };
      final newDocs = {
        for (final d in library.documents)
          d.id: Document(
            id: d.id,
            name: d.name,
            content: d.content,
            updatedAt: d.updatedAt,
            folderId: d.folderId,
            isStarred: d.isStarred,
            uri: d.uri?.toString(),
            isTrash: d.isTrash,
            syncMode: d.syncMode.name,
          ),
      };

      await (delete(folders)..where(
            (t) => t.id.isIn(
              oldFolders.keys.where((k) => !newFolders.containsKey(k)),
            ),
          ))
          .go();
      await (delete(documents)..where(
            (t) =>
                t.id.isIn(oldDocs.keys.where((k) => !newDocs.containsKey(k))),
          ))
          .go();

      await batch((b) {
        for (final f in newFolders.values) {
          if (oldFolders[f.id] != f) {
            b.insert(folders, f, mode: InsertMode.insertOrReplace);
          }
        }
        for (final d in newDocs.values) {
          if (oldDocs[d.id] != d) {
            b.insert(documents, d, mode: InsertMode.insertOrReplace);
          }
        }
      });
    });
  }

  /// Imports an index saved as JSON by earlier versions.
  Future<void> importLegacyJson(String raw) async {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    await replaceLibrary(LibraryMetadata.fromJson(json));
  }
}
