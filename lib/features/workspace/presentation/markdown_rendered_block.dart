import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'markdown_document_style.dart';

/// Source ranges used by both the preview and the editable document.
///
/// Returns discrete ranges for each non-empty line, while preserving fenced
/// code blocks (``` or ~~~) as unified multi-line blocks.
/// Blank lines are excluded from ranges so they remain untouched.
List<TextRange> markdownBlockRanges(String source) {
  final ranges = <TextRange>[];
  var offset = 0;
  while (offset < source.length) {
    final newline = source.indexOf('\n', offset);
    final lineEnd = newline < 0 ? source.length : newline;
    final line = source.substring(offset, lineEnd);

    if (line.trim().isEmpty) {
      // Blank line: skip without creating a range
      offset = newline < 0 ? source.length : newline + 1;
      continue;
    }

    final trimmed = line.trimLeft();
    final match = RegExp(r'^(`{3,}|~{3,})').firstMatch(trimmed);
    if (match != null) {
      // Fenced code block: keep entire block together as one range
      final fence = match.group(1)!;
      final start = offset;
      var fenceOffset = newline < 0 ? source.length : newline + 1;
      while (fenceOffset < source.length) {
        final nextNewline = source.indexOf('\n', fenceOffset);
        final nextLineEnd = nextNewline < 0 ? source.length : nextNewline;
        final nextLine = source.substring(fenceOffset, nextLineEnd).trimLeft();
        fenceOffset = nextNewline < 0 ? source.length : nextNewline + 1;
        if (nextLine.startsWith(fence)) {
          break;
        }
      }
      final end =
          fenceOffset > 0 &&
              fenceOffset <= source.length &&
              source[fenceOffset - 1] == '\n'
          ? fenceOffset - 1
          : fenceOffset;
      ranges.add(TextRange(start: start, end: end));
      offset = fenceOffset;
      continue;
    }

    // Single line block
    ranges.add(TextRange(start: offset, end: lineEnd));
    offset = newline < 0 ? source.length : newline + 1;
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
  Widget build(BuildContext context) {
    // Each list line is rendered independently, so retain its source nesting
    // before the Markdown parser normalizes leading whitespace.
    final list = RegExp(r'^( *)(?:[-*+]|\d+\.)\s+').firstMatch(markdown);
    final indent = list?.group(1)?.length ?? 0;
    final depth = (indent / 2).ceil();
    return Padding(
      padding: EdgeInsets.only(top: 8, bottom: 8, left: depth * 32.0),
      child: MarkdownBody(
        data: list == null ? markdown : markdown.substring(indent),
        imageDirectory: imageDirectory,
        builders: builders,
        selectable: selectable,
        onTapLink: onTapLink,
        fitContent: false,
        styleSheet: MarkdownDocumentStyle.sheet(theme),
        bulletBuilder: (parameters) => Text(
          parameters.style == BulletStyle.orderedList
              ? '${parameters.index + 1}.'
              : depth == 0
              ? '•'
              : '◦',
          style: MarkdownDocumentStyle.sheet(theme).listBullet!.copyWith(
            fontSize:
                parameters.style == BulletStyle.unorderedList && depth == 0
                ? 26
                : MarkdownDocumentStyle.bodySize,
            height: parameters.style == BulletStyle.unorderedList && depth == 0
                ? MarkdownDocumentStyle.bodySize *
                      MarkdownDocumentStyle.lineHeight /
                      26
                : MarkdownDocumentStyle.lineHeight,
          ),
        ),
      ),
    );
  }
}
