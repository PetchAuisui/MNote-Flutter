import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// A picture placed freely on the ink page, beneath the ink, so it can be
/// moved and resized and written over. Its file lives in the note's
/// `images/` folder like pictures in the Markdown.
@immutable
class InkPicture {
  const InkPicture({required this.id, required this.src, required this.rect});

  final String id;

  /// `images/<file>`, relative to the note's folder.
  final String src;

  /// Where the picture sits, in page coordinates.
  final Rect rect;

  /// Smallest side a picture can be shrunk to.
  static const minSide = 48.0;

  InkPicture copyWith({Rect? rect}) =>
      InkPicture(id: id, src: src, rect: rect ?? this.rect);

  Map<String, Object> toJson() => {
    'id': id,
    'src': src,
    'x': rect.left,
    'y': rect.top,
    'w': rect.width,
    'h': rect.height,
  };

  /// Reads a picture saved by [toJson], or throws [FormatException] when it
  /// is malformed, points outside `images/`, or lies outside the page.
  static InkPicture fromJson(
    Object? data, {
    required double pageWidth,
    required double pageHeight,
  }) {
    if (data is! Map) throw const FormatException('Invalid ink picture');
    final id = data['id'];
    final src = data['src'];
    final x = data['x'], y = data['y'], w = data['w'], h = data['h'];
    if (id is! String || id.isEmpty || src is! String || !isSafeSource(src)) {
      throw const FormatException('Invalid ink picture');
    }
    if (x is! num || y is! num || w is! num || h is! num) {
      throw const FormatException('Invalid ink picture');
    }
    final rect = Rect.fromLTWH(
      x.toDouble(),
      y.toDouble(),
      w.toDouble(),
      h.toDouble(),
    );
    if (!rect.isFinite ||
        rect.width < 1 ||
        rect.height < 1 ||
        rect.left < 0 ||
        rect.top < 0 ||
        rect.right > pageWidth + 0.5 ||
        rect.bottom > pageHeight + 0.5) {
      throw const FormatException('Invalid ink picture');
    }
    return InkPicture(id: id, src: src, rect: rect);
  }

  /// Only a direct child of `images/`, never a path that climbs out of it.
  static bool isSafeSource(String src) {
    if (!src.startsWith('images/')) return false;
    final file = src.substring('images/'.length);
    return file.isNotEmpty &&
        !file.contains('/') &&
        !file.contains(r'\') &&
        !file.contains('..');
  }

  /// [rect] scaled (keeping its shape) and moved as needed so it lies on a
  /// page [pageWidth] wide and [pageHeight] tall, with its shorter side at
  /// least [minSide] where the page allows.
  static Rect fitOnPage(Rect rect, double pageWidth, double pageHeight) {
    if (rect.width <= 0 || rect.height <= 0) {
      return Rect.fromLTWH(0, 0, minSide, minSide);
    }
    var scale = math.max(1.0, minSide / math.min(rect.width, rect.height));
    scale = math.min(
      scale,
      math.min(pageWidth / rect.width, pageHeight / rect.height),
    );
    final width = rect.width * scale;
    final height = rect.height * scale;
    final left = rect.left.clamp(0.0, math.max(0.0, pageWidth - width));
    final top = rect.top.clamp(0.0, math.max(0.0, pageHeight - height));
    return Rect.fromLTWH(left.toDouble(), top.toDouble(), width, height);
  }

  /// The `images/…` files the pictures in an encoded ink snapshot use, for
  /// keeping those files synced. Unreadable snapshots use none.
  static Set<String> sourcesIn(Object? inkJson) {
    if (inkJson is! Map) return const {};
    final pictures = inkJson['pictures'];
    if (pictures is! List) return const {};
    return {
      for (final p in pictures)
        if (p is Map && p['src'] is String && isSafeSource(p['src'] as String))
          p['src'] as String,
    };
  }
}
