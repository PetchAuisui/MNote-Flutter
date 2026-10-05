import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'markdown_document_style.dart';

/// Source ranges used by both the preview and the editable document.
List<TextRange> markdownBlockRanges(String source) {
  final ranges = <TextRange>[];
  var offset = 0;
  while (offset < source.length) {
    final start = offset;
    String? fence;
    do {
      final newline = source.indexOf('\n', offset);
      final end = newline < 0 ? source.length : newline + 1;
      final line = source.substring(offset, end).trim();
      final match = RegExp(r'^(`{3,}|~{3,})').firstMatch(line);
      if (match != null) {
        if (fence == null) {
          fence = match.group(1);
        } else if (line.startsWith(fence)) {
          fence = null;
        }
      }
      offset = end;
      if (line.isEmpty && fence == null) break;
    } while (offset < source.length);
    ranges.add(TextRange(start: start, end: offset));
  }
  return ranges;
}

class MarkdownRenderedBlock extends StatelessWidget {
  const MarkdownRenderedBlock({
    super.key,
    required this.markdown,
    required this.theme,
    this.imageDirectory,
    this.builders = const {},
    this.selectable = false,
    this.onTapLink,
  });
  final String markdown;
  final ThemeData theme;
  final String? imageDirectory;
  final Map<String, MarkdownElementBuilder> builders;
  final bool selectable;
  final void Function(String, String?, String?)? onTapLink;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: MarkdownBody(
      data: markdown,
      imageDirectory: imageDirectory,
      builders: builders,
      selectable: selectable,
      onTapLink: onTapLink,
      fitContent: false,
      styleSheet: MarkdownDocumentStyle.sheet(theme),
    ),
  );
}
