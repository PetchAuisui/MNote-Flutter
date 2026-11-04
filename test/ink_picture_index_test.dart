import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/workspace/data/ink_file_storage.dart';
import 'package:mnote/features/workspace/data/ink_picture_index.dart';

void main() {
  test('finds the pictures an ink page uses and notices changes', () async {
    final dir = await Directory.systemTemp.createTemp('ink-index');
    addTearDown(() => dir.delete(recursive: true));
    final index = InkPictureIndex(directory: () async => dir);
    final file = DeviceInkFileStorage.fileIn(dir, 'notes.md');

    expect(await index.sourcesFor('notes.md'), isEmpty);

    await file.writeAsString(
      jsonEncode({
        'format': 'mnote-ink',
        'pictures': [
          {'id': 'a', 'src': 'images/cat.png', 'x': 0, 'y': 0, 'w': 9, 'h': 9},
          {'id': 'b', 'src': '../escape.png', 'x': 0, 'y': 0, 'w': 9, 'h': 9},
        ],
      }),
    );
    expect(await index.sourcesFor('notes.md'), {'images/cat.png'});

    await file.writeAsString(jsonEncode({'format': 'mnote-ink', 'sketch': {}}));
    expect(await index.sourcesFor('notes.md'), isEmpty);

    await file.delete();
    expect(await index.sourcesFor('notes.md'), isEmpty);
  });
}
