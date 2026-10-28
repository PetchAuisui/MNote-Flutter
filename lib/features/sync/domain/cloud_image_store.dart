import 'dart:typed_data';

/// Pictures embedded in notes, stored per account and keyed by file name.
abstract interface class CloudImageStore {
  /// Size in bytes of the stored picture, or null when it is not there.
  Future<int?> sizeOf(String uid, String name);

  Future<void> upload(
    String uid,
    String name,
    Uint8List bytes,
    String contentType,
  );

  /// The stored picture, or null when it is not there or larger than
  /// [maxBytes].
  Future<Uint8List?> download(String uid, String name, int maxBytes);
}
