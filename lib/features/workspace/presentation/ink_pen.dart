import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/painting.dart';
import 'package:scribble/scribble.dart';

/// A [ScribbleNotifier] whose eraser either rubs out only the part of a stroke
/// it passes over (splitting the stroke in two) or, with [eraseWholeStroke],
/// deletes every stroke it touches.
///
/// Whatever tool is selected, a stylus erases while it is flipped to its
/// eraser end or while its side button is held (S Pen, Surface Pen, Wacom…),
/// then goes straight back to the tool it had.
class InkPenNotifier extends ScribbleNotifier {
  InkPenNotifier({super.sketch, super.allowedPointersMode, super.widths});

  /// Radius of the eraser circle.
  static const eraserRadius = 12.0;

  /// Whether [event] comes from a stylus asking to erase: flipped over to its
  /// eraser end, or with its side button held.
  static bool wantsEraser(PointerEvent event) =>
      event.kind == PointerDeviceKind.invertedStylus ||
      (event.kind == PointerDeviceKind.stylus &&
          event.buttons & kPrimaryStylusButton != 0);

  /// The drawing state to return to once a stylus stops erasing on its own.
  Drawing? _resumeDrawing;

  /// Whether the eraser deletes a whole stroke on touch instead of only the
  /// part it covers.
  bool eraseWholeStroke = false;

  /// Where each active eraser pointer was last seen, so a fast swipe erases
  /// the whole path between two pointer events rather than skipping gaps.
  final Map<int, Offset> _eraserTrail = {};

  bool _erasingWith(PointerEvent event) =>
      value is Erasing && value.supportedPointerKinds.contains(event.kind);

  @override
  void onPointerDown(PointerDownEvent event) {
    final current = value;
    if (current is Drawing &&
        current.activePointerIds.isEmpty &&
        current.supportedPointerKinds.contains(event.kind) &&
        wantsEraser(event)) {
      _resumeDrawing = current;
      temporaryValue = ScribbleState.erasing(
        sketch: current.sketch,
        selectedWidth: eraserRadius,
        scaleFactor: current.scaleFactor,
        allowedPointersMode: current.allowedPointersMode,
      );
    }
    super.onPointerDown(event);
    if (!_erasingWith(event)) return;
    _eraserTrail[event.pointer] = event.localPosition;
    temporaryValue = _erase(event.localPosition, event.localPosition);
  }

  @override
  void onPointerUpdate(PointerMoveEvent event) {
    if (!_erasingWith(event) || !value.active) {
      super.onPointerUpdate(event);
      return;
    }
    final from = _eraserTrail[event.pointer] ?? event.localPosition;
    _eraserTrail[event.pointer] = event.localPosition;
    temporaryValue = _erase(from, event.localPosition).copyWith(
      pointerPosition: Point(event.localPosition.dx, event.localPosition.dy),
    );
  }

  @override
  void onPointerUp(PointerUpEvent event) => _endErase(event, () {
    super.onPointerUp(event);
  });

  @override
  void onPointerCancel(PointerCancelEvent event) => _endErase(event, () {
    super.onPointerCancel(event);
  });

  /// A stylus can leave without lifting (it hovers away, or the platform
  /// drops it), which must still finish the swipe and hand the pen back.
  @override
  void onPointerExit(PointerExitEvent event) {
    if (_resumeDrawing == null || value is! Erasing) {
      super.onPointerExit(event);
      return;
    }
    _endErase(event, () => super.onPointerExit(event));
  }

  void _endErase(PointerEvent event, void Function() fallback) {
    if (!_erasingWith(event)) {
      fallback();
      return;
    }
    final from = _eraserTrail.remove(event.pointer) ?? event.localPosition;
    final pos = event is PointerUpEvent && event.kind == PointerDeviceKind.mouse
        ? value.pointerPosition
        : null;
    // Assigning `value` (not `temporaryValue`) records one undo step for the
    // whole eraser swipe.
    value = _erase(from, event.localPosition).copyWith(
      pointerPosition: pos,
      activePointerIds: value.activePointerIds
          .where((id) => id != event.pointer)
          .toList(),
    );
    final resume = _resumeDrawing;
    if (resume != null && value.activePointerIds.isEmpty) {
      _resumeDrawing = null;
      // Undo only restores the sketch, so this never brings back the
      // temporary eraser.
      temporaryValue = resume.copyWith(
        sketch: value.sketch,
        activePointerIds: const [],
        pointerPosition: null,
        activeLine: null,
      );
    }
  }

  ScribbleState _erase(Offset from, Offset to) {
    final eraserRadius = value.selectedWidth / value.scaleFactor;
    final lines = <SketchLine>[];
    var changed = false;
    for (final line in value.sketch.lines) {
      final pieces = eraseFromLine(
        line,
        from,
        to,
        eraserRadius,
        wholeStroke: eraseWholeStroke,
      );
      if (pieces.length != 1 || !identical(pieces.first, line)) changed = true;
      lines.addAll(pieces);
    }
    if (!changed) return value;
    return value.copyWith.sketch(lines: lines);
  }

  /// The pieces of [line] left after an eraser of [radius] swept from [from]
  /// to [to]. Returns `[line]` itself when nothing was touched, and nothing
  /// at all when [wholeStroke] is set and the stroke was touched.
  ///
  /// The stroke is tested along its whole length, not just at its recorded
  /// points: a fast stroke's points can lie far apart, and the eraser must
  /// still cut the ink drawn between them. Each cut ends exactly at the edge
  /// of the eraser.
  static List<SketchLine> eraseFromLine(
    SketchLine line,
    Offset from,
    Offset to,
    double radius, {
    bool wholeStroke = false,
  }) {
    final points = line.points;
    if (points.isEmpty) return [line];
    final reach = radius + line.width / 2;
    // Nothing near the eraser's path can be touched.
    final sweep = Rect.fromPoints(from, to).inflate(reach);
    bool near(Point a, Point b) =>
        sweep.overlaps(Rect.fromPoints(Offset(a.x, a.y), Offset(b.x, b.y)));
    bool covered(Point p) =>
        _distanceToSegment(Offset(p.x, p.y), from, to) <= reach;
    // Samples along a segment are this far apart, so the eraser can't slip
    // between two of them.
    final step = math.max(0.5, reach / 4);

    final pieces = <List<Point>>[];
    var current = <Point>[];
    var inside = covered(points.first);
    var touched = inside;
    if (!inside) current.add(points.first);
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      if (!inside && !near(a, b)) {
        // Too far from the eraser for any of this segment to be covered.
        current.add(b);
        continue;
      }
      final length = math.sqrt(
        (b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y),
      );
      final steps = math.max(1, (length / step).ceil());
      for (var j = 1; j <= steps; j++) {
        final q = j == steps ? b : _lerp(a, b, j / steps);
        final qInside = covered(q);
        if (qInside == inside) {
          if (!inside && j == steps) current.add(b);
          continue;
        }
        if (qInside) {
          // The ink runs into the eraser: end this piece at the last sample
          // outside it.
          touched = true;
          if (j > 1) current.add(_lerp(a, b, (j - 1) / steps));
          pieces.add(current);
          current = <Point>[];
        } else {
          // The ink comes out of the eraser: a new piece starts here.
          current = <Point>[q];
        }
        inside = qInside;
      }
    }
    if (!touched) return [line];
    if (wholeStroke) return const [];
    pieces.add(current);
    final varied = points.any((p) => p.pressure != points.first.pressure);
    return [
      for (final piece in pieces)
        // A lone point left at a cut would show up as a stray dot.
        if (piece.length > 1)
          line.copyWith(points: varied ? _keepVaried(piece) : piece),
    ];
  }

  /// Scribble works out pressure from drawing speed when every point of a
  /// stroke has the same pressure. A piece cut from a stroke whose pressure
  /// varied (a real stylus, or a highlight kept at an even width) mustn't
  /// switch that on, so its first point is nudged apart from the rest.
  static List<Point> _keepVaried(List<Point> piece) {
    final first = piece.first.pressure;
    if (piece.any((p) => p.pressure != first)) return piece;
    final nudged = first >= 0.5 ? first - 0.0001 : first + 0.0001;
    return [
      Point(piece.first.x, piece.first.y, pressure: nudged),
      ...piece.skip(1),
    ];
  }

  static Point _lerp(Point a, Point b, double t) => Point(
    a.x + (b.x - a.x) * t,
    a.y + (b.y - a.y) * t,
    pressure: a.pressure + (b.pressure - a.pressure) * t,
  );

  static double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lengthSquared = ab.distanceSquared;
    if (lengthSquared == 0) return (p - a).distance;
    final t = (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / lengthSquared)
        .clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }
}
