import 'dart:convert';
import 'dart:io';

import 'package:mnote/features/workspace/data/ink_file_storage.dart';
import 'package:mnote/features/workspace/presentation/ink_picture.dart';
import 'package:path_provider/path_provider.dart';

/// Which `images/…` files each note's ink page uses, for keeping them synced.
///
/// An ink file is read again only when it has changed since the last look,
/// so a sync pass doesn't reread and decode every note's ink.
class InkPictureIndex {
  InkPictureIndex({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _directory;
  final _seen =
      <String, ({DateTime modified, int size, Set<String> sources})>{};

  Future<Set<String>> sourcesFor(String name) async {
    try {
      final file = DeviceInkFileStorage.fileIn(await _directory(), name);
      final stat = await file.stat();
      if (stat.type == FileSystemEntityType.notFound) {
        _seen.remove(name);
        return const {};
      }
      final known = _seen[name];
      if (known != null &&
          known.modified == stat.modified &&
          known.size == stat.size) {
        return known.sources;
      }
      final text = await file.readAsString();
      // Most ink has no pictures; skip decoding it.
      final sources = text.contains('"pictures"')
          ? InkPicture.sourcesIn(jsonDecode(text))
          : const <String>{};
      _seen[name] = (
        modified: stat.modified,
        size: stat.size,
        sources: sources,
      );
      return sources;
    } on Object {
      return const {};
    }
  }
}
