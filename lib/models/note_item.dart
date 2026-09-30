enum NoteType { markdown, drawing, mixed }

class NoteItem {
  final String id;
  final String title;
  final String previewText;
  final DateTime updatedAt;
  final NoteType type;

  NoteItem({
    required this.id,
    required this.title,
    required this.previewText,
    required this.updatedAt,
    required this.type,
  });
}