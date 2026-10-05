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
    final uri = document.uri;
    if (uri == null ||
        uri.scheme != 'file' ||
        document.name != _nameFrom(uri, document.name)) {
      return saveAs(document);
    }

    await _storage.write(uri, _encode(document.content));
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

      if (metadata != null) {
        for (final item in metadata.items) {
          if (item.isDeleted) continue;

          final uri = Uri.tryParse(item.uri);
          if (uri != null) {
            seenUris.add(uri.toString());
            final content = await readDocument(uri);
            if (content != null) {
              documents.add(
                MarkdownDocument.opened(
                  name: item.name,
                  content: content,
                  uri: uri,
                ),
              );
            }
          }
        }
      }

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
    await _storage.delete(uri);

    final metadata = await loadMetadata();
    if (metadata != null) {
      final updatedItems = metadata.items
          .where((item) => item.uri != uri.toString())
          .toList();
      await saveMetadata(metadata.copyWith(items: updatedItems));
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
    if (doc.uri == null) return;
    final metadata = await loadMetadata() ?? const LibraryMetadata(items: []);
    final uriStr = doc.uri.toString();

    final existingIndex = metadata.items.indexWhere((e) => e.uri == uriStr);
    final updatedItems = List<NoteItemMetadata>.from(metadata.items);

    if (existingIndex >= 0) {
      updatedItems[existingIndex] = updatedItems[existingIndex].copyWith(
        name: doc.name,
        updatedAt: DateTime.now(),
      );
    } else {
      updatedItems.add(
        NoteItemMetadata(
          id: uriStr,
          uri: uriStr,
          name: doc.name,
          updatedAt: DateTime.now(),
          isDeleted: false,
          isStarred: false,
        ),
      );
    }

    await saveMetadata(metadata.copyWith(items: updatedItems));
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