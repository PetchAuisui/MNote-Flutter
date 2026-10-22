import 'dart:typed_data';

/// A document's pen ink as stored in the cloud, keyed by document name.
class CloudInk {
  const CloudInk({
    required this.name,
    required this.hash,
    required this.data,
    required this.updatedAt,
  });

  final String name;

  /// Hash of the uncompressed sketch, so copies compare without decoding.
  final String hash;

  /// gzip-compressed sketch JSON.
  final Uint8List data;
  final DateTime updatedAt;

  static String idFor(String name) => Uri.encodeComponent(name);
}

abstract interface class CloudInkStore {
  Stream<List<CloudInk>> watch(String uid);

  Future<void> upsert(String uid, CloudInk ink);
}
