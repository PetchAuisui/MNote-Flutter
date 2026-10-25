import 'package:mnote/l10n/language_preferences.dart';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

abstract interface class InkFileStorage {
  Future<bool> save({required String name, required Uint8List bytes});

  Future<Uint8List?> open();

  Future<bool> autoSave({required String name, required Uint8List bytes});

  Future<Uint8List?> autoLoad({required String name});

  /// Document names that have auto-saved ink.
  Future<List<String>> listNames();

  /// Removes all auto-saved ink.
  Future<void> deleteAll();
}

class DeviceInkFileStorage implements InkFileStorage {
  const DeviceInkFileStorage();

  @override
  Future<bool> save({required String name, required Uint8List bytes}) async {
    final uri = await FilePicker.saveFile(
      dialogTitle: LanguagePreferences.current().inkSaveDialogTitle,
      fileName: name,
      bytes: bytes,
      mimeType: 'application/json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    return uri != null;
  }

  @override
  Future<Uint8List?> open() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    return file?.readAsBytes();
  }

  @override
  Future<bool> autoSave({
    required String name,
    required Uint8List bytes,
  }) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}/$name.ink.json');
      await file.writeAsBytes(bytes, flush: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Uint8List?> autoLoad({required String name}) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}/$name.ink.json');
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (_) {}
    return null;
  }

  static const _suffix = '.ink.json';

  @override
  Future<List<String>> listNames() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      return [
        for (final file in Directory(appDir.path).listSync().whereType<File>())
          if (file.path.endsWith(_suffix))
            Uri.decodeComponent(
              file.uri.pathSegments.last,
            ).replaceFirst(_suffix, ''),
      ];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> deleteAll() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      for (final file in Directory(appDir.path).listSync().whereType<File>()) {
        if (file.path.endsWith(_suffix)) await file.delete();
      }
    } catch (_) {}
  }
}
