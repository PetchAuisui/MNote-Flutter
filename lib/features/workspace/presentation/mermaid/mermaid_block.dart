/// ค่าคงที่สำหรับคลาสของแท็ก code ที่เป็นภาษา Mermaid
const String _mermaidClass = 'language-mermaid';

/// ตรวจสอบว่าคลาสของ code block คือภาษา Mermaid หรือไม่
///
/// คืนค่า `true` เมื่อระบุคลาสเป็น 'language-mermaid' โดยไม่สนใจตัวพิมพ์เล็ก-ใหญ่
/// และคืนค่า `false` หากเป็น null หรือภาษาอื่น เพื่อป้องกันการจับผิดเป็น 'language-mermaidjs'
bool isMermaidCodeClass(String? className) {
  if (className == null) {
    return false;
  }
  return className.trim().toLowerCase() == _mermaidClass;
}

/// ทำความสะอาดและปรับแต่งข้อความ Mermaid ก่อนนำไปประมวลผล
///
/// แปลงรูปแบบขึ้นบรรทัดใหม่จาก CRLF (\r\n) ให้เป็น LF (\n) เพื่อความเข้ากันได้
/// พร้อมตัดช่องว่างและบรรทัดว่างส่วนเกินที่หัวและท้ายข้อความออก โดยยังคงย่อหน้าภายในไว้
String normalizeMermaidSource(String raw) {
  // แปลง \r\n (Windows CRLF) เป็น \n (LF)
  final normalizedLineEndings = raw.replaceAll('\r\n', '\n');

  // ตัดช่องว่างและ \n ส่วนเกินที่หัวและท้ายข้อความออก
  return normalizedLineEndings.trim();
}
