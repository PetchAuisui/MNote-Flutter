import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mnote/features/workspace/data/image_shrinker.dart';

Uint8List noisyJpeg(int width, int height, {int? orientation}) {
  final random = Random(1);
  final image = img.Image(width: width, height: height);
  for (final pixel in image) {
    pixel.setRgb(random.nextInt(256), random.nextInt(256), random.nextInt(256));
  }
  if (orientation != null) image.exif.imageIfd.orientation = orientation;
  return img.encodeJpg(image, quality: 95);
}

void main() {
  test('keeps a small picture exactly as it is', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final result = await ImageShrinker.shrink(bytes, '.jpg');
    expect(result!.bytes, bytes);
    expect(result.extension, '.jpg');
  });

  test('scales a large picture down to the longest side limit', () async {
    final source = noisyJpeg(2000, 1000);
    expect(source.length, greaterThan(ImageShrinker.keepBytes));

    final result = await ImageShrinker.shrink(source, '.jpg');
    final decoded = img.decodeJpg(result!.bytes)!;

    expect(decoded.width, ImageShrinker.maxSide);
    expect(decoded.height, 800);
    expect(result.bytes.length, lessThan(source.length));
  });

  test('applies the EXIF rotation to the pixels', () async {
    final source = noisyJpeg(1000, 600, orientation: 6);
    expect(source.length, greaterThan(ImageShrinker.keepBytes));

    final result = await ImageShrinker.shrink(source, '.jpg');
    final decoded = img.decodeJpg(result!.bytes)!;

    expect(decoded.height, greaterThan(decoded.width));
  });

  test('leaves something that is not a picture alone', () async {
    final bytes = Uint8List.fromList(
      List.filled(ImageShrinker.keepBytes + 1, 7),
    );
    final result = await ImageShrinker.shrink(bytes, '.jpg');
    expect(result!.bytes, bytes);
  });
}
