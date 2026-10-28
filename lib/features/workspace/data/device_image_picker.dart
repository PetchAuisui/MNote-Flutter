import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:mnote/features/workspace/data/image_shrinker.dart';
import 'package:path_provider/path_provider.dart';

class MarkdownImageReference {
  const MarkdownImageReference({required this.alt, required this.uri});

  final String alt;
  final Uri uri;

  String get markdown => '![$alt](${uri.toString()})';
}

class DeviceImagePicker {
  const DeviceImagePicker();

  static const folder = 'images';

  /// Lets the user choose an image and copies it next to the document (into
  /// `images/`), returning a reference relative to [documentDirectory]. The
  /// picker's own copy lives in a temporary folder that the system clears and
  /// whose path changes between launches, so it must not be linked directly.
  /// Without a file-based [documentDirectory] the app documents folder is used.
  Future<MarkdownImageReference?> pick({Uri? documentDirectory}) async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Insert image',
      type: FileType.image,
    );
    if (file == null) return null;

    final base = documentDirectory?.scheme == 'file'
        ? Directory.fromUri(documentDirectory!)
        : await getApplicationDocumentsDirectory();
    return copyIntoDocument(
      directory: base,
      fileName: file.name,
      bytes: await file.readAsBytes(),
    );
  }

  /// Stores [bytes] as `images/<name>-<fingerprint>.<ext>` under [directory], renaming on a
  /// clash so an existing picture is never overwritten.
  static Future<MarkdownImageReference> copyIntoDocument({
    required Directory directory,
    required String fileName,
    required List<int> bytes,
  }) async {
    final dotIndex = fileName.lastIndexOf('.');
    final alt = dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
    var extension = dotIndex > 0 ? fileName.substring(dotIndex) : '';
    var data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    final shrunk = await ImageShrinker.shrink(data, extension);
    if (shrunk != null) {
      data = shrunk.bytes;
      extension = shrunk.extension;
    }
    final images = Directory('${directory.path}/$folder');
    await images.create(recursive: true);
    // The cloud keys pictures by file name, and two devices can both own an
    // IMG_0001.jpg, so the name carries a fingerprint of the picture itself.
    final name = _uniqueName(images, '$alt-${_fingerprint(data)}', extension);
    await File('${images.path}/$name').writeAsBytes(data);
    return MarkdownImageReference(
      alt: alt,
      uri: Uri(pathSegments: [folder, name]),
    );
  }

  /// FNV-1a over the bytes, as 8 hex digits.
  static String _fingerprint(List<int> bytes) {
    var hash = 0x811c9dc5;
    for (final byte in bytes) {
      hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static String _uniqueName(Directory directory, String stem, String ext) {
    var name = '$stem$ext';
    for (var n = 2; File('${directory.path}/$name').existsSync(); n++) {
      name = '$stem ($n)$ext';
    }
    return name;
  }
}
