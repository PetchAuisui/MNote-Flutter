import 'chat_message.dart';

/// เนื้อหาโน้ตที่แนบให้ AI อ่านพร้อมคำถาม
///
/// ผู้ใช้เห็นชิปและเอาออกได้ก่อนส่งเสมอ
/// เนื้อหาจะไม่ถูกเก็บในประวัติแชท ส่งเฉพาะข้อความที่แนบเท่านั้น
final class AiDocumentContext {
  /// เพดานจริงของแผนฟรีโดยประมาณ (TPM 250K token × ~4 ตัวอักษรต่อ token)
  /// เกินนี้ Gemini ไม่รับอยู่แล้ว ตรวจไว้เพื่อแจ้งผู้ใช้ให้ชัดเจน
  static const int maxContentLength = 1000000;

  /// จำนวน token สูงสุดของข้อความที่แนบโน้ต
  ///
  /// ภาษาไทยอาจใช้ token ต่อตัวอักษรมากกว่าภาษาอังกฤษ ลิมิตตัวอักษรอย่างเดียว
  /// จึงไม่พอ โน้ตยาวจะถูกนับ token จริงก่อนส่ง เว้นที่ไว้ให้ system prompt
  /// และประวัติแชทใต้ TPM 250K ของแผนฟรี
  static const int maxPromptTokens = 200000;

  final String title;
  final String content;

  const AiDocumentContext({required this.title, required this.content});

  bool get isTooLong => content.length > maxContentLength;
}

final class AiAssistantException implements Exception {
  final String message;

  const AiAssistantException(this.message);

  @override
  String toString() => 'AiAssistantException: $message';
}

abstract interface class AiAssistant {
  /// คืนคำตอบทีละชิ้น ผิดพลาดให้ส่ง AiAssistantException
  Stream<String> sendMessage(
    String text, {
    List<ChatMessage> history = const [],
    AiDocumentContext? document,
  });
}
