class MarkdownDocument {
  const MarkdownDocument({
    required this.name,
    required this.content,
    required this.savedName,
    required this.savedContent,
    this.uri,
  });

  factory MarkdownDocument.opened({
    required String name,
    required String content,
    required Uri uri,
  }) {
    return MarkdownDocument(
      name: name,
      content: content,
      savedName: name,
      savedContent: content,
      uri: uri,
    );
  }

  factory MarkdownDocument.untitled([String content = '']) {
    return MarkdownDocument(
      name: 'Untitled.md',
      content: content,
      savedName: 'Untitled.md',
      savedContent: '',
    );
  }

  final String name;
  final String content;
  final String savedName;
  final String savedContent;
  final Uri? uri;

  bool get isDirty => name != savedName || content != savedContent;

  MarkdownDocument edit(String value) {
    return MarkdownDocument(
      name: name,
      content: value,
      savedName: savedName,
      savedContent: savedContent,
      uri: uri,
    );
  }

  MarkdownDocument rename(String value) {
    return MarkdownDocument(
      name: value,
      content: content,
      savedName: savedName,
      savedContent: savedContent,
      uri: uri,
    );
  }

  MarkdownDocument markSaved({required String name, required Uri uri}) {
    return MarkdownDocument(
      name: name,
      content: content,
      savedName: name,
      savedContent: content,
      uri: uri,
    );
  }
}
