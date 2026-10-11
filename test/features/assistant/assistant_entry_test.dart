import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/app/mnote_app.dart';
import 'package:mnote/features/assistant/domain/ai_assistant.dart';
import 'package:mnote/features/workspace/domain/markdown_document.dart';
import 'package:mnote/features/workspace/presentation/markdown_workspace_page.dart';
import '../../helpers/fake_ai_assistant.dart';
import '../../helpers/fakes.dart';

void main() {
  Future<void> pumpWorkspace(
    WidgetTester tester, {
    required Size size,
    AiAssistant? assistant,
    String content = '',
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = FakeDocumentRepository();
    final document = MarkdownDocument.opened(
      name: 'Test.md',
      content: content,
      uri: Uri.file('/tmp/Test.md'),
    );

    await tester.pumpWidget(
      MnoteApp(
        documentRepository: repo,
        home: MarkdownWorkspacePage(
          initialDocument: document,
          repository: repo,
          assistant: assistant,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Workspace AI Assistant Entry Tests', () {
    // 1. ไม่ส่ง assistant: toolbar-assistant-button เจอ 0 ตัว
    testWidgets(
      '1. toolbar-assistant-button is not shown when assistant is null',
      (tester) async {
        await pumpWorkspace(
          tester,
          size: const Size(1024, 768),
          assistant: null,
        );

        expect(find.byKey(const Key('toolbar-assistant-button')), findsNothing);
      },
    );

    // 2. จอ 1024x768 ส่ง FakeAiAssistant: กดปุ่มแล้วเจอ assistant-side-sheet
    testWidgets(
      '2. tapping assistant button on tablet (1024x768) opens side sheet',
      (tester) async {
        final fakeAssistant = FakeAiAssistant();
        await pumpWorkspace(
          tester,
          size: const Size(1024, 768),
          assistant: fakeAssistant,
        );

        final buttonFinder = find.byKey(const Key('toolbar-assistant-button'));
        expect(buttonFinder, findsOneWidget);

        await tester.tap(buttonFinder);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('assistant-side-sheet')), findsOneWidget);
      },
    );

    // 3. จอ 390x844: กดปุ่มแล้วเจอ assistant-chat-dialog
    testWidgets(
      '3. tapping assistant button on phone (390x844) opens fullscreen dialog',
      (tester) async {
        final fakeAssistant = FakeAiAssistant();
        await pumpWorkspace(
          tester,
          size: const Size(390, 844),
          assistant: fakeAssistant,
        );

        final buttonFinder = find.byKey(const Key('toolbar-assistant-button'));
        expect(buttonFinder, findsOneWidget);

        await tester.tap(buttonFinder);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('assistant-chat-dialog')), findsOneWidget);
      },
    );

    // 4. บทสนทนายังอยู่: ปิดแผงแล้วเปิดใหม่ ต้องยังเจอข้อความเดิม
    testWidgets(
      '4. conversation history persists across closing and reopening chat panel',
      (tester) async {
        final fakeAssistant = FakeAiAssistant(chunks: ['สวัสดี', 'ครับ']);
        await pumpWorkspace(
          tester,
          size: const Size(1024, 768),
          assistant: fakeAssistant,
        );

        await tester.tap(find.byKey(const Key('toolbar-assistant-button')));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('assistant-input')),
          'ข้อความของฉัน',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('assistant-send')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('assistant-message-user')), findsOneWidget);

        await tester.tap(find.byKey(const Key('assistant-close')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('assistant-side-sheet')), findsNothing);

        await tester.tap(find.byKey(const Key('toolbar-assistant-button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('assistant-message-user')), findsOneWidget);
        expect(find.text('ข้อความของฉัน'), findsOneWidget);
      },
    );

    // 5. (Security) เนื้อหาโน้ตไม่ถูกส่งให้ AI
    testWidgets(
      '5. (Security) note content is not sent to AI or rendered in chat panel',
      (tester) async {
        final fakeAssistant = FakeAiAssistant();
        const secretNoteContent = 'ข้อมูลลับในโน้ตที่ห้ามส่งไป AI';

        await pumpWorkspace(
          tester,
          size: const Size(1024, 768),
          assistant: fakeAssistant,
          content: secretNoteContent,
        );

        await tester.tap(find.byKey(const Key('toolbar-assistant-button')));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('assistant-input')),
          'สวัสดี',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('assistant-send')));
        await tester.pumpAndSettle();

        expect(fakeAssistant.lastDocument, isNull);
        expect(fakeAssistant.lastText, 'สวัสดี');

        final chatPanelFinder = find.byKey(const Key('assistant-chat-panel'));
        final secretInChat = find.descendant(
          of: chatPanelFinder,
          matching: find.textContaining(secretNoteContent),
        );
        expect(secretInChat, findsNothing);
      },
    );

    // 6. ออกจากหน้าแล้วไม่ error (dispose ถูกต้อง ไม่ throw exception)
    testWidgets(
      '6. disposing workspace while controller exists does not throw',
      (tester) async {
        final fakeAssistant = FakeAiAssistant();
        await pumpWorkspace(
          tester,
          size: const Size(1024, 768),
          assistant: fakeAssistant,
        );

        await tester.tap(find.byKey(const Key('toolbar-assistant-button')));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('assistant-input')),
          'ทดสอบก่อนปิดหน้า',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('assistant-send')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('assistant-close')));
        await tester.pumpAndSettle();

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  });
}
