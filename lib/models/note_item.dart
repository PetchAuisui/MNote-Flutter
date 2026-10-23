import 'package:mnote/features/workspace/domain/markdown_document.dart';

/// Per-document cloud sync choice, kept on this device only.
enum SyncMode {
  /// Follow the global settings.
  auto,

  /// Never upload this document or apply cloud changes to it.
  never;

  static SyncMode fromName(String? name) => SyncMode.values.firstWhere(
    (m) => m.name == name,
    orElse: () => SyncMode.auto,
  );
}

class LibraryMetadata {
  final List<FolderItem> folders;
  final List<DocumentItem> documents;

  const LibraryMetadata({this.folders = const [], this.documents = const []});

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
    'folders': folders
        .map(
          (f) => {
            'id': f.id,
            'name': f.name,
            'updatedAt': f.updatedAt.toIso8601String(),
            'isStarred': f.isStarred,
            'isTrash': f.isTrash,
            'color': f.colorValue,
          },
        )
        .toList(),
    'documents': documents
        .map(
          (d) => {
            'id': d.id,
            'name': d.name,
            'content': d.content,
            'updatedAt': d.updatedAt.toIso8601String(),
            'folderId': d.folderId,
            'isStarred': d.isStarred,
            'uri': d.uri?.toString(),
            'isTrash': d.isTrash,
            'syncMode': d.syncMode.name,
          },
        )
        .toList(),
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
          updatedAt:
              DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
              DateTime.now(),
          isStarred: map['isStarred'] as bool? ?? false,
          isTrash: map['isTrash'] as bool? ?? false,
          colorValue: map['color'] as int?,
        );
      }).toList(),
      documents: docsList.map((d) {
        final map = d as Map<String, dynamic>;
        return DocumentItem(
          id: map['id'] as String,
          name: map['name'] as String,
          content: map['content'] as String? ?? '',
          updatedAt:
              DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
              DateTime.now(),
          folderId: map['folderId'] as String?,
          isStarred: map['isStarred'] as bool? ?? false,
          uri: map['uri'] != null ? Uri.tryParse(map['uri'] as String) : null,
          isTrash: map['isTrash'] as bool? ?? false,
          syncMode: SyncMode.fromName(map['syncMode'] as String?),
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

  /// ARGB value of the folder's chosen color, or null for the theme color.
  final int? colorValue;

  FolderItem({
    required this.id,
    required this.name,
    required this.updatedAt,
    this.isStarred = false,
    this.isTrash = false,
    this.colorValue,
  });

  /// Returns a copy with [colorValue] set to [color]; null clears it.
  FolderItem withColor(int? color) => FolderItem(
    id: id,
    name: name,
    updatedAt: DateTime.now(),
    isStarred: isStarred,
    isTrash: isTrash,
    colorValue: color,
  );

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
      colorValue: colorValue,
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
  final SyncMode syncMode;

  DocumentItem({
    required this.id,
    required this.name,
    required this.content,
    required this.updatedAt,
    this.folderId,
    this.isStarred = false,
    this.uri,
    this.isTrash = false,
    this.syncMode = SyncMode.auto,
  });

  String get extension {
    final parts = name.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : 'md';
  }

  bool get isTxt => extension == 'txt';
  bool get isMarkdown => extension == 'md' || extension == 'markdown';

  String get displayName => documentDisplayName(name);

  DocumentItem copyWith({
    String? id,
    String? name,
    String? content,
    DateTime? updatedAt,
    String? folderId,
    bool? isStarred,
    Uri? uri,
    bool? isTrash,
    SyncMode? syncMode,
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
      syncMode: syncMode ?? this.syncMode,
    );
  }

  DocumentItem moveToFolder(String? newFolderId) {
    return DocumentItem(
      id: id,
      name: name,
      content: content,
      updatedAt: DateTime.now(),
      folderId: newFolderId,
      isStarred: isStarred,
      uri: uri,
      isTrash: isTrash,
      syncMode: syncMode,
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
