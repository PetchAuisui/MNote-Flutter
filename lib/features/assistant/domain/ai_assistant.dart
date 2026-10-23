import 'chat_message.dart';

/// เนื้อหาโน้ตที่แนบให้ AI อ่านพร้อมคำถาม
///
/// ผู้ใช้เห็นชิปและเอาออกได้ก่อนส่งเสมอ
/// เนื้อหาจะไม่ถูกเก็บในประวัติแชท ส่งเฉพาะข้อความที่แนบเท่านั้น
final class AiDocumentContext {
  /// จำกัดความยาวเพื่อคุมโควตา เกินแล้วแจ้ง error ไม่ตัดทิ้ง
  static const int maxContentLength = 20000;

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
