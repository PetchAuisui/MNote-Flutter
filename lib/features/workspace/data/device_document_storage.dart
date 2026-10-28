import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:mnote/features/workspace/data/database/library_database.dart';
import 'package:mnote/features/workspace/data/database/library_database_native.dart';
import 'package:mnote/features/workspace/data/document_storage.dart';
import 'package:mnote/models/note_item.dart';
import 'package:path_provider/path_provider.dart';

class DeviceDocumentStorage implements DocumentStorage {
  const DeviceDocumentStorage();

  static const _documentExtensions = ['md', 'markdown', 'txt'];

  @override
  Future<SelectedDocumentFile?> pickDocument() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Open Markdown document',
      type: FileType.custom,
      allowedExtensions: _documentExtensions,
    );
    if (file == null) return null;

    return SelectedDocumentFile(
      name: file.name,
      uri: file.uri,
      bytes: await file.readAsBytes(),
    );
  }

  @override
  Future<Uri?> saveAs({required String name, required Uint8List bytes}) {
    return FilePicker.saveFile(
      dialogTitle: 'Save Markdown document',
      fileName: name,
      bytes: bytes,
      mimeType: 'text/markdown',
      type: FileType.custom,
      allowedExtensions: _documentExtensions,
    );
  }

  @override
  Future<Uri?> createDocument({
    required String name,
    required Uint8List bytes,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final file = File('${appDir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    return file.uri;
  }

  @override
  Future<void> write(Uri uri, Uint8List bytes) {
    if (uri.scheme != 'file') {
      throw const FileSystemException('The selected URI is not writable.');
    }
    return File.fromUri(uri).writeAsBytes(bytes, flush: true);
  }

  @override
  Future<Uint8List?> read(Uri uri) async {
    if (uri.scheme == 'file') {
      final file = File.fromUri(uri);
      if (await file.exists()) {
        return file.readAsBytes();
      }
    }
    return null;
  }

  @override
  Future<List<SelectedDocumentFile>> listDocuments() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(appDir.path);
    if (!await dir.exists()) return [];

    final result = <SelectedDocumentFile>[];
    final files = dir.listSync().whereType<File>();

    for (final file in files) {
      final ext = file.path.split('.').last.toLowerCase();
      if (_documentExtensions.contains(ext)) {
        final filename = file.uri.pathSegments.last;
        final bytes = await file.readAsBytes();
        result.add(
          SelectedDocumentFile(name: filename, uri: file.uri, bytes: bytes),
        );
      }
    }
    return result;
  }

  @override
  Future<void> delete(Uri uri) async {
    if (uri.scheme == 'file') {
      final file = File.fromUri(uri);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  @override
  Future<Uri> relocate(Uri uri) async {
    if (uri.scheme != 'file' || await File.fromUri(uri).exists()) return uri;
    if (uri.pathSegments.isEmpty) return uri;
    final appDir = await getApplicationDocumentsDirectory();
    // pathSegments are percent-encoded; File wants the decoded name.
    final moved = File(
      '${appDir.path}/${Uri.decodeComponent(uri.pathSegments.last)}',
    );
    if (await moved.exists()) return moved.uri;
    return uri;
  }

  /// One connection per app run, shared by every storage instance.
  static LibraryDatabase? _database;

  static LibraryDatabase get _db => _database ??= openLibraryDatabase();

  /// The index from before the SQLite database existed.
  Future<File> _legacyIndex() async {
    final appDir = await getApplicationDocumentsDirectory();
    return File('${appDir.path}/.mnote_library.json');
  }

  @override
  Future<String?> readMetadata() async {
    if (await _db.isEmpty()) {
      final legacy = await _legacyIndex();
      if (await legacy.exists()) {
        try {
          await _db.importLegacyJson(await legacy.readAsString());
          // Set the old file aside so deleting every note later cannot make
          // an empty database import it again.
          await legacy.rename('${legacy.path}.migrated');
        } catch (_) {
          // An unreadable old index is treated as no index, as before.
          return null;
        }
      }
    }
    final library = await _db.loadLibrary();
    if (library.folders.isEmpty && library.documents.isEmpty) return null;
    return jsonEncode(library.toJson());
  }

  @override
  Future<void> writeMetadata(String content) {
    return _db.replaceLibrary(
      LibraryMetadata.fromJson(jsonDecode(content) as Map<String, dynamic>),
    );
  }
}
