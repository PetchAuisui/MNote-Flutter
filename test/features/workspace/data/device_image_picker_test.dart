import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/workspace/data/device_image_picker.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('mnote_img'));
  tearDown(() => dir.deleteSync(recursive: true));

  test(
    'copies the image beside the document and links it relatively',
    () async {
      final ref = await DeviceImagePicker.copyIntoDocument(
        directory: dir,
        fileName: 'IMG_0111.jpeg',
        bytes: [1, 2, 3],
      );

      expect(
        ref.markdown,
        matches(r'^!\[IMG_0111\]\(images/IMG_0111-[0-9a-f]{8}\.jpeg\)$'),
      );
      expect(File('${dir.path}/${ref.uri.path}').readAsBytesSync(), [1, 2, 3]);
    },
  );

  test('never overwrites an existing image and encodes spaces', () async {
    final first = await DeviceImagePicker.copyIntoDocument(
      directory: dir,
      fileName: 'my photo.png',
      bytes: [1],
    );
    final again = await DeviceImagePicker.copyIntoDocument(
      directory: dir,
      fileName: 'my photo.png',
      bytes: [1],
    );

    expect(first.markdown, contains('images/my%20photo-'));
    expect(again.markdown, contains('%20(2).png'));
    expect(
      File('${dir.path}/${Uri.decodeFull(first.uri.path)}').readAsBytesSync(),
      [1],
    );
    expect(
      File('${dir.path}/${Uri.decodeFull(again.uri.path)}').readAsBytesSync(),
      [1],
    );
  });

  test(
    'different pictures with the same file name get different names',
    () async {
      final a = await DeviceImagePicker.copyIntoDocument(
        directory: dir,
        fileName: 'IMG_0001.jpg',
        bytes: [1, 1],
      );
      final b = await DeviceImagePicker.copyIntoDocument(
        directory: dir,
        fileName: 'IMG_0001.jpg',
        bytes: [2, 2],
      );

      expect(a.uri.path, isNot(b.uri.path));
    },
  );
}
