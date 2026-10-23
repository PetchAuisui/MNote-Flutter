import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/assistant/domain/ai_assistant.dart';
import 'package:mnote/features/assistant/domain/chat_message.dart';
import 'package:mnote/features/assistant/presentation/assistant_chat_controller.dart';
import 'package:mnote/features/assistant/presentation/assistant_chat_panel.dart';
import 'package:mnote/features/workspace/presentation/mermaid/mermaid.dart';
import '../../helpers/fake_ai_assistant.dart';

class _ManualStreamAssistant implements AiAssistant {
  final StreamController<String> streamController;
  int callCount = 0;

  _ManualStreamAssistant(this.streamController);

  @override
  Stream<String> sendMessage(
    String text, {
    List<ChatMessage> history = const [],
    AiDocumentContext? document,
  }) {
    callCount++;
    return streamController.stream;
  }
}

void main() {
  Widget buildTestWidget({
    required AssistantChatController controller,
    VoidCallback? onClose,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: AssistantChatPanel(controller: controller, onClose: onClose),
      ),
    );
  }

  Future<void> sendText(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('assistant-input')), text);
    await tester.pump();
    await tester.tap(find.byKey(const Key('assistant-send')));
  }

  group('AssistantChatPanel Widget Tests', () {
    testWidgets(
      '1. should show empty state, privacy note without note, and 3 suggestion chips',
      (tester) async {
        final fakeAssistant = FakeAiAssistant();
        final controller = AssistantChatController(fakeAssistant);

        await tester.pumpWidget(buildTestWidget(controller: controller));

        expect(find.byKey(const Key('assistant-empty')), findsOneWidget);
        expect(find.byKey(const Key('assistant-privacy-note')), findsOneWidget);
        expect(find.textContaining('ไม่ได้อ่านโน้ต'), findsOneWidget);
        expect(find.byKey(const Key('assistant-note-chip')), findsNothing);
        expect(find.byKey(const Key('assistant-note-attach')), findsNothing);
        expect(find.byKey(const Key('assistant-suggestion-0')), findsOneWidget);
        expect(find.byKey(const Key('assistant-suggestion-1')), findsOneWidget);
        expect(find.byKey(const Key('assistant-suggestion-2')), findsOneWidget);
      },
    );

    testWidgets('2. send button is disabled when input is empty', (
      tester,
    ) async {
      final fakeAssistant = FakeAiAssistant();
      final controller = AssistantChatController(fakeAssistant);

      await tester.pumpWidget(buildTestWidget(controller: controller));

      final sendButton = tester.widget<IconButton>(
        find.byKey(const Key('assistant-send')),
      );
      expect(sendButton.onPressed, isNull);
    });

    testWidgets(
      '3. entering text and tapping send renders user and AI bubbles and clears input',
      (tester) async {
        final fakeAssistant = FakeAiAssistant(chunks: ['สวัสดี', 'ครับ']);
        final controller = AssistantChatController(fakeAssistant);

        await tester.pumpWidget(buildTestWidget(controller: controller));

        await tester.enterText(
          find.byKey(const Key('assistant-input')),
          'คำทักทาย',
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('assistant-send')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('assistant-message-user')), findsOneWidget);
        expect(find.byKey(const Key('assistant-message-ai')), findsOneWidget);
        expect(find.text('สวัสดีครับ'), findsOneWidget);

        final textField = tester.widget<TextField>(
          find.byKey(const Key('assistant-input')),
        );
        expect(textField.controller?.text, isEmpty);
      },
    );

    testWidgets('4. tapping suggestion chip sends its text to assistant', (
      tester,
    ) async {
      final fakeAssistant = FakeAiAssistant();
      final controller = AssistantChatController(fakeAssistant);

      await tester.pumpWidget(buildTestWidget(controller: controller));

      await tester.tap(find.byKey(const Key('assistant-suggestion-0')));
      await tester.pumpAndSettle();

      expect(fakeAssistant.lastText, 'อธิบาย Markdown แบบเข้าใจง่าย');
    });

    testWidgets('5. shows assistant-error container when exception occurs', (
      tester,
    ) async {
      final fakeAssistant = FakeAiAssistant(
        chunks: [],
        error: const AiAssistantException('ระบบไม่ว่าง'),
      );
      final controller = AssistantChatController(fakeAssistant);

      await tester.pumpWidget(buildTestWidget(controller: controller));

      await sendText(tester, 'สวัสดี');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('assistant-error')), findsOneWidget);
      expect(find.text('ระบบไม่ว่าง'), findsOneWidget);
    });

    testWidgets('6. parses and renders markdown bold text without asterisks', (
      tester,
    ) async {
      final fakeAssistant = FakeAiAssistant(chunks: ['**ตัวหนา**']);
      final controller = AssistantChatController(fakeAssistant);

      await tester.pumpWidget(buildTestWidget(controller: controller));

      await sendText(tester, 'ทดสอบ');
      await tester.pumpAndSettle();

      expect(find.text('ตัวหนา'), findsOneWidget);
      expect(find.text('**ตัวหนา**'), findsNothing);
    });

    testWidgets('7. renders mermaid code block using MermaidElementBuilder', (
      tester,
    ) async {
      final mermaidBlock = buildMermaidFencedBlock('flowchart TD\nA-->B');
      final fakeAssistant = FakeAiAssistant(chunks: [mermaidBlock]);
      final controller = AssistantChatController(fakeAssistant);

      await tester.pumpWidget(buildTestWidget(controller: controller));

      await sendText(tester, 'วาดผัง');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mermaid-diagram-fallback')), findsOneWidget);
    });

    testWidgets(
      '8. shows typing indicator and disables clear button while responding',
      (tester) async {
        final streamController = StreamController<String>();
        final manualAssistant = _ManualStreamAssistant(streamController);
        final controller = AssistantChatController(manualAssistant);

        await tester.pumpWidget(buildTestWidget(controller: controller));

        await sendText(tester, 'คำถาม');
        await tester.pump();

        expect(find.byKey(const Key('assistant-typing')), findsOneWidget);

        final clearButton = tester.widget<IconButton>(
          find.byKey(const Key('assistant-clear')),
        );
        expect(clearButton.onPressed, isNull);

        streamController.add('คำตอบที่สมบูรณ์');
        await streamController.close();
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('assistant-typing')), findsNothing);
      },
    );

    testWidgets('9. tapping clear button resets view to empty state', (
      tester,
    ) async {
      final fakeAssistant = FakeAiAssistant();
      final controller = AssistantChatController(fakeAssistant);

      await tester.pumpWidget(buildTestWidget(controller: controller));

      await sendText(tester, 'ข้อความ');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('assistant-empty')), findsNothing);

      await tester.tap(find.byKey(const Key('assistant-clear')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('assistant-empty')), findsOneWidget);
      expect(find.byKey(const Key('assistant-message-user')), findsNothing);
    });

    testWidgets(
      '10. (Security) markdown image does not load network image and renders alt text',
      (tester) async {
        final fakeAssistant = FakeAiAssistant(
          chunks: ['![รูป](https://example.com/track.png)'],
        );
        final controller = AssistantChatController(fakeAssistant);

        await tester.pumpWidget(buildTestWidget(controller: controller));

        await sendText(tester, 'ขอรูป');
        await tester.pumpAndSettle();

        expect(find.byType(Image), findsNothing);
        expect(find.text('รูป'), findsOneWidget);
      },
    );

    testWidgets(
      '11. (Security) text field limits input length to 2000 characters',
      (tester) async {
        final fakeAssistant = FakeAiAssistant();
        final controller = AssistantChatController(fakeAssistant);

        await tester.pumpWidget(buildTestWidget(controller: controller));

        final textField = tester.widget<TextField>(
          find.byKey(const Key('assistant-input')),
        );
        expect(textField.maxLength, AssistantChatController.maxInputLength);
        expect(textField.maxLength, 2000);
      },
    );

    testWidgets(
      '12. showAssistantChat opens fullscreen dialog on compact screens (< 600)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeAssistant = FakeAiAssistant();
        final controller = AssistantChatController(fakeAssistant);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () =>
                      showAssistantChat(context, controller: controller),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('assistant-chat-dialog')), findsOneWidget);

        await tester.tap(find.byKey(const Key('assistant-close')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('assistant-chat-dialog')), findsNothing);
      },
    );

    testWidgets(
      '13. showAssistantChat opens 400px side-sheet on tablet/desktop (>= 600) and dismisses on barrier tap',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeAssistant = FakeAiAssistant();
        final controller = AssistantChatController(fakeAssistant);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () =>
                      showAssistantChat(context, controller: controller),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        final sideSheetFinder = find.byKey(const Key('assistant-side-sheet'));
        expect(sideSheetFinder, findsOneWidget);

        final size = tester.getSize(sideSheetFinder);
        expect(size.width, 400.0);

        await tester.tapAt(const Offset(100, 300));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('assistant-side-sheet')), findsNothing);
      },
    );

    testWidgets('14. side sheet keeps the input above the keyboard', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);

      final controller = AssistantChatController(FakeAiAssistant());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () =>
                    showAssistantChat(context, controller: controller),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final inputBottom = tester
          .getBottomLeft(find.byKey(const Key('assistant-input')))
          .dy;
      expect(inputBottom, lessThanOrEqualTo(768 - 300));
    });

    testWidgets('15. reopening the panel starts at the latest message', (
      tester,
    ) async {
      final controller = AssistantChatController(FakeAiAssistant());
      for (var i = 0; i < 15; i++) {
        await controller.send('ข้อความ $i');
      }

      await tester.pumpWidget(buildTestWidget(controller: controller));
      await tester.pumpAndSettle();

      final position = tester
          .widget<ListView>(find.byType(ListView))
          .controller!
          .position;
      expect(position.pixels, position.maxScrollExtent);
    });

    testWidgets('16. failed send puts the text back into the input', (
      tester,
    ) async {
      final controller = AssistantChatController(
        FakeAiAssistant(chunks: [], error: const AiAssistantException('ล้ม')),
      );
      await tester.pumpWidget(buildTestWidget(controller: controller));

      await sendText(tester, 'สวัสดี');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('assistant-error')), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('assistant-input')))
            .controller!
            .text,
        'สวัสดี',
      );
    });

    // 17. มีโน้ต: เห็นชิป, find.text('AI จะอ่าน: a.md'), find.byIcon(Icons.description_outlined) และแถบความเป็นส่วนตัวมีคำว่า "โน้ตที่แนบ"
    testWidgets(
      '17. displays note chip with title, description icon, and privacy note indicates attached note',
      (tester) async {
        final fake = FakeAiAssistant();
        const note = AiDocumentContext(title: 'a.md', content: 'เนื้อหา');
        final controller = AssistantChatController(
          fake,
          documentProvider: () => note,
        );

        await tester.pumpWidget(buildTestWidget(controller: controller));

        expect(find.byKey(const Key('assistant-note-chip')), findsOneWidget);
        expect(find.text('AI จะอ่าน: a.md'), findsOneWidget);
        expect(find.byIcon(Icons.description_outlined), findsOneWidget);
        expect(find.textContaining('โน้ตที่แนบ'), findsOneWidget);
      },
    );

    // 18. กด x: tap(find.byTooltip('ไม่แนบโน้ต')) แล้วชิปต้องหาย ปุ่มแนบต้องขึ้น และแถบเปลี่ยนเป็น "ไม่ได้อ่านโน้ต"
    testWidgets(
      '18. tapping chip delete button removes chip, reveals attach button, and updates privacy note',
      (tester) async {
        final fake = FakeAiAssistant();
        const note = AiDocumentContext(title: 'a.md', content: 'เนื้อหา');
        final controller = AssistantChatController(
          fake,
          documentProvider: () => note,
        );

        await tester.pumpWidget(buildTestWidget(controller: controller));

        await tester.tap(find.byTooltip('ไม่แนบโน้ต'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('assistant-note-chip')), findsNothing);
        expect(find.byKey(const Key('assistant-note-attach')), findsOneWidget);
        expect(find.textContaining('ไม่ได้อ่านโน้ต'), findsOneWidget);
      },
    );

    // 19. กดแนบกลับ: ชิปกลับมา
    testWidgets(
      '19. tapping attach button restores note chip and attached state',
      (tester) async {
        final fake = FakeAiAssistant();
        const note = AiDocumentContext(title: 'a.md', content: 'เนื้อหา');
        final controller = AssistantChatController(
          fake,
          documentProvider: () => note,
        );

        await tester.pumpWidget(buildTestWidget(controller: controller));

        await tester.tap(find.byTooltip('ไม่แนบโน้ต'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('assistant-note-chip')), findsNothing);

        await tester.tap(find.byKey(const Key('assistant-note-attach')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('assistant-note-chip')), findsOneWidget);
        expect(find.text('AI จะอ่าน: a.md'), findsOneWidget);
      },
    );

    // 20. (Security) ที่เห็นตรงกับที่ส่ง (ระดับหน้าจอ): มีชิปแล้วส่ง fake.lastDocument != null / กด x แล้วส่ง == null
    testWidgets(
      '20. (Security) UI attachment chip presence strictly reflects in sent document and verifies callCount',
      (tester) async {
        final fake = FakeAiAssistant();
        const note = AiDocumentContext(title: 'a.md', content: 'เนื้อหา');
        final controller = AssistantChatController(
          fake,
          documentProvider: () => note,
        );

        await tester.pumpWidget(buildTestWidget(controller: controller));

        // ส่งเมื่อมีชิป
        expect(find.byKey(const Key('assistant-note-chip')), findsOneWidget);
        await sendText(tester, 'ถามตอนแนบ');
        await tester.pumpAndSettle();

        expect(fake.callCount, 1);
        expect(fake.lastDocument?.title, 'a.md');

        // กด x เอาโน้ตออก แล้วส่ง
        await tester.tap(find.byTooltip('ไม่แนบโน้ต'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('assistant-note-chip')), findsNothing);

        await sendText(tester, 'ถามตอนไม่แนบ');
        await tester.pumpAndSettle();

        expect(fake.callCount, 2);
        expect(fake.lastDocument, isNull);
      },
    );

    // 21. ป้ายบนข้อความ: ส่งตอนมีชิป ข้อความต้องมี assistant-message-note-label / ส่งตอนไม่มีชิป ต้องไม่มี
    testWidgets(
      '21. renders attached note label on user message bubble only when sent with attachment',
      (tester) async {
        final fake = FakeAiAssistant();
        const note = AiDocumentContext(title: 'a.md', content: 'เนื้อหา');
        final controller = AssistantChatController(
          fake,
          documentProvider: () => note,
        );

        await tester.pumpWidget(buildTestWidget(controller: controller));

        // ส่งรอบที่ 1: มีโน้ต
        await sendText(tester, 'ข้อความแรก');
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('assistant-message-note-label')),
          findsOneWidget,
        );
        expect(find.text('แนบ: a.md'), findsOneWidget);

        // เอาโน้ตออกแล้วส่งรอบที่ 2
        await tester.tap(find.byTooltip('ไม่แนบโน้ต'));
        await tester.pumpAndSettle();

        await sendText(tester, 'ข้อความที่สอง');
        await tester.pumpAndSettle();

        // ป้ายต้องยังคงมีแค่ 1 ตัว (มาจากข้อความแรกเท่านั้น)
        expect(
          find.byKey(const Key('assistant-message-note-label')),
          findsOneWidget,
        );
      },
    );

    // 22. (Security) โน้ตว่าง: ไม่มีทั้งชิปและปุ่มแนบ
    testWidgets(
      '22. (Security) empty or whitespace note content renders neither chip nor attach button',
      (tester) async {
        final fake = FakeAiAssistant();
        const note = AiDocumentContext(title: 'empty.md', content: '   \n  ');
        final controller = AssistantChatController(
          fake,
          documentProvider: () => note,
        );

        await tester.pumpWidget(buildTestWidget(controller: controller));

        expect(find.byKey(const Key('assistant-note-chip')), findsNothing);
        expect(find.byKey(const Key('assistant-note-attach')), findsNothing);
        expect(find.textContaining('ไม่ได้อ่านโน้ต'), findsOneWidget);
      },
    );

    // 23. เปิดแผงใหม่: กด x แล้ว pumpWidget ใหม่ด้วย controller ตัวเดิม ชิปต้องยังไม่กลับมา
    testWidgets(
      '23. unattached note state persists in controller across panel rebuilds/reopens',
      (tester) async {
        final fake = FakeAiAssistant();
        const note = AiDocumentContext(title: 'a.md', content: 'เนื้อหา');
        final controller = AssistantChatController(
          fake,
          documentProvider: () => note,
        );

        await tester.pumpWidget(buildTestWidget(controller: controller));

        // กด x เพื่อถอดโน้ตออก
        await tester.tap(find.byTooltip('ไม่แนบโน้ต'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('assistant-note-chip')), findsNothing);

        // ปิดแผง: เอา panel ออกจากหน้าจอ State จะถูก dispose จริง
        await tester.pumpWidget(const SizedBox());

        // เปิดใหม่: ได้ State ตัวใหม่ แต่ใช้ controller ตัวเดิม
        await tester.pumpWidget(buildTestWidget(controller: controller));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('assistant-note-chip')), findsNothing);
        expect(find.byKey(const Key('assistant-note-attach')), findsOneWidget);
      },
    );

    // 24. ชื่อยาว 200 ตัว: ต้องไม่มี overflow error
    testWidgets(
      '24. handles very long note title without throwing RenderFlex overflow exception',
      (tester) async {
        final fake = FakeAiAssistant();
        final longTitle = 'a' * 200;
        final note = AiDocumentContext(title: longTitle, content: 'เนื้อหา');
        final controller = AssistantChatController(
          fake,
          documentProvider: () => note,
        );

        await tester.pumpWidget(buildTestWidget(controller: controller));

        // ส่งข้อความเพื่อให้เกิดบับเบิลที่มีป้ายกำกับชื่อยาว
        await sendText(tester, 'ทดสอบชื่อยาว');
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const Key('assistant-message-note-label')),
          findsOneWidget,
        );
      },
    );
  });
}
