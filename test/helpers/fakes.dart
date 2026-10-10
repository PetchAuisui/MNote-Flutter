import 'dart:typed_data';

import 'package:mnote/features/workspace/data/device_image_picker.dart';
import 'package:mnote/features/workspace/data/document_storage.dart';
import 'package:mnote/features/workspace/domain/document_repository.dart';
import 'package:mnote/features/workspace/domain/markdown_document.dart';
import 'package:mnote/models/note_item.dart';

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
  Future<Uri?> createDocument({required String name, required Uint8List bytes}) async {
    final uri = saveUri ?? Uri.file('/tmp/$name');
    await write(uri, bytes);
    return uri;
  }

  String? metadataContent;
  final List<Uri> deletedUris = [];

  final Map<Uri, Uint8List> fileData = {};

  @override
  Future<void> write(Uri uri, Uint8List bytes) async {
    writtenUri = uri;
    writtenBytes = bytes;
    fileData[uri] = bytes;
  }

  @override
  Future<Uint8List?> read(Uri uri) async => fileData[uri] ?? writtenBytes;

  @override
  Future<List<SelectedDocumentFile>> listDocuments() async => [];

  @override
  Future<void> delete(Uri uri) async {
    deletedUris.add(uri);
  }

  @override
  Future<String?> readMetadata() async => metadataContent;

  @override
  Future<void> writeMetadata(String content) async {
    metadataContent = content;
  }
}

class FakeDocumentRepository implements DocumentRepository {
  MarkdownDocument? openResult;
  MarkdownDocument? saveResult;
  List<MarkdownDocument> listResult = [];
  LibraryMetadata? storedMetadata;
  final List<Uri> deletedUris = [];
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

  final Map<Uri, String> documentContents = {};

  @override
  Future<String?> readDocument(Uri uri) async => documentContents[uri];

  @override
  Future<void> delete(Uri uri) async {
    deletedUris.add(uri);
  }

  Object? metadataError;

  @override
  Future<LibraryMetadata?> loadMetadata() async {
    if (metadataError case final err?) throw err;
    return storedMetadata;
  }

  @override
  Future<void> saveMetadata(LibraryMetadata metadata) async {
    if (metadataError case final err?) throw err;
    storedMetadata = metadata;
  }
}

class FakeDeviceImagePicker extends DeviceImagePicker {
  FakeDeviceImagePicker([this.result]);
  final MarkdownImageReference? result;
  int pickCount = 0;

  @override
  Future<MarkdownImageReference?> pick() async {
    pickCount++;
    return result;
  }
}
