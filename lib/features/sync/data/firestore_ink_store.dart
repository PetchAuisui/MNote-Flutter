import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mnote/features/sync/domain/cloud_ink_store.dart';

/// Stores ink under `users/{uid}/ink/{encodedDocumentName}`.
class FirestoreInkStore implements CloudInkStore {
  FirestoreInkStore({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _ink(String uid) =>
      _firestore.collection('users').doc(uid).collection('ink');

  @override
  Stream<List<CloudInk>> watch(String uid) {
    return _ink(uid).snapshots().map(
      (snap) => [
        for (final doc in snap.docs)
          if (doc.data()['data'] is Blob)
            CloudInk(
              name: doc.data()['name'] as String? ?? '',
              hash: doc.data()['hash'] as String? ?? '',
              data: (doc.data()['data'] as Blob).bytes,
              updatedAt:
                  (doc.data()['updatedAt'] as Timestamp?)?.toDate() ??
                  DateTime.fromMillisecondsSinceEpoch(0),
            ),
      ],
    );
  }

  @override
  Future<void> upsert(String uid, CloudInk ink) {
    return _ink(uid).doc(CloudInk.idFor(ink.name)).set({
      'name': ink.name,
      'hash': ink.hash,
      'data': Blob(ink.data),
      'updatedAt': Timestamp.fromDate(ink.updatedAt),
    });
  }
}
