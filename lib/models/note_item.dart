class LibraryMetadata {
  final List<FolderItem> folders;
  final List<DocumentItem> documents;

  const LibraryMetadata({
    this.folders = const [],
    this.documents = const [],
  });

  LibraryMetadata copyWith({
    List<FolderItem>? folders,
    List<DocumentItem>? documents,
  }) {
    return LibraryMetadata(
      folders: folders ?? this.folders,
      documents: documents ?? this.documents,
    );
  }

  Map<String, dynamic> toJson() => {
    'folders': folders.map((f) => {
      'id': f.id,
      'name': f.name,
      'updatedAt': f.updatedAt.toIso8601String(),
      'isStarred': f.isStarred,
      'isTrash': f.isTrash,
    }).toList(),
    'documents': documents.map((d) => {
      'id': d.id,
      'name': d.name,
      'content': d.content,
      'updatedAt': d.updatedAt.toIso8601String(),
      'folderId': d.folderId,
      'isStarred': d.isStarred,
      'uri': d.uri?.toString(),
      'isTrash': d.isTrash,
    }).toList(),
  };

  factory LibraryMetadata.fromJson(Map<String, dynamic> json) {
    final foldersList = (json['folders'] as List<dynamic>?) ?? [];
    final docsList = (json['documents'] as List<dynamic>?) ?? [];
    return LibraryMetadata(
      folders: foldersList.map((f) {
        final map = f as Map<String, dynamic>;
        return FolderItem(
          id: map['id'] as String,
          name: map['name'] as String,
          updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
          isStarred: map['isStarred'] as bool? ?? false,
          isTrash: map['isTrash'] as bool? ?? false,
        );
      }).toList(),
      documents: docsList.map((d) {
        final map = d as Map<String, dynamic>;
        return DocumentItem(
          id: map['id'] as String,
          name: map['name'] as String,
          content: map['content'] as String? ?? '',
          updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
          folderId: map['folderId'] as String?,
          isStarred: map['isStarred'] as bool? ?? false,
          uri: map['uri'] != null ? Uri.tryParse(map['uri'] as String) : null,
          isTrash: map['isTrash'] as bool? ?? false,
        );
      }).toList(),
    );
  }
}

class FolderItem {
  final String id;
  final String name;
  final DateTime updatedAt;
  final bool isStarred;
  final bool isTrash;

  FolderItem({
    required this.id,
    required this.name,
    required this.updatedAt,
    this.isStarred = false,
    this.isTrash = false,
  });

  FolderItem copyWith({
    String? id,
    String? name,
    DateTime? updatedAt,
    bool? isStarred,
    bool? isTrash,
  }) {
    return FolderItem(
      id: id ?? this.id,
      name: name ?? this.name,
      updatedAt: updatedAt ?? this.updatedAt,
      isStarred: isStarred ?? this.isStarred,
      isTrash: isTrash ?? this.isTrash,
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
  final bool isTrash;

  DocumentItem({
    required this.id,
    required this.name,
    required this.content,
    required this.updatedAt,
    this.folderId,
    this.isStarred = false,
    this.uri,
    this.isTrash = false,
  });

  String get extension {
    final parts = name.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : 'md';
  }

  bool get isTxt => extension == 'txt';
  bool get isMarkdown => extension == 'md' || extension == 'markdown';

  String get displayName {
    final lastDot = name.lastIndexOf('.');
    if (lastDot > 0) {
      return name.substring(0, lastDot);
    }
    return name;
  }

  DocumentItem copyWith({
    String? id,
    String? name,
    String? content,
    DateTime? updatedAt,
    String? folderId,
    bool? isStarred,
    Uri? uri,
    bool? isTrash,
  }) {
    return DocumentItem(
      id: id ?? this.id,
      name: name ?? this.name,
      content: content ?? this.content,
      updatedAt: updatedAt ?? this.updatedAt,
      folderId: folderId ?? this.folderId,
      isStarred: isStarred ?? this.isStarred,
      uri: uri ?? this.uri,
      isTrash: isTrash ?? this.isTrash,
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