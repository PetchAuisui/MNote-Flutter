class MarkdownDocument {
  const MarkdownDocument({
    required this.name,
    required this.content,
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
      savedContent: content,
      uri: uri,
    );
  }

  factory MarkdownDocument.untitled([String content = '']) {
    return MarkdownDocument(
      name: 'Untitled.md',
      content: content,
      savedContent: '',
    );
  }

  final String name;
  final String content;
  final String savedContent;
  final Uri? uri;

  bool get isDirty => content != savedContent;

  MarkdownDocument edit(String value) {
    return MarkdownDocument(
      name: name,
      content: value,
      savedContent: savedContent,
      uri: uri,
    );
  }

  MarkdownDocument markSaved({required String name, required Uri uri}) {
    return MarkdownDocument(
      name: name,
      content: content,
      savedContent: content,
      uri: uri,
    );
  }
}
