import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/app/mnote_app.dart';
import 'package:mnote/features/assistant/domain/ai_assistant.dart';
import 'package:mnote/features/assistant/domain/chat_message.dart';
import 'package:mnote/features/workspace/data/local_document_repository.dart';
import 'package:mnote/features/workspace/domain/markdown_document.dart';
import 'package:mnote/features/workspace/presentation/markdown_workspace_page.dart';

import '../helpers/harness.dart';

/// Stands in for Gemini: answers in pieces with a short delay between them,
/// the way the real stream arrives, and records what the app sent.
class ScriptedAssistant implements AiAssistant {
  ScriptedAssistant(this.reply, {this.fail = false});

  final List<String> reply;
  final bool fail;
  final sent = <({String text, AiDocumentContext? document, int history})>[];

  @override
  Stream<String> sendMessage(
    String text, {
    List<ChatMessage> history = const [],
    AiDocumentContext? document,
  }) async* {
    sent.add((text: text, document: document, history: history.length));
    for (final piece in reply) {
      await Future<void>.delayed(const Duration(milliseconds: 60));
      yield piece;
    }
    if (fail) throw const AiAssistantException('quota');
  }
}

/// End-to-end: a saved note is opened, the user asks the AI about it, the
/// answer streams into the chat, and the note itself is left untouched.
void main() {
  const noteText =
      '# Flutter Testing\nUnit, widget and integration tests cover different layers.';

  Future<MarkdownDocument> savedNote(TempDirStorage storage) async {
    final repo = LocalDocumentRepository(storage);
    final saved = await repo.save(
      MarkdownDocument(
        name: 'Testing.md',
        content: noteText,
        savedName: 'Testing.md',
        savedContent: '',
      ),
    );
    return MarkdownDocument.opened(
      name: saved!.name,
      content: noteText,
      uri: saved.uri!,
    );
  }

  Future<void> openWorkspace(
    WidgetTester tester,
    TempDirStorage storage,
    AiAssistant assistant,
  ) async {
    final repo = LocalDocumentRepository(storage);
    await tester.pumpWidget(
      MnoteApp(
        documentRepository: repo,
        home: MarkdownWorkspacePage(
          repository: repo,
          initialDocument: await savedNote(storage),
          assistant: assistant,
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> ask(WidgetTester tester, String question) async {
    await tester.enterText(find.byKey(const Key('assistant-input')), question);
    await tester.pump();
    await tester.tap(find.byKey(const Key('assistant-send')));
    // Let every streamed piece arrive.
    await settle(tester);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await settle(tester);
  }

  testWidgets('asks the AI about the open note and shows the streamed answer', (
    tester,
  ) async {
    prepareDevice(tester);
    final storage = await createStorage(tester);
    final assistant = ScriptedAssistant([
      'โน้ตนี้สรุปว่า ',
      'การทดสอบแต่ละแบบ',
      'ครอบคลุมคนละชั้นของแอป',
    ]);
    await openWorkspace(tester, storage, assistant);

    await tester.tap(find.byKey(const Key('toolbar-assistant-button')));
    await settle(tester);
    expect(find.byKey(const Key('assistant-side-sheet')), findsOneWidget);
    // The note is offered as context, by name only, before anything is sent.
    expect(find.byKey(const Key('assistant-note-chip')), findsOneWidget);
    expect(assistant.sent, isEmpty);

    await ask(tester, 'สรุปโน้ตนี้ให้หน่อย');

    // The app sent the question together with the real note.
    expect(assistant.sent.single.text, 'สรุปโน้ตนี้ให้หน่อย');
    expect(assistant.sent.single.document?.title, 'Testing.md');
    expect(assistant.sent.single.document?.content, noteText);

    // Both sides of the conversation are on screen, the answer in full.
    expect(find.byKey(const Key('assistant-message-user')), findsOneWidget);
    expect(
      find.textContaining('ครอบคลุมคนละชั้นของแอป', findRichText: true),
      findsOneWidget,
    );

    // A follow-up carries the earlier turns as history.
    await ask(tester, 'ขอเป็นข้อ ๆ');
    expect(assistant.sent, hasLength(2));
    expect(assistant.sent.last.history, greaterThanOrEqualTo(2));

    // Closing the chat leaves the note exactly as it was.
    await tester.tap(find.byKey(const Key('assistant-close')));
    await settle(tester);
    expect(find.byKey(const Key('assistant-side-sheet')), findsNothing);
    final onDisk = await LocalDocumentRepository(
      storage,
    ).readDocument(Uri.file('${storage.directory.path}/Testing.md'));
    expect(onDisk, noteText);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed AI answer shows an error and the chat keeps working', (
    tester,
  ) async {
    prepareDevice(tester);
    final storage = await createStorage(tester);
    final assistant = ScriptedAssistant(['ครึ่ง'], fail: true);
    await openWorkspace(tester, storage, assistant);

    await tester.tap(find.byKey(const Key('toolbar-assistant-button')));
    await settle(tester);
    await ask(tester, 'ช่วยอธิบาย');

    expect(find.byKey(const Key('assistant-error')), findsOneWidget);
    // The input is usable again, so the user can retry.
    await tester.enterText(find.byKey(const Key('assistant-input')), 'ลองใหม่');
    await tester.pump();
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('assistant-send')))
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });
}
