import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

abstract interface class InkFileStorage {
  Future<bool> save({required String name, required Uint8List bytes});

  Future<Uint8List?> open();

  Future<bool> autoSave({required String name, required Uint8List bytes});

  Future<Uint8List?> autoLoad({required String name});
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

  @override
  Future<bool> autoSave({required String name, required Uint8List bytes}) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}/$name.ink.json');
      await file.writeAsBytes(bytes, flush: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Uint8List?> autoLoad({required String name}) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}/$name.ink.json');
      if (await file.exists()) {
        return file.readAsBytes();
      }
    } catch (_) {}
    return null;
  }
}
