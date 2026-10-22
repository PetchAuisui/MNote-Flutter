import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/assistant/domain/ai_assistant.dart';
import 'package:mnote/features/assistant/domain/chat_message.dart';
import 'package:mnote/features/assistant/presentation/assistant_chat_controller.dart';
import '../../helpers/fake_ai_assistant.dart';

class _CustomStreamAssistant implements AiAssistant {
  final Stream<String> stream;
  int callCount = 0;

  _CustomStreamAssistant(this.stream);

  @override
  Stream<String> sendMessage(
    String text, {
    List<ChatMessage> history = const [],
    AiDocumentContext? document,
  }) {
    callCount++;
    return stream;
  }
}

/// ครั้งแรกตอบได้ครึ่งเดียวแล้วล้ม ครั้งต่อไปตอบจบ
class _FailOnceAssistant implements AiAssistant {
  int calls = 0;
  List<ChatMessage>? lastHistory;

  @override
  Stream<String> sendMessage(
    String text, {
    List<ChatMessage> history = const [],
    AiDocumentContext? document,
  }) async* {
    calls++;
    lastHistory = history;
    yield 'ตอบไม่จบ';
    if (calls == 1) throw const AiAssistantException('ล้ม');
    yield 'ครบ';
  }
}

void main() {
  group('AssistantChatController Tests', () {
    test(
      '1. should add user and assistant messages, concatenate chunks, and set isResponding to false',
      () async {
        final fakeAssistant = FakeAiAssistant(chunks: ['สวัสดี', 'ครับ']);
        final controller = AssistantChatController(fakeAssistant);

        await controller.send('สวัสดี');

        expect(controller.messages.length, 2);
        expect(controller.messages[0].role, ChatRole.user);
        expect(controller.messages[0].text, 'สวัสดี');
        expect(controller.messages[1].role, ChatRole.assistant);
        expect(controller.messages[1].text, 'สวัสดีครับ');
        expect(controller.isResponding, isFalse);
        expect(controller.errorMessage, isNull);
      },
    );

    test(
      '2. should not call assistant when message is empty or whitespace only',
      () async {
        final fakeAssistant = FakeAiAssistant();
        final controller = AssistantChatController(fakeAssistant);

        await controller.send('');
        await controller.send('   ');

        expect(fakeAssistant.callCount, 0);
        expect(controller.messages, isEmpty);
      },
    );

    test('3. should trim message before sending to assistant', () async {
      final fakeAssistant = FakeAiAssistant();
      final controller = AssistantChatController(fakeAssistant);

      await controller.send('  ข้อความทดสอบ  ');

      expect(fakeAssistant.lastText, 'ข้อความทดสอบ');
      expect(controller.messages.first.text, 'ข้อความทดสอบ');
    });

    test(
      '4. (Security) should reject message longer than 2000 chars without calling assistant',
      () async {
        final fakeAssistant = FakeAiAssistant();
        final controller = AssistantChatController(fakeAssistant);

        final longText = 'a' * (AssistantChatController.maxInputLength + 1);
        await controller.send(longText);

        expect(fakeAssistant.callCount, 0);
        expect(
          controller.errorMessage,
          'ข้อความยาวเกินไป (สูงสุด 2000 ตัวอักษร)',
        );
        expect(controller.messages, isEmpty);
      },
    );

    test(
      '5. should send prior messages as history in second turn without new message included',
      () async {
        final fakeAssistant = FakeAiAssistant();
        final controller = AssistantChatController(fakeAssistant);

        await controller.send('ข้อความแรก');
        await controller.send('ข้อความที่สอง');

        expect(fakeAssistant.lastHistory?.length, 2);
        expect(fakeAssistant.lastHistory?[0].text, 'ข้อความแรก');
        expect(fakeAssistant.lastHistory?[1].text, 'สวัสดีครับ');
        expect(fakeAssistant.lastText, 'ข้อความที่สอง');
      },
    );

    test(
      '6. (Security) should cap history length at 20 messages after 15 turns',
      () async {
        final fakeAssistant = FakeAiAssistant();
        final controller = AssistantChatController(fakeAssistant);

        for (int i = 1; i <= 15; i++) {
          await controller.send('ข้อความ $i');
        }

        expect(controller.messages.length, 30);

        await controller.send('ข้อความ 16');
        expect(
          fakeAssistant.lastHistory?.length,
          AssistantChatController.maxHistoryMessages,
        );
        expect(fakeAssistant.lastHistory?.length, 20);
      },
    );

    test(
      '7. should handle AiAssistantException before any chunk and remove empty bubble',
      () async {
        final fakeAssistant = FakeAiAssistant(
          chunks: [],
          error: const AiAssistantException('ข้อความทดสอบ'),
        );
        final controller = AssistantChatController(fakeAssistant);

        await controller.send('ส่งข้อความ');

        expect(controller.errorMessage, 'ข้อความทดสอบ');
        expect(controller.messages, isEmpty);
        expect(controller.isResponding, isFalse);
      },
    );

    test(
      '8. should show generic error and discard partial answer on unexpected error',
      () async {
        final fakeAssistant = FakeAiAssistant(
          chunks: ['ตอบบางส่วน'],
          error: StateError('Unexpected error'),
        );
        final controller = AssistantChatController(fakeAssistant);

        await controller.send('ส่งข้อความ');

        expect(controller.errorMessage, 'AI ตอบไม่สำเร็จ กรุณาลองใหม่');
        expect(controller.messages, isEmpty);
        expect(controller.isResponding, isFalse);
      },
    );

    test(
      '9. should ignore repeated send calls while still responding',
      () async {
        final streamController = StreamController<String>();
        final customAssistant = _CustomStreamAssistant(streamController.stream);
        final controller = AssistantChatController(customAssistant);

        final firstCall = controller.send('ข้อความแรก');
        expect(controller.isResponding, isTrue);

        await controller.send('ข้อความซ้ำ');
        expect(customAssistant.callCount, 1);

        streamController.add('ตอบ');
        await streamController.close();
        await firstCall;

        expect(controller.isResponding, isFalse);
      },
    );

    test('10. clear() should reset messages and errorMessage', () async {
      final fakeAssistant = FakeAiAssistant();
      final controller = AssistantChatController(fakeAssistant);

      await controller.send('ข้อความ');
      expect(controller.messages, isNotEmpty);

      controller.clear();
      expect(controller.messages, isEmpty);
      expect(controller.errorMessage, isNull);
    });

    test(
      '11. disposing controller while responding should complete future without hanging',
      () async {
        final streamController = StreamController<String>();
        final customAssistant = _CustomStreamAssistant(streamController.stream);
        final controller = AssistantChatController(customAssistant);

        final sending = controller.send('ข้อความ');
        expect(controller.isResponding, isTrue);

        controller.dispose();
        streamController.add('ข้อมูลหลังจาก dispose');
        await streamController.close();

        await expectLater(
          sending.timeout(const Duration(seconds: 1)),
          completes,
        );
      },
    );

    test(
      '12. document passed to assistant must be null for privacy guarantee',
      () async {
        final fakeAssistant = FakeAiAssistant();
        final controller = AssistantChatController(fakeAssistant);

        await controller.send('ทดสอบความเป็นส่วนตัว');

        expect(fakeAssistant.lastDocument, isNull);
      },
    );

    test(
      '13. (Security) Thai text counts visible characters, not code units',
      () async {
        final fake = FakeAiAssistant();
        final controller = AssistantChatController(fake);
        final thai = 'กี' * 2000; // เห็น 2000 ตัว แต่ length = 4000

        await controller.send(thai);

        expect(fake.callCount, 1);
        expect(controller.errorMessage, isNull);
      },
    );

    test('14. send returns true on success and false on error', () async {
      final ok = AssistantChatController(FakeAiAssistant());
      expect(await ok.send('สวัสดี'), isTrue);

      final failing = AssistantChatController(
        FakeAiAssistant(error: const AiAssistantException('ล้ม')),
      );
      expect(await failing.send('สวัสดี'), isFalse);
      expect(await failing.send('   '), isFalse);
    });

    test('15. interrupted answer is not sent as history next turn', () async {
      final assistant = _FailOnceAssistant();
      final controller = AssistantChatController(assistant);

      expect(await controller.send('ครั้งแรก'), isFalse);
      expect(controller.messages, isEmpty);

      expect(await controller.send('ครั้งที่สอง'), isTrue);
      expect(assistant.lastHistory, isEmpty);
      expect(controller.messages.length, 2);
    });
    test('16. empty answer counts as failure and is rolled back', () async {
      final controller = AssistantChatController(FakeAiAssistant(chunks: []));

      expect(await controller.send('สวัสดี'), isFalse);
      expect(controller.messages, isEmpty);
      expect(controller.errorMessage, contains('ไม่ได้ส่งคำตอบ'));
    });
  });
}
