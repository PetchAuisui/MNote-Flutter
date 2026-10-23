import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show StringCharacters;
import '../domain/ai_assistant.dart';
import '../domain/chat_message.dart';

class AssistantChatController extends ChangeNotifier {
  final AiAssistant _assistant;
  final AiDocumentContext Function()? _documentProvider;

  AssistantChatController(this._assistant, {this._documentProvider});

  static const int maxInputLength = 2000;
  static const int maxHistoryMessages = 20;

  final List<ChatMessage> _messages = [];
  bool _isResponding = false;
  String? _errorMessage;
  bool _isDisposed = false;
  StreamSubscription<String>? _streamSubscription;
  Completer<void>? _responseDone;

  /// ผู้ใช้ต้องการแนบโน้ตไหม เริ่มต้นแนบ กด x แล้วจำไว้จนกว่าจะกดแนบใหม่
  bool _noteAttached = true;

  List<ChatMessage> get messages => UnmodifiableListView(_messages);
  bool get isResponding => _isResponding;
  String? get errorMessage => _errorMessage;

  /// โน้ตที่แนบได้ตอนนี้ โน้ตว่างถือว่าไม่มี
  AiDocumentContext? _currentNote() {
    final note = _documentProvider?.call();
    if (note == null || note.content.trim().isEmpty) return null;
    return note;
  }

  bool get canAttachNote => _currentNote() != null;
  bool get isNoteAttached => _noteAttached && canAttachNote;
  String? get attachedNoteTitle => _noteAttached ? _currentNote()?.title : null;

  void setNoteAttached(bool value) {
    if (_noteAttached == value) return;
    _noteAttached = value;
    _notifySafely();
  }

  /// คืน true เมื่อ AI ตอบจบสำเร็จ
  /// ถ้าไม่สำเร็จ เอาคำถามและคำตอบที่ไม่จบออก ไม่ให้ถูกส่งเป็นประวัติรอบหน้า
  Future<bool> send(String text) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty || _isResponding) {
      return false;
    }

    // นับแบบเดียวกับ TextField (ตัวอักษรที่เห็น) สระไทยจะไม่ถูกนับซ้ำ
    if (trimmedText.characters.length > maxInputLength) {
      _errorMessage = 'ข้อความยาวเกินไป (สูงสุด 2000 ตัวอักษร)';
      _notifySafely();
      return false;
    }

    // อ่านโน้ตตอนกดส่ง จะได้เนื้อหาล่าสุด
    final document = _noteAttached ? _currentNote() : null;
    if (document != null && document.isTooLong) {
      _errorMessage =
          'โน้ตยาวเกินไปสำหรับผู้ช่วย AI '
          '(สูงสุด ${AiDocumentContext.maxContentLength} ตัวอักษร) '
          'กด x ที่ชื่อโน้ตเพื่อส่งโดยไม่แนบ';
      _notifySafely();
      return false;
    }

    final history = _messages.length > maxHistoryMessages
        ? _messages.sublist(_messages.length - maxHistoryMessages)
        : List<ChatMessage>.from(_messages);

    _errorMessage = null;
    final turnStart = _messages.length;
    _messages.add(
      ChatMessage(
        role: ChatRole.user,
        text: trimmedText,
        attachedNoteTitle: document?.title,
      ),
    );
    _messages.add(const ChatMessage(role: ChatRole.assistant, text: ''));
    _isResponding = true;
    _notifySafely();

    final completer = _responseDone = Completer<void>();
    var succeeded = false;

    try {
      final stream = _assistant.sendMessage(
        trimmedText,
        history: history,
        document: document,
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
          if (!completer.isCompleted) completer.complete();
        },
        onDone: () {
          // ตอบจบแต่ไม่มีข้อความ (เช่น โดน safety filter) ถือว่าไม่สำเร็จ
          // จะได้ถอยกลับ คืนข้อความเข้าช่องพิมพ์ และบอกผู้ใช้
          final answer = _messages.length > turnStart + 1
              ? _messages[turnStart + 1].text
              : '';
          if (answer.trim().isNotEmpty) {
            succeeded = true;
          } else {
            _errorMessage =
                'AI ไม่ได้ส่งคำตอบกลับมา ลองถามใหม่หรือเปลี่ยนคำถาม';
          }
          if (!completer.isCompleted) completer.complete();
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
      if (!succeeded && !_isDisposed && turnStart <= _messages.length) {
        _messages.removeRange(turnStart, _messages.length);
      }
      _isResponding = false;
      _notifySafely();
    }
    return succeeded;
  }

  void _handleError(Object error) {
    _errorMessage = error is AiAssistantException
        ? error.message
        : 'AI ตอบไม่สำเร็จ กรุณาลองใหม่';
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
