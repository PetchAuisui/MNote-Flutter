import 'dart:convert';
import 'dart:typed_data';

/// A single-file note that carries both the Markdown and its ink, so a note
/// exported on one device opens complete on another.
class MnoteBundle {
  const MnoteBundle({required this.name, required this.markdown, this.ink});

  static const extension = 'mnote';
  static const _format = 'mnote-bundle';
  static const _version = 1;

  /// Document name, including its Markdown extension.
  final String name;
  final String markdown;

  /// An encoded `mnote-ink` snapshot, or null when the note has no ink.
  final String? ink;

  Uint8List encode() => Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'format': _format,
        'version': _version,
        'name': name,
        'markdown': markdown,
        'ink': ?(ink == null ? null : jsonDecode(ink!)),
      }),
    ),
  );

  /// Throws [FormatException] when [bytes] is not a supported bundle.
  factory MnoteBundle.decode(Uint8List bytes) {
    final Object? data;
    try {
      data = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw const FormatException('Not a Mnote file');
    }
    if (data is! Map<String, dynamic> ||
        data['format'] != _format ||
        data['version'] != _version ||
        data['name'] is! String ||
        data['markdown'] is! String) {
      throw const FormatException('Unsupported Mnote file');
    }
    final ink = data['ink'];
    if (ink != null && ink is! Map<String, dynamic>) {
      throw const FormatException('Unsupported ink in Mnote file');
    }
    return MnoteBundle(
      name: data['name'] as String,
      markdown: data['markdown'] as String,
      ink: ink == null ? null : jsonEncode(ink),
    );
  }
}
