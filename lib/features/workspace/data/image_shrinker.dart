import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// A picture after [ImageShrinker.shrink]; [extension] includes the dot.
class ShrunkImage {
  const ShrunkImage(this.bytes, this.extension);

  final Uint8List bytes;
  final String extension;
}

/// Scales photos down so notes stay light to store and sync.
class ImageShrinker {
  const ImageShrinker._();

  /// Pictures at or below this size are kept exactly as they are.
  static const keepBytes = 400 * 1024;
  static const maxSide = 1600;
  static const _quality = 80;

  /// Returns [bytes] unchanged when small or not decodable, otherwise a
  /// downscaled copy (JPEG, or PNG when it has transparency).
  static Future<ShrunkImage?> shrink(Uint8List bytes, String extension) async {
    if (bytes.length <= keepBytes) return ShrunkImage(bytes, extension);
    try {
      return await compute(_shrink, (bytes, extension));
    } catch (e) {
      debugPrint('Could not shrink picture: $e');
      return null;
    }
  }

  static ShrunkImage _shrink((Uint8List, String) input) {
    final (bytes, extension) = input;
    final decoded = img.decodeImage(bytes);
    // Animated pictures and unknown formats are left alone.
    if (decoded == null || decoded.numFrames > 1) {
      return ShrunkImage(bytes, extension);
    }
    final longest = decoded.width > decoded.height
        ? decoded.width
        : decoded.height;
    final scaled = longest <= maxSide
        ? decoded
        : img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? maxSide : null,
            height: decoded.height > decoded.width ? maxSide : null,
            interpolation: img.Interpolation.average,
          );
    final keepAlpha = decoded.hasAlpha;
    final encoded = keepAlpha
        ? img.encodePng(scaled)
        : img.encodeJpg(scaled, quality: _quality);
    if (encoded.length >= bytes.length) return ShrunkImage(bytes, extension);
    return ShrunkImage(encoded, keepAlpha ? '.png' : '.jpg');
  }
}
