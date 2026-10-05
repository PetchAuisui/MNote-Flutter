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
  /// เลือกไฟล์และอ่านไม่เกิน [maxBytes] + 1 byte
  ///
  /// ถ้าไฟล์ใหญ่กว่า [maxBytes] จะได้ bytes ยาว [maxBytes] + 1 พอให้ผู้เรียกรู้ว่าเกิน
  /// โดยไม่ต้องโหลดทั้งไฟล์เข้าหน่วยความจำ คืน `null` เมื่อผู้ใช้กดยกเลิก
  Future<PickedMermaidFile?> pick({required int maxBytes});
}

/// การเลือกไฟล์ Mermaid ผ่าน FilePicker ของระบบ
///
/// อ่านด้วย `readAsByteStream` ไม่ใช้ `readAsBytes` (โหลดทั้งไฟล์) หรือ `length`
/// (อาจอ่านทั้งไฟล์เพื่อหาขนาดเมื่อระบบไม่ได้บอกมา)
class DeviceMermaidFileSource implements MermaidFileSource {
  const DeviceMermaidFileSource();

  @override
  Future<PickedMermaidFile?> pick({required int maxBytes}) async {
    final file = await FilePicker.pickFile(type: FileType.any);
    if (file == null) return null;
    return PickedMermaidFile(
      name: file.name,
      bytes: await readLimitedBytes(file.readAsByteStream(), maxBytes + 1),
    );
  }
}

/// อ่าน [stream] จนครบ [limit] byte แล้วหยุด
///
/// การ `break` ออกจาก `await for` ยกเลิกการอ่านไฟล์ส่วนที่เหลือทันที
/// ไฟล์ใหญ่แค่ไหนก็ใช้หน่วยความจำไม่เกิน [limit]
Future<Uint8List> readLimitedBytes(Stream<List<int>> stream, int limit) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    final remaining = limit - builder.length;
    if (chunk.length >= remaining) {
      builder.add(chunk.sublist(0, remaining));
      break;
    }
    builder.add(chunk);
  }
  return builder.takeBytes();
}