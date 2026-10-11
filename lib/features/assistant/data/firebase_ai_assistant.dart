import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

import '../../../core/app_check.dart';
import '../domain/ai_assistant.dart';
import '../domain/chat_message.dart';

/// เรียก Gemini ผ่าน Firebase AI Logic
///
/// API key อยู่ฝั่งเซิร์ฟเวอร์ของ Firebase ไม่อยู่ในแอป
/// และ AI Logic บังคับ App Check จึงรับเฉพาะคำขอจากแอปที่ผ่านการยืนยัน
class FirebaseAiAssistant implements AiAssistant {
  const FirebaseAiAssistant();

  static const modelName = 'gemini-3.8-flash';

  static const _systemPrompt =
      'คุณคือผู้ช่วยในแอปจดโน้ต MNote ตอบเป็นภาษาเดียวกับผู้ใช้ กระชับ '
      'จัดรูปแบบด้วย Markdown และถ้าผู้ใช้ขอผังหรือไดอะแกรม '
      'ให้ตอบเป็นบล็อกโค้ด mermaid';

  static GenerativeModel? _model;

  @override
  Stream<String> sendMessage(
    String text, {
    List<ChatMessage> history = const [],
    AiDocumentContext? document,
  }) async* {
    assert(document == null, 'ยังไม่รองรับการส่งเนื้อหาโน้ต');
    try {
      await ensureAppCheckActivated();
      final model = _model ??= FirebaseAI.googleAI().generativeModel(
        model: modelName,
        systemInstruction: Content.system(_systemPrompt),
      );
      final chat = model.startChat(history: buildGeminiHistory(history));
      await for (final chunk in chat.sendMessageStream(Content.text(text))) {
        final part = chunk.text;
        if (part != null && part.isNotEmpty) yield part;
      }
    } on FirebaseAIException catch (error) {
      debugPrint('Firebase AI error: ${error.runtimeType}');
      throw const AiAssistantException(
        'ผู้ช่วย AI ไม่พร้อมใช้งานชั่วคราว กรุณาลองใหม่ภายหลัง',
      );
    }
  }
}

/// แปลงบทสนทนาเป็นรูปแบบที่ Gemini รับ
///
/// Gemini ต้องการให้ผู้ใช้กับโมเดลสลับกันพูด จึงเก็บเฉพาะคู่
/// "ผู้ใช้ตามด้วยคำตอบที่ไม่ว่าง" ข้อความที่ตอบไม่สำเร็จจะถูกข้าม
@visibleForTesting
List<Content> buildGeminiHistory(List<ChatMessage> messages) {
  final result = <Content>[];
  for (var i = 0; i + 1 < messages.length; i++) {
    final question = messages[i];
    final answer = messages[i + 1];
    if (question.role == ChatRole.user &&
        answer.role == ChatRole.assistant &&
        answer.text.trim().isNotEmpty) {
      result
        ..add(Content.text(question.text))
        ..add(Content.model([TextPart(answer.text)]));
      i++;
    }
  }
  return result;
}
