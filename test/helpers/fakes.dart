import 'dart:typed_data';

import 'package:mnote/features/workspace/data/document_storage.dart';
import 'package:mnote/features/workspace/domain/document_repository.dart';
import 'package:mnote/features/workspace/domain/markdown_document.dart';

class FakeDocumentStorage implements DocumentStorage {
  SelectedDocumentFile? selectedFile;
  Uri? saveUri;
  Uri? writtenUri;
  Uint8List? writtenBytes;
  String? savedAsName;
  int saveAsCalls = 0;

  @override
  Future<SelectedDocumentFile?> pickDocument() async => selectedFile;

  @override
  Future<Uri?> saveAs({required String name, required Uint8List bytes}) async {
    saveAsCalls += 1;
    savedAsName = name;
    writtenBytes = bytes;
    return saveUri;
  }

  @override
  Future<void> write(Uri uri, Uint8List bytes) async {
    writtenUri = uri;
    writtenBytes = bytes;
  }

  @override
  Future<List<SelectedDocumentFile>> listDocuments() async => [];
}

class FakeDocumentRepository implements DocumentRepository {
  MarkdownDocument? openResult;
  MarkdownDocument? saveResult;
  List<MarkdownDocument> listResult = [];
  Object? error;
  int openCalls = 0;
  int saveCalls = 0;
  int listCalls = 0;

  @override
  Future<MarkdownDocument?> open() async {
    openCalls += 1;
    if (error case final error?) throw error;
    return openResult;
  }

  @override
  Future<MarkdownDocument?> save(MarkdownDocument document) async {
    saveCalls += 1;
    if (error case final error?) throw error;
    return saveResult ??
        document.markSaved(
          name: document.name,
          uri: document.uri ?? Uri.file('/tmp/${document.name}'),
        );
  }

  @override
  Future<MarkdownDocument?> saveAs(MarkdownDocument document) => save(document);

  @override
  Future<List<MarkdownDocument>> listDocuments() async {
    listCalls += 1;
    if (error case final error?) throw error;
    return listResult;
  }
}
