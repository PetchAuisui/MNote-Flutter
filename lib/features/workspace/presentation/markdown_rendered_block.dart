import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:path_provider/path_provider.dart';
import 'markdown_document_style.dart';

class _LineBreakSyntax extends md.InlineSyntax {
  _LineBreakSyntax() : super(r'[ \t]*<[bB][rR]\s*/?>[ \t]*\n?');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.empty('br'));
    return true;
  }
}

/// Loads a picture referenced from a note. Relative paths resolve against the
/// note's folder, then the app documents folder (where pictures land for a note
/// without a file location). A missing file shows a placeholder, not a gap.
class _DocumentImage extends StatefulWidget {
  const _DocumentImage({
    required this.uri,
    this.directory,
    this.alt,
    this.width,
    this.height,
  });

  final Uri uri;
  final String? directory;
  final String? alt;
  final double? width;
  final double? height;

  @override
  State<_DocumentImage> createState() => _DocumentImageState();
}

class _DocumentImageState extends State<_DocumentImage> {
  // Looked up once, not on every rebuild, so the picture does not flicker.
  late Future<File?> _file = _locate();

  Uri get uri => widget.uri;
  double? get width => widget.width;
  double? get height => widget.height;

  @override
  void didUpdateWidget(_DocumentImage old) {
    super.didUpdateWidget(old);
    if (old.uri != widget.uri || old.directory != widget.directory) {
      _file = _locate();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      return Image.network(
        uri.toString(),
        width: width,
        height: height,
        errorBuilder: _broken,
      );
    }
    if (uri.scheme == 'data') {
      final data = uri.data;
      if (data == null) return _broken(context, 'invalid data uri', null);
      return Image.memory(
        data.contentAsBytes(),
        width: width,
        height: height,
        errorBuilder: _broken,
      );
    }
    return FutureBuilder<File?>(
      future: _file,
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file == null) {
          return snapshot.connectionState == ConnectionState.done
              ? _broken(context, 'not found: $uri', null)
              : const SizedBox(height: 24);
        }
        return Image.file(
          file,
          width: width,
          height: height,
          errorBuilder: _broken,
        );
      },
    );
  }

  Future<File?> _locate() async {
    if (uri.scheme == 'file') return File.fromUri(uri);
    final candidates = <Directory>[];
    final base = widget.directory;
    if (base != null) candidates.add(Directory.fromUri(Uri.parse(base)));
    try {
      candidates.add(await getApplicationDocumentsDirectory());
    } on Object {
      // No documents folder on this platform; the note folder is all we have.
    }
    final relative = Uri.decodeFull(uri.path);
    // A synced note must not point the viewer at files outside its folders.
    if (relative.split(RegExp(r'[\\/]')).contains('..')) return null;
    for (final directory in candidates) {
      final file = File('${directory.path}/$relative');
      if (await file.exists()) return file;
    }
    return null;
  }

  Widget _broken(BuildContext context, Object error, StackTrace? stack) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, color: scheme.outline),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              widget.alt?.isNotEmpty == true ? widget.alt! : uri.toString(),
              style: TextStyle(color: scheme.outline),
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws `img` elements. Pictures stored next to the note go through
/// [_DocumentImage], which also covers web and `data:` links. App assets
/// (`resource:`) are drawn here. All honour the `#WIDTHxHEIGHT` size suffix.
class _ImageElementBuilder extends MarkdownElementBuilder {
  _ImageElementBuilder(this.directory);

  final String? directory;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final parts = (element.attributes['src'] ?? '').split('#');
    final uri = Uri.tryParse(parts.first);
    if (uri == null) return const SizedBox();
    double? width;
    double? height;
    if (parts.length == 2) {
      final size = parts.last.split('x');
      if (size.length == 2) {
        width = double.tryParse(size[0]);
        height = double.tryParse(size[1]);
      }
    }
    if (uri.scheme == 'resource') {
      return Image.asset(
        uri.path,
        width: width,
        height: height,
        errorBuilder: (_, _, _) => const SizedBox(),
      );
    }
    return _DocumentImage(
      uri: uri,
      directory: directory,
      alt: element.attributes['alt'],
      width: width,
      height: height,
    );
  }
}

/// Shared parser context for blocks that are edited independently.
class MarkdownBlockContext {
  MarkdownBlockContext(String source, List<TextRange> ranges) {
    final document = md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      encodeHtml: false,
    )..parseLines(source.split('\n'));
    references = document.linkReferences;

    final counters = <int, int>{};
    for (final range in ranges) {
      final text = range.textInside(source);
      final item = RegExp(r'^( *)(?:(\d+)[.)]|[-*+])\s+').firstMatch(text);
      if (item == null) {
        counters.clear();
        continue;
      }
      final indent = item.group(1)!.length;
      counters.removeWhere((depth, _) => depth > indent);
      final number = item.group(2);
      if (number == null) {
        counters.remove(indent);
      } else {
        final next = counters.containsKey(indent)
            ? counters[indent]! + 1
            : int.parse(number);
        counters[indent] = next;
        orderedNumbers[range.start] = next;
      }
    }
  }

  late final Map<String, md.LinkReference> references;
  final orderedNumbers = <int, int>{};
}

class _ReferenceContextSyntax extends md.InlineSyntax {
  _ReferenceContextSyntax(this.references) : super(r'!?\[');

  final Map<String, md.LinkReference> references;
  md.Document? _document;

  @override
  bool tryMatch(md.InlineParser parser, [int? startMatchPos]) {
    if (!identical(_document, parser.document)) {
      parser.document.linkReferences.addAll(references);
      _document = parser.document;
    }
    return false;
  }

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    // Let the standard link/image syntax consume the text with the shared
    // definitions, retaining its normal label formatting and escaping rules.
    return false;
  }
}

/// Source ranges used by both the preview and the editable document.
///
/// Keeps paragraphs, setext headings, fenced code and tables together so
/// their Markdown syntax is parsed with its surrounding lines.
/// Blank lines are excluded from ranges so they remain untouched.
List<TextRange> markdownBlockRanges(String source) {
  final ranges = <TextRange>[];
  final lines = source.split('\n');
  final lineOffsets = <int>[];
  var lineOffset = 0;
  for (final line in lines) {
    lineOffsets.add(lineOffset);
    lineOffset += line.length + 1;
  }
  final parser = md.BlockParser(
    lines.map(md.Line.new).toList(),
    md.Document(extensionSet: md.ExtensionSet.gitHubFlavored),
  );
  var parserLine = 0;
  void advanceParser() {
    parser.advance();
    parserLine++;
  }

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

    final fencePattern = const md.FencedCodeBlockSyntax().pattern;
    final match = fencePattern.firstMatch(line);
    if (match != null) {
      // Fenced code block: keep entire block together as one range
      final fence = match.namedGroup('backtick') ?? match.namedGroup('tilde')!;
      final start = offset;
      var fenceOffset = newline < 0 ? source.length : newline + 1;
      while (fenceOffset < source.length) {
        final nextNewline = source.indexOf('\n', fenceOffset);
        final nextLineEnd = nextNewline < 0 ? source.length : nextNewline;
        final nextLine = source.substring(fenceOffset, nextLineEnd);
        fenceOffset = nextNewline < 0 ? source.length : nextNewline + 1;
        final closing = fencePattern.firstMatch(nextLine);
        final marker =
            closing?.namedGroup('backtick') ?? closing?.namedGroup('tilde');
        final info =
            closing?.namedGroup('backtickInfo') ??
            closing?.namedGroup('tildeInfo');
        if (marker != null &&
            marker.startsWith(fence) &&
            info!.trim().isEmpty) {
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

    // A table needs its header, separator and rows in the same parser call.
    if (line.contains('|') && newline >= 0) {
      final separatorStart = newline + 1;
      final separatorNewline = source.indexOf('\n', separatorStart);
      final separatorEnd = separatorNewline < 0
          ? source.length
          : separatorNewline;
      final separator = source.substring(separatorStart, separatorEnd);
      if (RegExp(
        r'^\s*\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|?\s*$',
      ).hasMatch(separator)) {
        var end = separatorEnd;
        var next = separatorNewline < 0 ? source.length : separatorNewline + 1;
        while (next < source.length) {
          final rowNewline = source.indexOf('\n', next);
          final rowEnd = rowNewline < 0 ? source.length : rowNewline;
          final row = source.substring(next, rowEnd);
          if (row.trim().isEmpty || !row.contains('|')) break;
          end = rowEnd;
          next = rowNewline < 0 ? source.length : rowNewline + 1;
        }
        ranges.add(TextRange(start: offset, end: end));
        offset = next;
        continue;
      }
    }

    // Use the renderer's block rules to identify paragraph boundaries. Inline
    // emphasis and setext underlines need the complete paragraph to parse.
    while (!parser.isDone && lineOffsets[parserLine] < offset) {
      advanceParser();
    }
    final syntax = parser.blockSyntaxes.firstWhere(
      (syntax) => syntax.canParse(parser),
    );
    if (syntax is md.BlockquoteSyntax) {
      // Preserve quote boundaries, lazy continuations and nested fenced code.
      final childLines = syntax.parseChildLines(parser);
      parserLine += childLines.length;
      final lastLine = parserLine - 1;
      ranges.add(
        TextRange(
          start: offset,
          end: lineOffsets[lastLine] + lines[lastLine].length,
        ),
      );
      offset = parser.isDone ? source.length : lineOffsets[parserLine];
      continue;
    }
    if (syntax is md.ListSyntax) {
      // Keep each item independently editable, but retain its paragraph's
      // continuation lines so inline formatting can span them.
      advanceParser();
      while (!parser.isDone && !parser.current.isBlankLine) {
        if (RegExp(
          r'^\s*(?:[-*+]|\d+[.)])\s+',
        ).hasMatch(parser.current.content)) {
          break;
        }
        final continuation = parser.blockSyntaxes.firstWhere(
          (syntax) => syntax.canParse(parser),
        );
        if (continuation is! md.ParagraphSyntax &&
            continuation is! md.CodeBlockSyntax) {
          break;
        }
        advanceParser();
      }
      final lastLine = parserLine - 1;
      ranges.add(
        TextRange(
          start: offset,
          end: lineOffsets[lastLine] + lines[lastLine].length,
        ),
      );
      offset = parser.isDone ? source.length : lineOffsets[parserLine];
      continue;
    }
    if (syntax is md.ParagraphSyntax) {
      advanceParser();
      while (!parser.isDone) {
        // We only inspect syntax rules here, so BlockParser.currentSyntax is
        // unset. Recognize the underline before the horizontal-rule rule.
        if (const md.SetextHeaderSyntax().pattern.hasMatch(
          parser.current.content,
        )) {
          advanceParser();
          break;
        }
        final interruption = syntax.interruptedBy(parser);
        if (interruption != null) {
          if (interruption is md.SetextHeaderSyntax) advanceParser();
          break;
        }
        advanceParser();
      }
      final lastLine = parserLine - 1;
      ranges.add(
        TextRange(
          start: offset,
          end: lineOffsets[lastLine] + lines[lastLine].length,
        ),
      );
      offset = parser.isDone ? source.length : lineOffsets[parserLine];
      continue;
    }

    // Other standalone lines (including independently editable list items).
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
    this.references = const {},
    this.orderedNumber,
    this.textOptions = const DocumentTextOptions(),
  });
  final String markdown;
  final Map<String, md.LinkReference> references;
  final int? orderedNumber;
  final ThemeData theme;
  final String? imageDirectory;
  final Map<String, MarkdownElementBuilder> builders;
  final bool selectable;
  final void Function(String, String?, String?)? onTapLink;
  final DocumentTextOptions textOptions;

  @override
  Widget build(BuildContext context) {
    // Each list line is rendered independently, so retain its source nesting
    // before the Markdown parser normalizes leading whitespace.
    final list = RegExp(r'^( *)(?:[-*+]|\d+[.)])\s+').firstMatch(markdown);
    final indent = list?.group(1)?.length ?? 0;
    final depth = (indent / 2).ceil();
    final sheet = MarkdownDocumentStyle.sheet(theme, textOptions);
    return Padding(
      padding: EdgeInsets.only(top: 8, bottom: 8, left: depth * 32.0),
      child: MarkdownBody(
        data: list == null ? markdown : markdown.substring(indent),
        inlineSyntaxes: [
          if (references.isNotEmpty) _ReferenceContextSyntax(references),
          _LineBreakSyntax(),
        ],
        builders: {'img': _ImageElementBuilder(imageDirectory), ...builders},
        selectable: selectable,
        onTapLink: onTapLink,
        fitContent: false,
        styleSheet: sheet,
        syntaxHighlighter: MarkdownDocumentStyle.codeBlockHighlighter(sheet),
        bulletBuilder: (parameters) {
          if (parameters.style == BulletStyle.orderedList) {
            return Text(
              '${orderedNumber ?? parameters.index + 1}.',
              style: sheet.listBullet,
            );
          }
          final diameter = depth == 0 ? 8.0 : 6.0;
          return SizedBox(
            height: textOptions.bodySize * textOptions.lineHeight,
            child: Center(
              child: Container(
                width: diameter,
                height: diameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: depth == 0 ? MarkdownDocumentStyle.textColor : null,
                  border: depth == 0
                      ? null
                      : Border.all(
                          color: MarkdownDocumentStyle.textColor,
                          width: 1.2,
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
