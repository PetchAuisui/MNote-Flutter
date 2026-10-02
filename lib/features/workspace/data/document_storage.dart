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

  Future<Uri?> saveAs({required String name, required Uint8List bytes});

  Future<List<SelectedDocumentFile>> listDocuments();

  Future<void> delete(Uri uri);

  Future<String?> readMetadata();

  Future<void> writeMetadata(String content);
}
