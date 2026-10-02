import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

abstract interface class InkFileStorage {
  Future<bool> save({required String name, required Uint8List bytes});

  Future<Uint8List?> open();
}

class DeviceInkFileStorage implements InkFileStorage {
  const DeviceInkFileStorage();

  @override
  Future<bool> save({required String name, required Uint8List bytes}) async {
    final uri = await FilePicker.saveFile(
      dialogTitle: 'บันทึกหมึกแยกจาก Markdown',
      fileName: name,
      bytes: bytes,
      mimeType: 'application/json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    return uri != null;
  }

  @override
  Future<Uint8List?> open() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    return file?.readAsBytes();
  }
}
