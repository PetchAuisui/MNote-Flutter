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

      expect(ref.markdown, '![IMG_0111](images/IMG_0111.jpeg)');
      expect(File('${dir.path}/images/IMG_0111.jpeg').readAsBytesSync(), [
        1,
        2,
        3,
      ]);
    },
  );

  test('never overwrites an existing image and encodes spaces', () async {
    await DeviceImagePicker.copyIntoDocument(
      directory: dir,
      fileName: 'my photo.png',
      bytes: [1],
    );
    final second = await DeviceImagePicker.copyIntoDocument(
      directory: dir,
      fileName: 'my photo.png',
      bytes: [2],
    );

    expect(second.markdown, '![my photo](images/my%20photo%20(2).png)');
    expect(File('${dir.path}/images/my photo.png').readAsBytesSync(), [1]);
    expect(File('${dir.path}/images/my photo (2).png').readAsBytesSync(), [2]);
  });
}
