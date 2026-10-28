import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:mnote/features/sync/domain/cloud_image_store.dart';

/// Stores pictures under `users/{uid}/images/{encodedFileName}`.
class FirebaseImageStore implements CloudImageStore {
  FirebaseImageStore({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance {
    // Give up on a stalled request quickly instead of retrying for minutes.
    _storage
      ..setMaxUploadRetryTime(const Duration(seconds: 20))
      ..setMaxDownloadRetryTime(const Duration(seconds: 20))
      ..setMaxOperationRetryTime(const Duration(seconds: 20));
  }

  final FirebaseStorage _storage;

  Reference _ref(String uid, String name) =>
      _storage.ref('users/$uid/images/${Uri.encodeComponent(name)}');

  @override
  Future<int?> sizeOf(String uid, String name) async {
    try {
      return (await _ref(uid, name).getMetadata()).size;
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return null;
      rethrow;
    }
  }

  @override
  Future<void> upload(
    String uid,
    String name,
    Uint8List bytes,
    String contentType,
  ) async {
    await _ref(
      uid,
      name,
    ).putData(bytes, SettableMetadata(contentType: contentType));
  }

  @override
  Future<Uint8List?> download(String uid, String name, int maxBytes) async {
    try {
      return await _ref(uid, name).getData(maxBytes);
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return null;
      rethrow;
    }
  }
}
