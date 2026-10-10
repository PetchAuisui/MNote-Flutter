import 'dart:convert';
import 'dart:typed_data';

import 'package:mnote/features/workspace/data/document_storage.dart';
import 'package:mnote/features/workspace/domain/document_repository.dart';
import 'package:mnote/features/workspace/domain/markdown_document.dart';
import 'package:mnote/models/note_item.dart';

class LocalDocumentRepository implements DocumentRepository {
  const LocalDocumentRepository(this._storage);

  final DocumentStorage _storage;

  @override
  Future<MarkdownDocument?> open() async {
    final file = await _storage.pickDocument();
    if (file == null) return null;

    try {
      final content = utf8.decode(_withoutByteOrderMark(file.bytes));
      final doc = MarkdownDocument.opened(
        name: file.name,
        content: content,
        uri: file.uri,
      );

      // บันทึกเข้า Metadata ป้องกันไฟล์หาย
      await _registerToMetadata(doc);

      return doc;
    } on FormatException {
      throw const DocumentReadException(
        'ไฟล์นี้ไม่ใช่ข้อความ UTF-8 ที่ Mnote รองรับ',
      );
    }
  }

  @override
  Future<MarkdownDocument?> save(MarkdownDocument document) async {
    var uri = document.uri;
    if (uri == null || uri.scheme.isEmpty) {
      final targetName = _ensureMarkdownExtension(document.name);
      uri = await _storage.createDocument(
        name: targetName,
        bytes: _encode(document.content),
      );
      if (uri == null) return saveAs(document);
      final savedDoc = document.markSaved(name: document.name, uri: uri);
      await _registerToMetadata(savedDoc);
      return savedDoc;
    }

    final currentFileName = _nameFrom(uri, document.name);
    final targetFileName = _ensureMarkdownExtension(document.name);

    if (uri.scheme != 'file' ||
        targetFileName != _ensureMarkdownExtension(currentFileName)) {
      return saveAs(document);
    }

    try {
      await _storage.write(uri, _encode(document.content));
    } catch (_) {
      try {
        final newUri = await _storage.createDocument(
          name: targetFileName,
          bytes: _encode(document.content),
        );
        if (newUri == null) return null;
        uri = newUri;
      } catch (_) {
        return null;
      }
    }

    final savedDoc = document.markSaved(name: document.name, uri: uri);
    await _registerToMetadata(savedDoc);
    return savedDoc;
  }

  @override
  Future<MarkdownDocument?> saveAs(MarkdownDocument document) async {
    final uri = await _storage.saveAs(
      name: _ensureMarkdownExtension(document.name),
      bytes: _encode(document.content),
    );
    if (uri == null) return null;

    final savedDoc = document.markSaved(
      name: _nameFrom(uri, document.name),
      uri: uri,
    );
    await _registerToMetadata(savedDoc);
    return savedDoc;
  }

  @override
  Future<List<MarkdownDocument>> listDocuments() async {
    try {
      final metadata = await loadMetadata();
      final documents = <MarkdownDocument>[];
      final seenUris = <String>{};

      // 1. อ่านไฟล์จาก Metadata (ข้ามไฟล์ที่อยู่ในถังขยะ isTrash)
      if (metadata != null) {
        for (final docItem in metadata.documents) {
          if (docItem.isTrash) continue;

          final uri = docItem.uri;
          if (uri != null) {
            seenUris.add(uri.toString());
            final content = await readDocument(uri);
            if (content != null) {
              documents.add(
                MarkdownDocument.opened(
                  name: docItem.name,
                  content: content,
                  uri: uri,
                ),
              );
            }
          }
        }
      }

      // 2. สแกนไฟล์ตกค้างใน App Documents Directory
      final files = await _storage.listDocuments();
      for (final file in files) {
        if (seenUris.contains(file.uri.toString())) continue;

        try {
          final content = utf8.decode(_withoutByteOrderMark(file.bytes));
          documents.add(
            MarkdownDocument.opened(
              name: _nameFrom(file.uri, file.name),
              content: content,
              uri: file.uri,
            ),
          );
        } on FormatException {
          continue;
        }
      }

      return documents;
    } catch (e) {
      throw DocumentReadException('ไม่สามารถดึงรายการเอกสารได้: $e');
    }
  }

  @override
  Future<String?> readDocument(Uri uri) async {
    try {
      final bytes = await _storage.read(uri);
      if (bytes == null) return null;
      return utf8.decode(_withoutByteOrderMark(bytes));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> delete(Uri uri) async {
    // 1. ลบ physical file จริงออกจากเครื่อง
    await _storage.delete(uri);

    // 2. ลบออกจาก Metadata JSON
    final metadata = await loadMetadata();
    if (metadata != null) {
      final updatedDocs = metadata.documents
          .where((doc) => doc.uri?.toString() != uri.toString())
          .toList();
      await saveMetadata(
        LibraryMetadata(
          folders: metadata.folders,
          documents: updatedDocs,
        ),
      );
    }
  }

  @override
  Future<LibraryMetadata?> loadMetadata() async {
    try {
      final raw = await _storage.readMetadata();
      if (raw == null || raw.trim().isEmpty) return null;
      return LibraryMetadata.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveMetadata(LibraryMetadata metadata) async {
    await _storage.writeMetadata(jsonEncode(metadata.toJson()));
  }

  Future<void> _registerToMetadata(MarkdownDocument doc) async {
    final uri = doc.uri;
    if (uri == null) return;

    final metadata = await loadMetadata() ?? const LibraryMetadata();
    final uriStr = uri.toString();

    final existingIndex = metadata.documents.indexWhere(
      (d) => d.uri?.toString() == uriStr,
    );
    final updatedDocs = List<DocumentItem>.from(metadata.documents);

    if (existingIndex >= 0) {
      final old = updatedDocs[existingIndex];
      updatedDocs[existingIndex] = old.copyWith(
        name: doc.name,
        content: doc.content,
        updatedAt: DateTime.now(),
      );
    } else {
      updatedDocs.add(
        DocumentItem(
          id: uriStr,
          name: doc.name,
          content: doc.content,
          updatedAt: DateTime.now(),
          uri: uri,
          isTrash: false,
          isStarred: false,
        ),
      );
    }

    await saveMetadata(
      LibraryMetadata(
        folders: metadata.folders,
        documents: updatedDocs,
      ),
    );
  }

  Uint8List _encode(String content) => Uint8List.fromList(utf8.encode(content));

  List<int> _withoutByteOrderMark(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return bytes.sublist(3);
    }
    return bytes;
  }

  String _ensureMarkdownExtension(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.endsWith('.md') ||
        lowerName.endsWith('.markdown') ||
        lowerName.endsWith('.txt')) {
      return name;
    }
    return '$name.md';
  }

  String _nameFrom(Uri uri, String fallback) {
    if (uri.pathSegments.isEmpty) return fallback;
    return Uri.decodeComponent(uri.pathSegments.last);
  }
}