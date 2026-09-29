import 'package:file_picker/file_picker.dart';

class MarkdownImageReference {
  const MarkdownImageReference({required this.alt, required this.uri});

  final String alt;
  final Uri uri;

  String get markdown => '![$alt](${uri.toString()})';
}

class DeviceImagePicker {
  const DeviceImagePicker();

  Future<MarkdownImageReference?> pick() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Insert image',
      type: FileType.image,
    );
    if (file == null) return null;

    final dotIndex = file.name.lastIndexOf('.');
    final alt = dotIndex > 0 ? file.name.substring(0, dotIndex) : file.name;
    return MarkdownImageReference(alt: alt, uri: file.uri);
  }
}
