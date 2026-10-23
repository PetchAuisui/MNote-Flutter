enum ChatRole { user, assistant }

final class ChatMessage {
  final ChatRole role;
  final String text;

  /// ชื่อโน้ตที่แนบไปกับข้อความนี้ ไว้แสดงบนข้อความ ไม่เก็บเนื้อหาโน้ต
  final String? attachedNoteTitle;

  const ChatMessage({
    required this.role,
    required this.text,
    this.attachedNoteTitle,
  });

  ChatMessage copyWith({String? text}) {
    return ChatMessage(
      role: role,
      text: text ?? this.text,
      attachedNoteTitle: attachedNoteTitle,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessage &&
          runtimeType == other.runtimeType &&
          role == other.role &&
          text == other.text &&
          attachedNoteTitle == other.attachedNoteTitle;

  @override
  int get hashCode => Object.hash(role, text, attachedNoteTitle);
}
