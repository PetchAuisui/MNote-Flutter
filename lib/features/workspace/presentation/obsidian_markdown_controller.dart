import 'package:flutter/material.dart';
import 'markdown_document_style.dart';

/// A [TextEditingController] that provides Obsidian-style live Markdown preview
/// directly inside the editor. Headings, bold, italics, inline code, blockquotes,
/// lists, links, and code blocks are rendered with live rich typography, while
/// syntax is revealed on selected lines and hidden elsewhere when enabled.
class ObsidianMarkdownEditingController extends TextEditingController {
  ObsidianMarkdownEditingController({
    super.text,
    this.primaryColor = const Color(0xFF1E88E5),
    this.onSurfaceColor = const Color(0xFF202124),
    this.hideInactiveSyntax = false,
    this.showRawSource = false,
  });

  final bool showRawSource;
  final bool hideInactiveSyntax;
  bool _editorHasFocus = false;
  bool _hideSyntax = false;

  bool get editorHasFocus => _editorHasFocus;

  set editorHasFocus(bool value) {
    if (_editorHasFocus == value) return;
    _editorHasFocus = value;
    notifyListeners();
  }

  TextStyle _syntaxStyle(TextStyle style) => _hideSyntax
      ? style.copyWith(
          fontSize: 0,
          letterSpacing: 0,
          wordSpacing: 0,
          color: Colors.transparent,
          backgroundColor: Colors.transparent,
          decoration: TextDecoration.none,
        )
      : style.copyWith(color: style.color?.withValues(alpha: 0.45));

  Color primaryColor;
  Color onSurfaceColor;

  static final _inlinePattern = RegExp(
    r'(!?\[[^\]]*\]\([^)]*\))'
    r'|(`[^`\n]+`)'
    r'|(\*\*\*[^\*\n]+?\*\*\*)'
    r'|(\*\*[^\*\n]+?\*\*)'
    r'|(~~[^~\n]+?~~)'
    r'|(\*[^\*\n]+?\*)'
    r'|(_[^_\n]+?_)'
    r'|(<br\s*/?>)',
  );

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (showRawSource) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final baseStyle = style ?? const TextStyle();
    if (text.isEmpty) {
      return TextSpan(style: baseStyle, text: text);
    }

    final spans = <InlineSpan>[];
    final lines = text.split('\n');
    bool inCodeBlock = false;
    var lineOffset = 0;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final isLastLine = i == lines.length - 1;
      final lineSuffix = isLastLine ? '' : '\n';
      final lineEnd = lineOffset + line.length;
      final selected =
          _editorHasFocus &&
          selection.isValid &&
          selection.start <= lineEnd &&
          selection.end >= lineOffset;
      final composing =
          withComposing &&
          value.composing.isValid &&
          !value.composing.isCollapsed &&
          value.composing.start <= lineEnd &&
          value.composing.end >= lineOffset;
      _hideSyntax = hideInactiveSyntax && !selected && !composing;
      lineOffset = lineEnd + lineSuffix.length;

      // Code block boundary: ``` or ~~~
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
        inCodeBlock = !inCodeBlock;
        spans.add(
          TextSpan(
            text: line,
            style: _syntaxStyle(
              baseStyle.copyWith(
                color: primaryColor,
                fontFamily: 'monospace',
                backgroundColor: const Color(0x12000000),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
        if (lineSuffix.isNotEmpty) {
          spans.add(TextSpan(text: lineSuffix, style: baseStyle));
        }
        continue;
      }

      if (inCodeBlock) {
        spans.add(
          TextSpan(
            text: '$line$lineSuffix',
            style: baseStyle.copyWith(
              fontFamily: 'monospace',
              backgroundColor: const Color(0x0C000000),
              color: const Color(0xFF374151),
            ),
          ),
        );
        continue;
      }

      spans.addAll(_parseLine(line, baseStyle, lineSuffix));
    }

    return TextSpan(children: spans);
  }

  List<InlineSpan> _parseLine(
    String line,
    TextStyle baseStyle,
    String lineSuffix,
  ) {
    // 1. Headings (# H1 to ###### H6)
    if (line.startsWith('#')) {
      final match = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(line);
      if (match != null) {
        final hashes = match.group(1)!;
        final headingText = match.group(2)!;
        final level = hashes.length;

        final double factor;
        final FontWeight weight;
        final Color headingColor;

        switch (level) {
          case 1:
            factor = 28 / 17;
            weight = FontWeight.bold;
            headingColor = onSurfaceColor;
            break;
          case 2:
            factor = 24 / 17;
            weight = FontWeight.bold;
            headingColor = onSurfaceColor;
            break;
          case 3:
            factor = 20 / 17;
            weight = FontWeight.w600;
            headingColor = onSurfaceColor;
            break;
          default:
            factor = MarkdownDocumentStyle.headingSizes[level - 1] / 17;
            weight = FontWeight.w600;
            headingColor = onSurfaceColor;
            break;
        }

        final headingStyle = baseStyle.copyWith(
          fontSize: (baseStyle.fontSize ?? 15) * factor,
          fontWeight: weight,
          color: headingColor,
        );
        final markerStyle = headingStyle.copyWith(
          color: headingColor.withValues(alpha: 0.4),
          fontWeight: FontWeight.normal,
        );

        return [
          TextSpan(text: '$hashes ', style: _syntaxStyle(markerStyle)),
          ..._parseInlineFormatting(headingText, headingStyle),
          if (lineSuffix.isNotEmpty)
            TextSpan(text: lineSuffix, style: headingStyle),
        ];
      }
    }

    // 2. Blockquotes (> quote)
    if (line.startsWith('>')) {
      final match = RegExp(r'^(>\s?)(.*)$').firstMatch(line);
      if (match != null) {
        final prefix = match.group(1)!;
        final quoteText = match.group(2)!;
        final quoteStyle = baseStyle.copyWith(color: onSurfaceColor);
        final prefixStyle = quoteStyle.copyWith(
          color: primaryColor.withValues(alpha: 0.6),
          fontWeight: FontWeight.bold,
        );

        return [
          TextSpan(text: prefix, style: _syntaxStyle(prefixStyle)),
          ..._parseInlineFormatting(quoteText, quoteStyle),
          if (lineSuffix.isNotEmpty)
            TextSpan(text: lineSuffix, style: quoteStyle),
        ];
      }
    }

    // 3. Task lists (- [ ] or - [x])
    final taskMatch = RegExp(
      r'^(\s*[-*+]\s+\[([ xX])\]\s+)(.*)$',
    ).firstMatch(line);
    if (taskMatch != null) {
      final prefix = taskMatch.group(1)!;
      final checked = taskMatch.group(2)!.trim().isNotEmpty;
      final bodyText = taskMatch.group(3)!;

      final taskStyle = checked
          ? baseStyle.copyWith(
              color: const Color(0xFF9E9E9E),
              decoration: TextDecoration.lineThrough,
            )
          : baseStyle;
      final prefixStyle = baseStyle.copyWith(
        color: checked ? primaryColor : const Color(0xFF757575),
        fontWeight: FontWeight.bold,
      );

      return [
        TextSpan(text: prefix, style: prefixStyle),
        ..._parseInlineFormatting(bodyText, taskStyle),
        if (lineSuffix.isNotEmpty) TextSpan(text: lineSuffix, style: taskStyle),
      ];
    }

    // Rules take precedence over list markers such as "* * *".
    if (RegExp(r'^\s*([*\-_])\s*(\1\s*){2,}\s*$').hasMatch(line)) {
      return [
        TextSpan(
          text: line,
          style: _syntaxStyle(
            baseStyle.copyWith(
              color: const Color(0xFFBDBDBD),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (lineSuffix.isNotEmpty) TextSpan(text: lineSuffix, style: baseStyle),
      ];
    }

    // 4. Unordered and ordered lists (- item, * item, 1. item)
    final listMatch = RegExp(r'^(\s*(?:[-*+]|\d+\.)\s+)(.*)$').firstMatch(line);
    if (listMatch != null) {
      final prefix = listMatch.group(1)!;
      final bodyText = listMatch.group(2)!;
      final prefixStyle = baseStyle.copyWith(
        color: primaryColor,
        fontWeight: FontWeight.w600,
      );
      return [
        if (_hideSyntax && RegExp(r'^\s*[-*+]').hasMatch(prefix)) ...[
          TextSpan(
            text: prefix.substring(0, prefix.indexOf(RegExp(r'[-*+]'))),
            style: baseStyle,
          ),
          TextSpan(
            text: prefix.substring(
              prefix.indexOf(RegExp(r'[-*+]')),
              prefix.indexOf(RegExp(r'[-*+]')) + 1,
            ),
            style: _syntaxStyle(
              prefixStyle,
            ).copyWith(letterSpacing: (baseStyle.fontSize ?? 15) * 0.6),
          ),
          TextSpan(
            text: prefix.substring(prefix.indexOf(RegExp(r'[-*+]')) + 1),
            style: baseStyle,
          ),
        ] else
          TextSpan(text: prefix, style: prefixStyle),
        ..._parseInlineFormatting(bodyText, baseStyle),
        if (lineSuffix.isNotEmpty) TextSpan(text: lineSuffix, style: baseStyle),
      ];
    }

    // 6. Regular paragraph lines
    return [
      ..._parseInlineFormatting(line, baseStyle),
      if (lineSuffix.isNotEmpty) TextSpan(text: lineSuffix, style: baseStyle),
    ];
  }

  List<InlineSpan> _parseInlineFormatting(String text, TextStyle currentStyle) {
    if (text.isEmpty) return [];

    final spans = <InlineSpan>[];
    final matches = _inlinePattern.allMatches(text);
    var lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match.start),
            style: currentStyle,
          ),
        );
      }

      final raw = match.group(0)!;

      if (RegExp(r'^<br\s*/?>$').hasMatch(raw)) {
        spans.add(TextSpan(text: raw, style: _syntaxStyle(currentStyle)));
      } else if (raw.startsWith('![') && raw.contains('](')) {
        // Image: ![alt](url)
        final closingBracket = raw.indexOf('](');
        final alt = raw.substring(2, closingBracket);
        final url = raw.substring(closingBracket + 2, raw.length - 1);
        spans.add(TextSpan(text: '![', style: _syntaxStyle(currentStyle)));
        spans.add(
          TextSpan(
            text: alt,
            style: currentStyle.copyWith(
              fontStyle: FontStyle.italic,
              color: primaryColor,
            ),
          ),
        );
        spans.add(TextSpan(text: ']($url)', style: _syntaxStyle(currentStyle)));
      } else if (raw.startsWith('[') && raw.contains('](')) {
        // Link: [text](url)
        final closingBracket = raw.indexOf('](');
        final linkText = raw.substring(1, closingBracket);
        final url = raw.substring(closingBracket + 2, raw.length - 1);
        spans.add(TextSpan(text: '[', style: _syntaxStyle(currentStyle)));
        spans.add(
          TextSpan(
            text: linkText,
            style: currentStyle.copyWith(
              color: const Color(0xFF1976D2),
              decoration: TextDecoration.underline,
            ),
          ),
        );
        spans.add(TextSpan(text: ']($url)', style: _syntaxStyle(currentStyle)));
      } else if (raw.startsWith('`') && raw.endsWith('`') && raw.length >= 2) {
        // Inline code: `code`
        final codeBody = raw.substring(1, raw.length - 1);
        spans.add(TextSpan(text: '`', style: _syntaxStyle(currentStyle)));
        spans.add(
          TextSpan(
            text: codeBody,
            style: currentStyle.copyWith(
              fontFamily: 'monospace',
              color: onSurfaceColor,
              fontSize: (currentStyle.fontSize ?? 17) * 15 / 17,
              backgroundColor: const Color(0x14000000),
            ),
          ),
        );
        spans.add(TextSpan(text: '`', style: _syntaxStyle(currentStyle)));
      } else if (raw.startsWith('***') &&
          raw.endsWith('***') &&
          raw.length >= 6) {
        // Bold Italic: ***text***
        final body = raw.substring(3, raw.length - 3);
        spans.add(TextSpan(text: '***', style: _syntaxStyle(currentStyle)));
        spans.add(
          TextSpan(
            text: body,
            style: currentStyle.copyWith(
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
        spans.add(TextSpan(text: '***', style: _syntaxStyle(currentStyle)));
      } else if (raw.startsWith('**') &&
          raw.endsWith('**') &&
          raw.length >= 4) {
        // Bold: **text**
        final body = raw.substring(2, raw.length - 2);
        spans.add(TextSpan(text: '**', style: _syntaxStyle(currentStyle)));
        spans.add(
          TextSpan(
            text: body,
            style: currentStyle.copyWith(fontWeight: FontWeight.bold),
          ),
        );
        spans.add(TextSpan(text: '**', style: _syntaxStyle(currentStyle)));
      } else if (raw.startsWith('~~') &&
          raw.endsWith('~~') &&
          raw.length >= 4) {
        // Strikethrough: ~~text~~
        final body = raw.substring(2, raw.length - 2);
        spans.add(TextSpan(text: '~~', style: _syntaxStyle(currentStyle)));
        spans.add(
          TextSpan(
            text: body,
            style: currentStyle.copyWith(
              decoration: TextDecoration.lineThrough,
              color: currentStyle.color?.withValues(alpha: 0.6),
            ),
          ),
        );
        spans.add(TextSpan(text: '~~', style: _syntaxStyle(currentStyle)));
      } else if ((raw.startsWith('*') &&
              raw.endsWith('*') &&
              raw.length >= 2) ||
          (raw.startsWith('_') && raw.endsWith('_') && raw.length >= 2)) {
        // Italic: *text* or _text_
        final marker = raw.substring(0, 1);
        final body = raw.substring(1, raw.length - 1);
        spans.add(TextSpan(text: marker, style: _syntaxStyle(currentStyle)));
        spans.add(
          TextSpan(
            text: body,
            style: currentStyle.copyWith(fontStyle: FontStyle.italic),
          ),
        );
        spans.add(TextSpan(text: marker, style: _syntaxStyle(currentStyle)));
      } else {
        spans.add(TextSpan(text: raw, style: currentStyle));
      }

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: currentStyle));
    }

    return spans;
  }
}
