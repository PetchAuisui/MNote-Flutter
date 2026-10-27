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
      '12. (Security) no document is sent without a document provider',
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

    // 17. แนบเป็นค่าเริ่มต้น isNoteAttached เป็น true และ attachedNoteTitle ได้ 'a.md'
    test(
      '17. note is attached by default with valid title and isNoteAttached as true',
      () {
        const note = AiDocumentContext(title: 'a.md', content: 'เนื้อหา');
        final controller = AssistantChatController(
          FakeAiAssistant(),
          documentProvider: () => note,
        );

        expect(controller.canAttachNote, isTrue);
        expect(controller.isNoteAttached, isTrue);
        expect(controller.attachedNoteTitle, 'a.md');
      },
    );

    // 18. ส่งโน้ตไปจริง fake.lastDocument?.content == 'เนื้อหา'
    test('18. actually sends attached document content to assistant', () async {
      final fake = FakeAiAssistant();
      const note = AiDocumentContext(title: 'a.md', content: 'เนื้อหา');
      final controller = AssistantChatController(
        fake,
        documentProvider: () => note,
      );

      await controller.send('สรุปให้หน่อย');

      expect(fake.lastDocument?.title, 'a.md');
      expect(fake.lastDocument?.content, 'เนื้อหา');
    });

    // 19. อ่านตอนส่ง เปลี่ยน note หลังสร้าง controller แล้วส่ง ต้องได้เนื้อหาใหม่
    test(
      '19. evaluates provider at send time so updated content is retrieved',
      () async {
        final fake = FakeAiAssistant();
        var note = const AiDocumentContext(
          title: 'a.md',
          content: 'เนื้อหาเดิม',
        );
        final controller = AssistantChatController(
          fake,
          documentProvider: () => note,
        );

        note = const AiDocumentContext(title: 'a.md', content: 'เนื้อหาใหม่');
        await controller.send('สรุปให้หน่อย');

        expect(fake.lastDocument?.content, 'เนื้อหาใหม่');
      },
    );

    // 20. (Security) กด x แล้วส่ง setNoteAttached(false) แล้วส่ง lastDocument ต้องเป็น null
    test(
      '20. (Security) unchecking note persists across turns and sends null document',
      () async {
        final fake = FakeAiAssistant();
        const note = AiDocumentContext(title: 'a.md', content: 'เนื้อหา');
        final controller = AssistantChatController(
          fake,
          documentProvider: () => note,
        );

        controller.setNoteAttached(false);
        expect(controller.isNoteAttached, isFalse);
        expect(controller.attachedNoteTitle, isNull);

        await controller.send('ส่งครั้งที่ 1');
        expect(fake.callCount, 1);
        expect(fake.lastDocument, isNull);

        await controller.send('ส่งครั้งที่ 2');
        expect(fake.callCount, 2);
        expect(fake.lastDocument, isNull);
      },
    );

    // 21. แนบกลับส่ง setNoteAttached(true) แล้วส่ง ต้องได้โน้ต
    test(
      '21. re-enabling note attachment sends document to assistant again',
      () async {
        final fake = FakeAiAssistant();
        const note = AiDocumentContext(title: 'a.md', content: 'เนื้อหา');
        final controller = AssistantChatController(
          fake,
          documentProvider: () => note,
        );

        controller.setNoteAttached(false);
        await controller.send('ไม่แนบ');
        expect(fake.lastDocument, isNull);

        controller.setNoteAttached(true);
        expect(controller.isNoteAttached, isTrue);
        await controller.send('แนบใหม่');
        expect(fake.lastDocument?.content, 'เนื้อหา');
      },
    );

    // 22. แบบ ก. ยังแนบอยู่หลังส่ง ส่ง 2 ครั้งติดกัน ต้องได้โน้ตทั้ง 2 ครั้ง
    test(
      '22. note attachment state persists as attached across consecutive turns',
      () async {
        final fake = FakeAiAssistant();
        const note = AiDocumentContext(title: 'a.md', content: 'เนื้อหา');
        final controller = AssistantChatController(
          fake,
          documentProvider: () => note,
        );

        await controller.send('ถามครั้งที่ 1');
        expect(fake.lastDocument?.content, 'เนื้อหา');

        await controller.send('ถามครั้งที่ 2');
        expect(fake.lastDocument?.content, 'เนื้อหา');
      },
    );

    // 23. (Security) โน้ตว่างหรือมีแต่ช่องว่าง canAttachNote เป็น false และ lastDocument ต้องเป็น null
    test(
      '23. (Security) empty or whitespace-only content cannot be attached and sends null document',
      () async {
        final fake = FakeAiAssistant();
        const note = AiDocumentContext(title: 'empty.md', content: '   \n  ');
        final controller = AssistantChatController(
          fake,
          documentProvider: () => note,
        );

        expect(controller.canAttachNote, isFalse);
        expect(controller.isNoteAttached, isFalse);
        expect(controller.attachedNoteTitle, isNull);

        await controller.send('ส่งข้อความ');
        expect(fake.callCount, 1);
        expect(fake.lastDocument, isNull);
      },
    );

    // 24. โน้ตยาวเกิน send คืน false, callCount == 0, error มีคำว่า "ยาวเกินไป" และ messages ว่าง
    test(
      '24. rejecting overly long document aborts send, sets friendly error, and keeps messages empty',
      () async {
        final fake = FakeAiAssistant();
        final note = AiDocumentContext(
          title: 'huge.md',
          content: 'a' * (AiDocumentContext.maxContentLength + 1),
        );
        final controller = AssistantChatController(
          fake,
          documentProvider: () => note,
        );

        final result = await controller.send('ช่วยอ่านหน่อย');

        expect(result, isFalse);
        expect(fake.callCount, 0);
        expect(controller.errorMessage, contains('ยาวเกินไป'));
        expect(controller.errorMessage, contains('กด x'));
        expect(controller.messages, isEmpty);
      },
    );

    // 25. (Security) ประวัติแชทไม่มีเนื้อหาโน้ต ส่ง 2 ครั้ง แล้ว lastHistory ทุกข้อความต้องไม่มีคำว่า 'เนื้อหา' และข้อความแรกต้องมี attachedNoteTitle == 'a.md'
    test(
      '25. (Security) chat history never stores note content and preserves attachedNoteTitle',
      () async {
        final fake = FakeAiAssistant();
        const note = AiDocumentContext(
          title: 'a.md',
          content: 'ความลับสุดยอดเนื้อหาโน้ต',
        );
        final controller = AssistantChatController(
          fake,
          documentProvider: () => note,
        );

        await controller.send('ถามรอบ 1');
        await controller.send('ถามรอบ 2');

        expect(controller.messages.first.attachedNoteTitle, 'a.md');
        expect(fake.lastHistory, isNotNull);
        for (final msg in fake.lastHistory!) {
          expect(msg.text, isNot(contains('เนื้อหา')));
          expect(msg.text, isNot(contains('ความลับสุดยอด')));
        }
      },
    );

    // 26. ส่งไม่สำเร็จ ใช้ FakeAiAssistant(error: ...) ข้อความต้องถูกถอยกลับเหมือนเดิม และ isNoteAttached ยังเป็น true
    test(
      '26. failed turn rolls back messages but preserves note attachment state',
      () async {
        final fake = FakeAiAssistant(
          error: const AiAssistantException('ล้มเหลว'),
        );
        const note = AiDocumentContext(title: 'a.md', content: 'เนื้อหา');
        final controller = AssistantChatController(
          fake,
          documentProvider: () => note,
        );

        final result = await controller.send('ข้อความที่ส่งไม่ผ่าน');

        expect(result, isFalse);
        expect(controller.messages, isEmpty);
        expect(controller.isNoteAttached, isTrue);
      },
    );

    // 27. (Security) ที่เห็นตรงกับที่ส่ง วนทดสอบ 3 สถานะ จำค่าก่อนส่ง และเช็ก callCount
    test(
      '27. (Security) visual note attachment state strictly matches the sent document state',
      () async {
        final fake = FakeAiAssistant();
        var currentNote = const AiDocumentContext(
          title: 'test.md',
          content: 'เนื้อหาจริง',
        );
        final controller = AssistantChatController(
          fake,
          documentProvider: () => currentNote,
        );

        // กรณี 1: แนบปกติ
        final shown1 = controller.isNoteAttached;
        await controller.send('ข้อความ 1');
        expect(shown1, isTrue);
        expect(fake.callCount, 1);
        expect(fake.lastDocument != null, shown1);

        // กรณี 2: ผู้ใช้กด x (ปิดแนบ)
        controller.setNoteAttached(false);
        final shown2 = controller.isNoteAttached;
        await controller.send('ข้อความ 2');
        expect(shown2, isFalse);
        expect(fake.callCount, 2);
        expect(fake.lastDocument != null, shown2);

        // กรณี 3: ผู้ใช้เปิดแนบ แต่เนื้อหาโน้ตว่างเปล่า
        controller.setNoteAttached(true);
        currentNote = const AiDocumentContext(title: 'test.md', content: '   ');
        final shown3 = controller.isNoteAttached;
        await controller.send('ข้อความ 3');
        expect(shown3, isFalse);
        expect(fake.callCount, 3);
        expect(fake.lastDocument != null, shown3);
      },
    );

    // 28. copyWith keeps attachedNoteTitle and equality includes it
    test('28. copyWith keeps attachedNoteTitle and equality includes it', () {
      const original = ChatMessage(
        role: ChatRole.user,
        text: 'ก',
        attachedNoteTitle: 'a.md',
      );
      expect(original.copyWith(text: 'ข').attachedNoteTitle, 'a.md');
      expect(
        original,
        isNot(const ChatMessage(role: ChatRole.user, text: 'ก')),
      );
    });
  });
}
