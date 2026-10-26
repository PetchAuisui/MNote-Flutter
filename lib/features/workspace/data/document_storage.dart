import 'dart:typed_data';

class SelectedDocumentFile {
  const SelectedDocumentFile({
    required this.name,
    required this.uri,
    required this.bytes,
  });

  final String name;
  final Uri uri;
  final Uint8List bytes;
}

abstract interface class DocumentStorage {
  Future<SelectedDocumentFile?> pickDocument();

  Future<void> write(Uri uri, Uint8List bytes);

  Future<Uint8List?> read(Uri uri);

  Future<Uri?> saveAs({required String name, required Uint8List bytes});

  Future<Uri?> createDocument({required String name, required Uint8List bytes});

  Future<List<SelectedDocumentFile>> listDocuments();

  Future<void> delete(Uri uri);

  /// Maps a stored file URI to where that file lives now. iOS changes the
  /// app container path between installs, which leaves saved absolute URIs
  /// pointing nowhere. Returns [uri] unchanged when nothing better is found.
  Future<Uri> relocate(Uri uri);

  Future<String?> readMetadata();

  Future<void> writeMetadata(String content);
}
