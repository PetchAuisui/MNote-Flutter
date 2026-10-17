enum ChatRole { user, assistant }

final class ChatMessage {
  final ChatRole role;
  final String text;

  const ChatMessage({required this.role, required this.text});

  ChatMessage copyWith({String? text}) {
    return ChatMessage(role: role, text: text ?? this.text);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessage &&
          runtimeType == other.runtimeType &&
          role == other.role &&
          text == other.text;

  @override
  int get hashCode => Object.hash(role, text);
}
