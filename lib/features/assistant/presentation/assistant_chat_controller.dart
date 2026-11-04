import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:mnote/l10n/language_preferences.dart';
import '../domain/ai_assistant.dart';
import '../domain/chat_message.dart';

class AssistantChatController extends ChangeNotifier {
  final AiAssistant _assistant;
  final AiDocumentContext Function()? _documentProvider;

  /// วาดรูปหน้าโน้ตรวมลายมือ เรียกตอนกดส่งเฉพาะเมื่อแนบโน้ตที่มีลายมือ
  final Future<Uint8List?> Function()? _pageImageProvider;

  AssistantChatController(
    this._assistant, {
    this._documentProvider,
    this._pageImageProvider,
  });

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

  /// มีตัวอักษรที่ไม่ใช่ช่องว่างอย่างน้อย 1 ตัว
  static final _nonWhitespace = RegExp(r'\S');

  /// โน้ตที่แนบได้ตอนนี้ โน้ตว่างถือว่าไม่มี
  ///
  /// หน้าจอเรียกหลายครั้งทุกครั้งที่วาดใหม่ (รวมทุกชิ้นของคำตอบที่สตรีม)
  /// จึงเช็กด้วย hasMatch ซึ่งหยุดที่ตัวอักษรแรกที่ไม่ใช่ช่องว่าง
  /// ไม่ใช้ trim() ที่คัดลอกโน้ตทั้งก้อนทุกครั้ง
  AiDocumentContext? _currentNote() {
    final note = _documentProvider?.call();
    // โน้ตที่มีแต่ลายมือ ไม่มีข้อความ ก็แนบได้
    if (note == null ||
        (!note.hasInk && !_nonWhitespace.hasMatch(note.content))) {
      return null;
    }
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

  /// ใส่รูปหน้าโน้ตให้โน้ตที่แนบและมีลายมือ
  /// วาดไม่สำเร็จก็ส่งแค่ข้อความ ไม่ให้แชตพังเพราะรูป
  Future<AiDocumentContext?> _withPageImage(AiDocumentContext? document) async {
    final render = _pageImageProvider;
    if (document == null || !document.hasInk || render == null) {
      return document;
    }
    try {
      final image = await render();
      if (image == null) return document;
      return AiDocumentContext(
        title: document.title,
        content: document.content,
        hasInk: true,
        pageImage: image,
      );
    } catch (e) {
      debugPrint('AI page image failed: ${e.runtimeType}');
      return document;
    }
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
      _errorMessage = LanguagePreferences.current().aiTooLong(maxInputLength);
      _notifySafely();
      return false;
    }

    // อ่านโน้ตตอนกดส่ง จะได้เนื้อหาล่าสุด
    final document = _noteAttached ? _currentNote() : null;
    if (document != null && document.isTooLong) {
      _errorMessage = LanguagePreferences.current().aiNoteTooLong;
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
      // รอวาดรูปเฉพาะโน้ตที่แนบและมีลายมือ โน้ตอื่นส่งทันทีเหมือนเดิม
      // วาดหลังขึ้นสถานะกำลังตอบแล้ว กันกดส่งซ้ำระหว่างรอ
      final note =
          document != null && document.hasInk && _pageImageProvider != null
          ? await _withPageImage(document)
          : document;
      if (_isDisposed) return false;
      final stream = _assistant.sendMessage(
        trimmedText,
        history: history,
        document: note,
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
            _errorMessage = LanguagePreferences.current().aiNoAnswer;
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
        : LanguagePreferences.current().aiFailed;
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
