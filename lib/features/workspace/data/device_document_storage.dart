import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:mnote/features/workspace/data/document_storage.dart';

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
}
