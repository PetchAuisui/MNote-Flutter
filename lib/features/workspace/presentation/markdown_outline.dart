import 'markdown_rendered_block.dart';

/// One heading of a document, in source order.
class MarkdownHeading {
  const MarkdownHeading({
    required this.level,
    required this.title,
    required this.offset,
  });

  /// 1 for `#` through 6 for `######`.
  final int level;
  final String title;

  /// Where the heading starts in the source, so it can be matched to a block.
  final int offset;

  @override
  bool operator ==(Object other) =>
      other is MarkdownHeading &&
      other.level == level &&
      other.title == title &&
      other.offset == offset;

  @override
  int get hashCode => Object.hash(level, title, offset);
}

final _atxHeading = RegExp(r'^ {0,3}(#{1,6})[ \t]+(.*?)(?:[ \t]+#+)?[ \t]*$');
final _atxEmptyHeading = RegExp(r'^ {0,3}(#{1,6})[ \t]*$');
final _setextUnderline = RegExp(r'^ {0,3}(=+|-+)[ \t]*$');

/// Headings of [source], read from the same blocks the editor renders so code
/// fences never produce false entries and every heading maps to a block.
List<MarkdownHeading> parseMarkdownHeadings(String source) {
  final headings = <MarkdownHeading>[];
  for (final range in markdownBlockRanges(source)) {
    final text = range.textInside(source);
    final lines = text.split('\n');
    final first = lines.first.replaceFirst(RegExp(r'\r$'), '');

    final atx = _atxHeading.firstMatch(first);
    if (atx != null) {
      headings.add(
        MarkdownHeading(
          level: atx.group(1)!.length,
          title: _plainTitle(atx.group(2)!),
          offset: range.start,
        ),
      );
      continue;
    }
    final empty = _atxEmptyHeading.firstMatch(first);
    if (empty != null) {
      headings.add(
        MarkdownHeading(
          level: empty.group(1)!.length,
          title: '',
          offset: range.start,
        ),
      );
      continue;
    }

    // A setext heading is a single text line over a run of = or -.
    if (lines.length == 2) {
      final underline = _setextUnderline.firstMatch(
        lines[1].replaceFirst(RegExp(r'\r$'), ''),
      );
      if (underline != null && first.trim().isNotEmpty) {
        headings.add(
          MarkdownHeading(
            level: underline.group(1)!.startsWith('=') ? 1 : 2,
            title: _plainTitle(first.trim()),
            offset: range.start,
          ),
        );
      }
    }
  }
  return headings;
}

/// Drops the inline syntax that would look like noise in a list of titles.
String _plainTitle(String raw) {
  return raw
      .replaceAllMapped(RegExp(r'!?\[([^\]]*)\]\([^)]*\)'), (m) => m.group(1)!)
      .replaceAll(RegExp(r'[*_~`]+'), '')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .trim();
}
