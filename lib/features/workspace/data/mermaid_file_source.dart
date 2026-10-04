import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// ข้อมูลไฟล์ Mermaid ที่ผู้ใช้เลือกจากเครื่อง
final class PickedMermaidFile {
  const PickedMermaidFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// อินเทอร์เฟซสำหรับการเลือกไฟล์ Mermaid จากอุปกรณ์
abstract interface class MermaidFileSource {
  Future<PickedMermaidFile?> pick();
}

/// การเลือกไฟล์ Mermaid ผ่าน FilePicker ของระบบ
class DeviceMermaidFileSource implements MermaidFileSource {
  const DeviceMermaidFileSource();

  @override
  Future<PickedMermaidFile?> pick() async {
    final file = await FilePicker.pickFile(type: FileType.any);

    if (file == null) {
      return null;
    }

    return PickedMermaidFile(name: file.name, bytes: await file.readAsBytes());
  }
}
