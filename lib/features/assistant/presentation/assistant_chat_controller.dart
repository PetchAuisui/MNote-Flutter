import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show StringCharacters;
import '../domain/ai_assistant.dart';
import '../domain/chat_message.dart';

class AssistantChatController extends ChangeNotifier {
  final AiAssistant _assistant;

  AssistantChatController(this._assistant);

  static const int maxInputLength = 2000;
  static const int maxHistoryMessages = 20;

  final List<ChatMessage> _messages = [];
  bool _isResponding = false;
  String? _errorMessage;
  bool _isDisposed = false;
  StreamSubscription<String>? _streamSubscription;
  Completer<void>? _responseDone;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isResponding => _isResponding;
  String? get errorMessage => _errorMessage;

  Future<void> send(String text) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty || _isResponding) {
      return;
    }

    // นับแบบเดียวกับ TextField (ตัวอักษรที่เห็น) สระไทยจะไม่ถูกนับซ้ำ
    if (trimmedText.characters.length > maxInputLength) {
      _errorMessage = 'ข้อความยาวเกินไป (สูงสุด 2000 ตัวอักษร)';
      _notifySafely();
      return;
    }

    final history = _messages.length > maxHistoryMessages
        ? _messages.sublist(_messages.length - maxHistoryMessages)
        : List<ChatMessage>.from(_messages);

    _errorMessage = null;
    _messages.add(ChatMessage(role: ChatRole.user, text: trimmedText));
    _messages.add(const ChatMessage(role: ChatRole.assistant, text: ''));
    _isResponding = true;
    _notifySafely();

    final completer = _responseDone = Completer<void>();

    try {
      final stream = _assistant.sendMessage(
        trimmedText,
        history: history,
        // ยังไม่ส่งโน้ตให้ AI (ความเป็นส่วนตัว)
        document: null,
      );

      _streamSubscription = stream.listen(
        (chunk) {
          if (_messages.isNotEmpty &&
              _messages.last.role == ChatRole.assistant) {
            final lastIndex = _messages.length - 1;
            final current = _messages[lastIndex];
            _messages[lastIndex] = current.copyWith(text: current.text + chunk);
            _notifySafely();
          }
        },
        onError: (Object error) {
          _handleError(error);
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        cancelOnError: true,
      );

      await completer.future;
    } catch (e) {
      _handleError(e);
    } finally {
      _streamSubscription?.cancel();
      _streamSubscription = null;
      _responseDone = null;
      _isResponding = false;
      _notifySafely();
    }
  }

  void _handleError(Object error) {
    _errorMessage = error is AiAssistantException
        ? error.message
        : 'AI ตอบไม่สำเร็จ กรุณาลองใหม่';
    if (_messages.isNotEmpty &&
        _messages.last.role == ChatRole.assistant &&
        _messages.last.text.isEmpty) {
      _messages.removeLast();
    }
  }

  void clear() {
    if (_isResponding) return;
    _messages.clear();
    _errorMessage = null;
    _notifySafely();
  }

  void _notifySafely() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _streamSubscription?.cancel();
    _streamSubscription = null;
    final pending = _responseDone;
    if (pending != null && !pending.isCompleted) {
      pending.complete();
    }
    super.dispose();
  }
}
