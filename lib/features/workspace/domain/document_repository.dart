import 'package:mnote/features/workspace/domain/markdown_document.dart';

abstract interface class DocumentRepository {
  Future<MarkdownDocument?> open();

  Future<MarkdownDocument?> save(MarkdownDocument document);

  Future<MarkdownDocument?> saveAs(MarkdownDocument document);
}

class DocumentReadException implements Exception {
  const DocumentReadException(this.message);

  final String message;

  @override
  String toString() => message;
}
