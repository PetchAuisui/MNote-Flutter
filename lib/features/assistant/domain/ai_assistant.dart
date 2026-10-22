import 'chat_message.dart';

/// เนื้อหาโน้ตที่ผู้ใช้เลือกแนบให้ AI อ่าน ตอนนี้ยังไม่ส่งจริง เตรียมไว้สำหรับฟีเจอร์ในอนาคต
final class AiDocumentContext {
  final String title;
  final String content;

  const AiDocumentContext({required this.title, required this.content});
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
