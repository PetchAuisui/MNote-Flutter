enum NoteType { markdown, drawing, mixed }

class NoteItem {
  final String id;
  final String title;
  final String previewText;
  final DateTime updatedAt;
  final NoteType type;
  final bool isPinned;

  NoteItem({
    required this.id,
    required this.title,
    required this.previewText,
    required this.updatedAt,
    required this.type,
    this.isPinned = false,
  });

  NoteItem copyWith({
    String? id,
    String? title,
    String? previewText,
    DateTime? updatedAt,
    NoteType? type,
    bool? isPinned,
  }) {
    return NoteItem(
      id: id ?? this.id,
      title: title ?? this.title,
      previewText: previewText ?? this.previewText,
      updatedAt: updatedAt ?? this.updatedAt,
      type: type ?? this.type,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}