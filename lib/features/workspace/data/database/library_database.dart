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

  /// Replaces the whole library in one transaction, so a crash never leaves
  /// half of an update behind.
  Future<void> replaceLibrary(LibraryMetadata library) {
    return transaction(() async {
      await delete(folders).go();
      await delete(documents).go();
      await batch((b) {
        b.insertAll(folders, [
          for (final f in library.folders)
            FoldersCompanion.insert(
              id: f.id,
              name: f.name,
              updatedAt: f.updatedAt,
              isStarred: Value(f.isStarred),
              isTrash: Value(f.isTrash),
              colorValue: Value(f.colorValue),
            ),
        ], mode: InsertMode.insertOrReplace);
        b.insertAll(documents, [
          for (final d in library.documents)
            DocumentsCompanion.insert(
              id: d.id,
              name: d.name,
              content: Value(d.content),
              updatedAt: d.updatedAt,
              folderId: Value(d.folderId),
              isStarred: Value(d.isStarred),
              uri: Value(d.uri?.toString()),
              isTrash: Value(d.isTrash),
              syncMode: Value(d.syncMode.name),
            ),
        ], mode: InsertMode.insertOrReplace);
      });
    });
  }

  /// Imports an index saved as JSON by earlier versions.
  Future<void> importLegacyJson(String raw) async {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    await replaceLibrary(LibraryMetadata.fromJson(json));
  }
}
