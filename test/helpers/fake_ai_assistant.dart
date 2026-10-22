import 'dart:async';
import 'package:mnote/features/assistant/domain/ai_assistant.dart';
import 'package:mnote/features/assistant/domain/chat_message.dart';

class FakeAiAssistant implements AiAssistant {
  final List<String> chunks;
  final Object? error;

  String? lastText;
  List<ChatMessage>? lastHistory;
  AiDocumentContext? lastDocument;
  int callCount = 0;

  FakeAiAssistant({this.chunks = const ['สวัสดี', 'ครับ'], this.error});

  @override
  Stream<String> sendMessage(
    String text, {
    List<ChatMessage> history = const [],
    AiDocumentContext? document,
  }) {
    callCount++;
    lastText = text;
    lastHistory = history;
    lastDocument = document;
    return _respond();
  }

  Stream<String> _respond() async* {
    for (final chunk in chunks) {
      yield chunk;
    }
    if (error != null) {
      throw error!;
    }
  }
}
