import 'dart:io';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/assistant/data/firebase_ai_assistant.dart';
import 'package:mnote/features/assistant/domain/ai_assistant.dart';
import 'package:mnote/features/assistant/domain/chat_message.dart';

void main() {
  group('FirebaseAiAssistant & buildGeminiHistory Tests', () {
    // 1. ประวัติว่าง → ได้ list ว่าง
    test('1. empty messages returns empty Content list', () {
      final history = buildGeminiHistory([]);
      expect(history, isEmpty);
    });

    // 2. [user 'ก', ai 'ข'] → ได้ 2 รายการ, role เป็น 'user' กับ 'model', และ text เป็น 'ก' กับ 'ข'
    test(
      '2. single valid user and assistant pair maps correctly to user and model Content',
      () {
        final messages = [
          const ChatMessage(role: ChatRole.user, text: 'ก'),
          const ChatMessage(role: ChatRole.assistant, text: 'ข'),
        ];

        final history = buildGeminiHistory(messages);

        expect(history.length, 2);
        expect(history[0].role, 'user');
        expect((history[0].parts.first as TextPart).text, 'ก');
        expect(history[1].role, 'model');
        expect((history[1].parts.first as TextPart).text, 'ข');
      },
    );

    // 3. [user 'ก', user 'ค', ai 'ง'] → ได้แค่คู่ 'ค'/'ง'
    test(
      '3. consecutive user messages skip the first unpaired user message and pair last user with assistant',
      () {
        final messages = [
          const ChatMessage(role: ChatRole.user, text: 'ก'),
          const ChatMessage(role: ChatRole.user, text: 'ค'),
          const ChatMessage(role: ChatRole.assistant, text: 'ง'),
        ];

        final history = buildGeminiHistory(messages);

        expect(history.length, 2);
        expect(history[0].role, 'user');
        expect((history[0].parts.first as TextPart).text, 'ค');
        expect(history[1].role, 'model');
        expect((history[1].parts.first as TextPart).text, 'ง');
      },
    );

    // 4. [user 'ก', ai ''] → ได้ list ว่าง (ข้ามคำตอบที่ว่าง)
    test(
      '4. user message paired with empty assistant response is excluded',
      () {
        final messages = [
          const ChatMessage(role: ChatRole.user, text: 'ก'),
          const ChatMessage(role: ChatRole.assistant, text: ''),
        ];

        final history = buildGeminiHistory(messages);

        expect(history, isEmpty);
      },
    );

    // 5. expect(const FirebaseAiAssistant(), isA<AiAssistant>())
    test('5. FirebaseAiAssistant implements AiAssistant interface', () {
      const assistant = FirebaseAiAssistant();
      expect(assistant, isA<AiAssistant>());
    });
  });

  group('aiErrorToException', () {
    test('quota exceeded tells the user the quota is used up', () {
      final result = aiErrorToException(QuotaExceeded('Quota exceeded'));
      expect(result.message, contains('โควตา'));
    });

    test('other Firebase AI errors show the unavailable message', () {
      final result = aiErrorToException(ServerException('boom'));
      expect(result.message, contains('ไม่พร้อมใช้งาน'));
    });

    test('App Check failure shows the app verification message', () {
      final error = FirebaseException(
        plugin: 'firebase_app_check',
        code: 'unknown',
        message: '403 App attestation failed',
      );
      final result = aiErrorToException(error);
      expect(result.message, contains('ยืนยันความปลอดภัย'));
      expect(result.message, isNot(contains('อินเทอร์เน็ต')));
    });

    test('network errors show the connection message', () {
      final result = aiErrorToException(const SocketException('offline'));
      expect(result.message, contains('อินเทอร์เน็ต'));
    });

    test('(Security) log text never includes the error message', () {
      final appCheck = FirebaseException(
        plugin: 'firebase_app_check',
        code: 'unknown',
        message: 'internal project detail',
      );
      expect(describeAiError(appCheck), 'firebase_app_check/unknown');
      expect(
        describeAiError(QuotaExceeded('internal project detail')),
        isNot(contains('internal')),
      );
    });
  });
}
