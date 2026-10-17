import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/foundation.dart';

import '../domain/ai_assistant.dart';
import '../domain/chat_message.dart';

/// เรียก Gemini ผ่าน Firebase AI Logic
///
/// API key อยู่ฝั่งเซิร์ฟเวอร์ของ Firebase ไม่อยู่ในแอป
/// App Check เปิดให้ทั้งแอปใน main.dart AI Logic จึงรับเฉพาะคำขอจากแอปที่ผ่านการยืนยัน
class FirebaseAiAssistant implements AiAssistant {
  const FirebaseAiAssistant();

  static const modelName = 'gemini-3.8-flash';

  static const _systemPrompt =
      'คุณคือผู้ช่วยในแอปจดโน้ต MNote ตอบเป็นภาษาเดียวกับผู้ใช้ กระชับ '
      'จัดรูปแบบด้วย Markdown และถ้าผู้ใช้ขอผังหรือไดอะแกรม '
      'ให้ตอบเป็นบล็อกโค้ด mermaid '
      'คุณมองไม่เห็นและแก้ไขโน้ตของผู้ใช้ไม่ได้ '
      'ถ้าผู้ใช้ขอให้อ่าน แก้ หรือลบโน้ต ให้บอกตรง ๆ ว่าทำไม่ได้ '
      'แล้วเขียนข้อความที่ต้องการให้ผู้ใช้คัดลอกไปวางเอง '
      'ห้ามบอกว่าได้แก้ไขหรืออ่านโน้ตแล้ว';

  static GenerativeModel? _model;

  @override
  Stream<String> sendMessage(
    String text, {
    List<ChatMessage> history = const [],
    AiDocumentContext? document,
  }) async* {
    assert(document == null, 'ยังไม่รองรับการส่งเนื้อหาโน้ต');
    try {
      final model = _model ??= FirebaseAI.googleAI().generativeModel(
        model: modelName,
        systemInstruction: Content.system(_systemPrompt),
      );
      final chat = model.startChat(history: buildGeminiHistory(history));
      await for (final chunk in chat.sendMessageStream(Content.text(text))) {
        final part = chunk.text;
        if (part != null && part.isNotEmpty) yield part;
      }
    } on Exception catch (error) {
      debugPrint('AI request failed: ${describeAiError(error)}');
      throw aiErrorToException(error);
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

/// ข้อความสั้น ๆ สำหรับ log บอกแค่ชนิดของ error
///
/// ไม่พิมพ์ข้อความเต็ม เพราะอาจมีรายละเอียดภายในของโปรเจกต์
/// error ของ Firebase บอก plugin/code เช่น `firebase_app_check/unknown`
@visibleForTesting
String describeAiError(Object error) => error is FirebaseException
    ? '${error.plugin}/${error.code}'
    : error.runtimeType.toString();

/// แปลง error เป็นข้อความภาษาไทยที่บอกผู้ใช้ว่าเกิดอะไรขึ้น
@visibleForTesting
AiAssistantException aiErrorToException(Object error) {
  // QuotaExceeded เป็นลูกของ FirebaseAIException ต้องเช็กก่อน
  if (error is QuotaExceeded) {
    return const AiAssistantException(
      'ใช้ผู้ช่วย AI ครบโควตาแล้ว รอสักครู่แล้วลองใหม่ '
      'ถ้ายังไม่ได้ แปลว่าโควตาของวันนี้หมด ใช้ได้อีกครั้งพรุ่งนี้',
    );
  }
  if (error is FirebaseAIException) {
    return const AiAssistantException(
      'ผู้ช่วย AI ไม่พร้อมใช้งานชั่วคราว กรุณาลองใหม่ภายหลัง',
    );
  }
  if (error is FirebaseException && error.plugin == 'firebase_app_check') {
    return const AiAssistantException(
      'ยืนยันความปลอดภัยของแอปไม่สำเร็จ จึงใช้ผู้ช่วย AI ไม่ได้ในตอนนี้',
    );
  }
  return const AiAssistantException(
    'เชื่อมต่อผู้ช่วย AI ไม่สำเร็จ ตรวจสอบอินเทอร์เน็ตแล้วลองใหม่',
  );
}
