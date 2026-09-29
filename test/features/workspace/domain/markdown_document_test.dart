import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/workspace/domain/markdown_document.dart';

void main() {
  test('tracks edits until the document is marked as saved', () {
    final opened = MarkdownDocument.opened(
      name: 'notes.md',
      content: '# Notes',
      uri: Uri.file('/tmp/notes.md'),
    );

    final edited = opened.edit('# Updated notes');
    final saved = edited.markSaved(name: edited.name, uri: opened.uri!);

    expect(opened.isDirty, isFalse);
    expect(edited.isDirty, isTrue);
    expect(saved.isDirty, isFalse);
    expect(saved.content, '# Updated notes');
  });

  test('an untitled document becomes dirty after typing', () {
    final document = MarkdownDocument.untitled().edit('Hello');

    expect(document.name, 'Untitled.md');
    expect(document.uri, isNull);
    expect(document.isDirty, isTrue);
  });
}
