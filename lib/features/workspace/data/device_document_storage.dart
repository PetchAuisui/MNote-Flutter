import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:mnote/features/workspace/data/document_storage.dart';
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
  Future<void> write(Uri uri, Uint8List bytes) {
    if (uri.scheme != 'file') {
      throw const FileSystemException('The selected URI is not writable.');
    }
    return File.fromUri(uri).writeAsBytes(bytes, flush: true);
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
          SelectedDocumentFile(
            name: filename,
            uri: file.uri,
            bytes: bytes,
          ),
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
  Future<String?> readMetadata() async {
    final appDir = await getApplicationDocumentsDirectory();
    final file = File('${appDir.path}/.mnote_library.json');
    if (await file.exists()) {
      return file.readAsString();
    }
    return null;
  }

  @override
  Future<void> writeMetadata(String content) async {
    final appDir = await getApplicationDocumentsDirectory();
    final file = File('${appDir.path}/.mnote_library.json');
    await file.writeAsString(content, flush: true);
  }
}

