import 'dart:typed_data';

import 'package:mnote/features/workspace/domain/markdown_document.dart';
import 'package:mnote/models/note_item.dart';

abstract interface class DocumentRepository {
  Future<MarkdownDocument?> open();

  /// Opens a Markdown or text file the user already picked.
  Future<MarkdownDocument> openFile({
    required String name,
    required Uri uri,
    required Uint8List bytes,
  });

  Future<MarkdownDocument?> save(MarkdownDocument document);

  Future<MarkdownDocument?> saveAs(MarkdownDocument document);

  Future<List<MarkdownDocument>> listDocuments();

  Future<String?> readDocument(Uri uri);

  Future<void> delete(Uri uri);

  Future<LibraryMetadata?> loadMetadata();

  Future<void> saveMetadata(LibraryMetadata metadata);
}

class DocumentReadException implements Exception {
  const DocumentReadException(this.message);

  final String message;

  @override
  String toString() => message;
}
