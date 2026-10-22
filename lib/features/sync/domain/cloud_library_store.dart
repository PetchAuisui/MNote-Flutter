import 'package:mnote/models/note_item.dart';

/// A document as stored in the cloud. Documents are keyed by file name because
/// local URIs differ between devices.
class CloudDocument {
  const CloudDocument({
    required this.name,
    required this.content,
    required this.updatedAt,
    this.folderId,
    this.isStarred = false,
    this.isTrash = false,
    this.deleted = false,
  });

  factory CloudDocument.fromItem(DocumentItem item) {
    return CloudDocument(
      name: item.name,
      content: item.content,
      updatedAt: item.updatedAt,
      folderId: item.folderId,
      isStarred: item.isStarred,
      isTrash: item.isTrash,
    );
  }

  /// A tombstone so other devices remove the document too.
  factory CloudDocument.tombstone(String name, DateTime at) {
    return CloudDocument(name: name, content: '', updatedAt: at, deleted: true);
  }

  final String name;
  final String content;
  final DateTime updatedAt;
  final String? folderId;
  final bool isStarred;
  final bool isTrash;
  final bool deleted;

  /// Firestore document id; `/` is not allowed in ids.
  static String idFor(String name) => Uri.encodeComponent(name);

  String get id => idFor(name);

  /// Everything except the timestamp, used to tell whether two copies differ.
  String get signature =>
      '$name\u0000$folderId\u0000$isStarred\u0000$isTrash\u0000$content';
}

class CloudFolder {
  const CloudFolder({
    required this.id,
    required this.name,
    required this.updatedAt,
    this.isStarred = false,
    this.isTrash = false,
    this.deleted = false,
  });

  factory CloudFolder.fromItem(FolderItem item) {
    return CloudFolder(
      id: item.id,
      name: item.name,
      updatedAt: item.updatedAt,
      isStarred: item.isStarred,
      isTrash: item.isTrash,
    );
  }

  final String id;
  final String name;
  final DateTime updatedAt;
  final bool isStarred;
  final bool isTrash;
  final bool deleted;

  String get signature => '$name\u0000$isStarred\u0000$isTrash';
}

class CloudLibrarySnapshot {
  const CloudLibrarySnapshot({
    this.documents = const [],
    this.folders = const [],
    this.hasPendingWrites = false,
  });

  final List<CloudDocument> documents;
  final List<CloudFolder> folders;

  /// True while local writes are not yet confirmed by the server.
  final bool hasPendingWrites;
}

abstract interface class CloudLibraryStore {
  /// Emits the full remote library whenever it changes, including once on
  /// subscribe.
  Stream<CloudLibrarySnapshot> watch(String uid);

  Future<void> upsertDocuments(String uid, List<CloudDocument> documents);

  Future<void> upsertFolders(String uid, List<CloudFolder> folders);

  /// Completes once every queued write has reached the server.
  Future<void> waitForPendingWrites();
}
