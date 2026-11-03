/// A picture's display size, written Obsidian-style at the end of its alt
/// text: `![alt|300](src)` sets the width and keeps the picture's
/// proportions, `![alt|300x200](src)` sets both sides.
class MarkdownImageSize {
  const MarkdownImageSize(this.width, [this.height]);

  final int width;

  /// Null keeps the picture's own proportions.
  final int? height;

  @override
  bool operator ==(Object other) =>
      other is MarkdownImageSize &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => height == null ? '$width' : '${width}x$height';
}

/// `alt|300` or `alt|300x200`. In a table cell the bar is written `\|`.
final _sizedAlt = RegExp(r'^(.*?)\s*\\?\|\s*(\d+)(?:\s*[xX]\s*(\d+))?\s*$');

/// Splits a picture's alt text into its label and the size written after it.
(String, MarkdownImageSize?) splitImageAlt(String alt) {
  final match = _sizedAlt.firstMatch(alt);
  if (match == null) return (alt, null);
  final width = int.parse(match.group(2)!);
  final height = match.group(3) == null ? null : int.parse(match.group(3)!);
  if (width <= 0 || (height != null && height <= 0)) return (alt, null);
  return (match.group(1)!, MarkdownImageSize(width, height));
}

/// Writes [size] after the label [alt]; a null size leaves the label alone.
String joinImageAlt(String alt, MarkdownImageSize? size) =>
    size == null ? alt : '$alt|$size';

/// A block that is a single picture link, `![alt](src "title")`, possibly
/// with blank space around it.
class MarkdownImageLink {
  MarkdownImageLink._(
    this._before,
    this.alt,
    this.size,
    this.target,
    this._after,
  );

  static final _pattern = RegExp(
    r'^(\s*)!\[([^\[\]]*)\]\(((?:[^()\n]|\([^()\n]*\))*)\)(\s*)$',
  );

  /// The picture in [block], or null when the block holds anything else.
  static MarkdownImageLink? parse(String block) {
    final match = _pattern.firstMatch(block);
    if (match == null) return null;
    final (alt, size) = splitImageAlt(match.group(2)!);
    return MarkdownImageLink._(
      match.group(1)!,
      alt,
      size,
      match.group(3)!,
      match.group(4)!,
    );
  }

  final String _before;
  final String _after;

  /// The alt text without its size.
  final String alt;
  final MarkdownImageSize? size;

  /// The link target, including any title.
  final String target;

  /// The link's address without its title.
  String get src {
    final trimmed = target.trim();
    final angled = RegExp(r'^<([^>]*)>').firstMatch(trimmed);
    if (angled != null) return angled.group(1)!;
    return trimmed.split(RegExp(r'\s+')).first;
  }

  /// The block's Markdown with the picture shown at [size] (null resets it).
  String withSize(MarkdownImageSize? size) =>
      '$_before![${joinImageAlt(alt, size)}]($target)$_after';
}
