import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mnote/features/sync/domain/cloud_library_store.dart';

/// Stores the library under `users/{uid}/documents` and `users/{uid}/folders`.
class FirestoreLibraryStore implements CloudLibraryStore {
  FirestoreLibraryStore({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _documents(String uid) =>
      _firestore.collection('users').doc(uid).collection('documents');

  CollectionReference<Map<String, dynamic>> _folders(String uid) =>
      _firestore.collection('users').doc(uid).collection('folders');

  @override
  Stream<CloudLibrarySnapshot> watch(String uid) {
    late final StreamController<CloudLibrarySnapshot> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? docsSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? foldersSub;
    List<CloudDocument>? docs;
    List<CloudFolder>? folders;
    var pendingDocs = false;
    var pendingFolders = false;

    void emit() {
      if (docs == null || folders == null) return;
      controller.add(
        CloudLibrarySnapshot(
          documents: docs!,
          folders: folders!,
          hasPendingWrites: pendingDocs || pendingFolders,
        ),
      );
    }

    controller = StreamController<CloudLibrarySnapshot>(
      onListen: () {
        docsSub = _documents(uid)
            .snapshots(includeMetadataChanges: true)
            .listen((snap) {
              pendingDocs = snap.metadata.hasPendingWrites;
              docs = snap.docs.map((d) => _documentFrom(d.data())).toList();
              emit();
            }, onError: controller.addError);
        foldersSub = _folders(uid)
            .snapshots(includeMetadataChanges: true)
            .listen((snap) {
              pendingFolders = snap.metadata.hasPendingWrites;
              folders = snap.docs
                  .map((d) => _folderFrom(d.id, d.data()))
                  .toList();
              emit();
            }, onError: controller.addError);
      },
      onCancel: () async {
        await docsSub?.cancel();
        await foldersSub?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Future<void> upsertDocuments(String uid, List<CloudDocument> documents) {
    return _commit(
      documents,
      (batch, d) => batch.set(_documents(uid).doc(d.id), {
        'name': d.name,
        'content': d.content,
        'updatedAt': Timestamp.fromDate(d.updatedAt),
        'folderId': d.folderId,
        'isStarred': d.isStarred,
        'isTrash': d.isTrash,
        'deleted': d.deleted,
      }),
    );
  }

  @override
  Future<void> upsertFolders(String uid, List<CloudFolder> folders) {
    return _commit(
      folders,
      (batch, f) => batch.set(_folders(uid).doc(f.id), {
        'name': f.name,
        'updatedAt': Timestamp.fromDate(f.updatedAt),
        'isStarred': f.isStarred,
        'isTrash': f.isTrash,
        'deleted': f.deleted,
        'color': f.colorValue,
      }),
    );
  }

  @override
  Future<void> waitForPendingWrites() => _firestore.waitForPendingWrites();

  // A Firestore batch holds at most 500 writes.
  Future<void> _commit<T>(
    List<T> items,
    void Function(WriteBatch batch, T item) write,
  ) async {
    for (var i = 0; i < items.length; i += 400) {
      final batch = _firestore.batch();
      for (final item in items.skip(i).take(400)) {
        write(batch, item);
      }
      await batch.commit();
    }
  }

  CloudDocument _documentFrom(Map<String, dynamic> data) {
    return CloudDocument(
      name: data['name'] as String? ?? '',
      content: data['content'] as String? ?? '',
      updatedAt: _time(data['updatedAt']),
      folderId: data['folderId'] as String?,
      isStarred: data['isStarred'] as bool? ?? false,
      isTrash: data['isTrash'] as bool? ?? false,
      deleted: data['deleted'] as bool? ?? false,
    );
  }

  CloudFolder _folderFrom(String id, Map<String, dynamic> data) {
    return CloudFolder(
      id: id,
      name: data['name'] as String? ?? '',
      updatedAt: _time(data['updatedAt']),
      isStarred: data['isStarred'] as bool? ?? false,
      isTrash: data['isTrash'] as bool? ?? false,
      deleted: data['deleted'] as bool? ?? false,
      colorValue: (data['color'] as num?)?.toInt(),
    );
  }

  DateTime _time(Object? value) => value is Timestamp
      ? value.toDate()
      : DateTime.fromMillisecondsSinceEpoch(0);
}
