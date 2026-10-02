import 'package:mnote/features/workspace/domain/markdown_document.dart';
import 'package:mnote/models/note_item.dart';

abstract interface class DocumentRepository {
  Future<MarkdownDocument?> open();

  Future<MarkdownDocument?> save(MarkdownDocument document);

  Future<MarkdownDocument?> saveAs(MarkdownDocument document);

  Future<List<MarkdownDocument>> listDocuments();

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
