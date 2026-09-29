import 'dart:convert';
import 'dart:typed_data';

import 'package:mnote/features/workspace/data/document_storage.dart';
import 'package:mnote/features/workspace/domain/document_repository.dart';
import 'package:mnote/features/workspace/domain/markdown_document.dart';

class LocalDocumentRepository implements DocumentRepository {
  const LocalDocumentRepository(this._storage);

  final DocumentStorage _storage;

  @override
  Future<MarkdownDocument?> open() async {
    final file = await _storage.pickDocument();
    if (file == null) return null;

    try {
      final content = utf8.decode(_withoutByteOrderMark(file.bytes));
      return MarkdownDocument.opened(
        name: file.name,
        content: content,
        uri: file.uri,
      );
    } on FormatException {
      throw const DocumentReadException(
        'ไฟล์นี้ไม่ใช่ข้อความ UTF-8 ที่ Mnote รองรับ',
      );
    }
  }

  @override
  Future<MarkdownDocument?> save(MarkdownDocument document) async {
    final uri = document.uri;
    if (uri == null || uri.scheme != 'file') return saveAs(document);

    await _storage.write(uri, _encode(document.content));
    return document.markSaved(name: document.name, uri: uri);
  }

  @override
  Future<MarkdownDocument?> saveAs(MarkdownDocument document) async {
    final uri = await _storage.saveAs(
      name: _ensureMarkdownExtension(document.name),
      bytes: _encode(document.content),
    );
    if (uri == null) return null;

    return document.markSaved(name: _nameFrom(uri, document.name), uri: uri);
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
