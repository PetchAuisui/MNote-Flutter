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
      '1. should show empty state, privacy note, and 3 suggestion chips',
      (tester) async {
        final fakeAssistant = FakeAiAssistant();
        final controller = AssistantChatController(fakeAssistant);

        await tester.pumpWidget(buildTestWidget(controller: controller));

        expect(find.byKey(const Key('assistant-empty')), findsOneWidget);
        expect(find.byKey(const Key('assistant-privacy-note')), findsOneWidget);
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
  });
}
