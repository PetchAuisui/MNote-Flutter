class FolderItem {
  final String id;
  final String name;
  final DateTime updatedAt;
  final bool isStarred;

  FolderItem({
    required this.id,
    required this.name,
    required this.updatedAt,
    this.isStarred = false,
  });

  FolderItem copyWith({
    String? id,
    String? name,
    DateTime? updatedAt,
    bool? isStarred,
  }) {
    return FolderItem(
      id: id ?? this.id,
      name: name ?? this.name,
      updatedAt: updatedAt ?? this.updatedAt,
      isStarred: isStarred ?? this.isStarred,
    );
  }
}

class DocumentItem {
  final String id;
  final String name;
  final String content;
  final DateTime updatedAt;
  final String? folderId;
  final bool isStarred;
  final Uri? uri;

  DocumentItem({
    required this.id,
    required this.name,
    required this.content,
    required this.updatedAt,
    this.folderId,
    this.isStarred = false,
    this.uri,
  });

  String get extension {
    final parts = name.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : 'md';
  }

  bool get isTxt => extension == 'txt';
  bool get isMarkdown => extension == 'md' || extension == 'markdown';

  DocumentItem copyWith({
    String? id,
    String? name,
    String? content,
    DateTime? updatedAt,
    String? folderId,
    bool? isStarred,
    Uri? uri,
  }) {
    return DocumentItem(
      id: id ?? this.id,
      name: name ?? this.name,
      content: content ?? this.content,
      updatedAt: updatedAt ?? this.updatedAt,
      folderId: folderId ?? this.folderId,
      isStarred: isStarred ?? this.isStarred,
      uri: uri ?? this.uri,
    );
  }
}

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