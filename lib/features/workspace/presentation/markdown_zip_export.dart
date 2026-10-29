import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';

import 'markdown_rendered_block.dart';

/// Folder inside the zip that holds the note's pictures.
const markdownZipImageFolder = 'img';

/// Picture links in a note: `![alt](src "title")` and `<img src="...">`.
/// Group `src` is the link, which may carry a `#WIDTHxHEIGHT` size suffix.
final _imageLink = RegExp(
  r'(!\[[^\]]*\]\(\s*<?)(?<src>[^)\s>]+)(>?(?:\s+"[^"]*")?\s*\))'
  r'''|(<img\b[^>]*?\bsrc\s*=\s*["'])(?<html>[^"']+)(["'])''',
  caseSensitive: false,
);

/// Fenced code blocks, where image syntax is code to show, not a picture.
final _fencedCode = RegExp(
  r'^ {0,3}(`{3,}|~{3,})[^\n]*\n[\s\S]*?(?:^ {0,3}\1[`~]*[ \t]*$|(?![\s\S]))',
  multiLine: true,
);

/// Picture links in [markdown] outside fenced code blocks.
Iterable<RegExpMatch> _imageLinks(String markdown) {
  final code = _fencedCode.allMatches(markdown).toList();
  return _imageLink
      .allMatches(markdown)
      .where((m) => !code.any((c) => m.start >= c.start && m.start < c.end));
}

/// The picture links in [markdown], in order, without size suffixes.
Iterable<Uri> markdownImageUris(String markdown) sync* {
  for (final match in _imageLinks(markdown)) {
    final src = match.namedGroup('src') ?? match.namedGroup('html')!;
    final uri = Uri.tryParse(src.split('#').first);
    if (uri != null) yield uri;
  }
}

/// Packs a note as a zip: `<fileName>.md` at the top and its pictures in
/// `img/`, with the note's links rewritten to point there. Web links stay as
/// they are; a picture that cannot be found keeps its original link.
Future<Uint8List> buildMarkdownZip({
  required String markdown,
  required String fileName,
  String? imageDirectory,
  AssetBundle? bundle,
}) async {
  final archive = Archive()
    ..addFile(ArchiveFile.directory('$markdownZipImageFolder/'));
  final packed = <String, String>{};
  final usedNames = <String>{};

  Future<String?> pack(String link) async {
    if (packed.containsKey(link)) return packed[link];
    final bytes = await _readImage(link, imageDirectory, bundle ?? rootBundle);
    if (bytes == null) return null;
    final name = _uniqueName(_imageName(link, bytes), usedNames);
    archive.addFile(
      ArchiveFile.bytes('$markdownZipImageFolder/$name', bytes.data),
    );
    return packed[link] = '$markdownZipImageFolder/$name';
  }

  final rewritten = StringBuffer();
  var last = 0;
  for (final match in _imageLinks(markdown)) {
    final isHtml = match.namedGroup('src') == null;
    final src = isHtml ? match.namedGroup('html')! : match.namedGroup('src')!;
    final hash = src.indexOf('#');
    final link = hash < 0 ? src : src.substring(0, hash);
    final suffix = hash < 0 ? '' : src.substring(hash);
    final target = await pack(link);
    rewritten.write(markdown.substring(last, match.start));
    if (target == null) {
      rewritten.write(match[0]);
    } else {
      rewritten
        ..write(isHtml ? match[4] : match[1])
        ..write('$target$suffix')
        ..write(isHtml ? match[6] : match[3]);
    }
    last = match.end;
  }
  rewritten.write(markdown.substring(last));

  archive.addFile(
    ArchiveFile.bytes(
      '${_safeEntryName(fileName)}.md',
      utf8.encode(rewritten.toString()),
    ),
  );
  return ZipEncoder().encodeBytes(archive);
}

class _ImageBytes {
  const _ImageBytes(this.data, {this.mimeType});
  final Uint8List data;
  final String? mimeType;
}

Future<_ImageBytes?> _readImage(
  String link,
  String? imageDirectory,
  AssetBundle bundle,
) async {
  final uri = Uri.tryParse(link);
  if (uri == null || uri.scheme == 'http' || uri.scheme == 'https') {
    return null;
  }
  try {
    if (uri.scheme == 'data') {
      final data = uri.data;
      return data == null || !data.mimeType.startsWith('image/')
          ? null
          : _ImageBytes(data.contentAsBytes(), mimeType: data.mimeType);
    }
    // A note may come from someone else: never pack a file that is not a
    // picture, such as the library database next to the notes.
    final extension = uri.path.split('.').last.toLowerCase();
    if (!uri.path.contains('.') || !_imageExtensions.contains(extension)) {
      return null;
    }
    if (uri.scheme == 'resource') {
      final asset = await bundle.load(uri.path);
      return _ImageBytes(asset.buffer.asUint8List());
    }
    final file = await locateDocumentImage(uri, imageDirectory);
    if (file == null) return null;
    return _ImageBytes(await file.readAsBytes());
  } on Object {
    return null;
  }
}

const _imageExtensions = {
  'png',
  'jpg',
  'jpeg',
  'gif',
  'webp',
  'bmp',
  'heic',
  'heif',
  'svg',
  'tif',
  'tiff',
  'ico',
};

/// [name] with no folder separators or other characters a zip tool could
/// read as a path, so the note always lands at the top of the zip.
String _safeEntryName(String name) {
  final safe = name
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '-')
      .replaceAll(RegExp(r'^[\s.]+'), '')
      .trim();
  return safe.isEmpty ? 'note' : safe;
}

const _extensionsByMime = {
  'image/png': 'png',
  'image/jpeg': 'jpg',
  'image/gif': 'gif',
  'image/webp': 'webp',
  'image/svg+xml': 'svg',
  'image/heic': 'heic',
};

/// A file name for [link] that is safe in a zip and in a Markdown link.
String _imageName(String link, _ImageBytes bytes) {
  final mimeExtension = _extensionsByMime[bytes.mimeType];
  if (mimeExtension != null) return 'image.$mimeExtension';
  if (link.startsWith('data:')) return 'image';
  final path = Uri.tryParse(link)?.path ?? link;
  final base = Uri.decodeFull(path).split(RegExp(r'[\\/]')).last;
  final safe = base
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(RegExp(r'[^\p{L}\p{M}\p{N}_.\-]', unicode: true), '');
  return safe.isEmpty || safe.startsWith('.') ? 'image$safe' : safe;
}

String _uniqueName(String name, Set<String> used) {
  final dot = name.lastIndexOf('.');
  final stem = dot > 0 ? name.substring(0, dot) : name;
  final ext = dot > 0 ? name.substring(dot) : '';
  var candidate = name;
  for (var i = 1; !used.add(candidate.toLowerCase()); i++) {
    candidate = '$stem-$i$ext';
  }
  return candidate;
}
