import 'package:flutter/gestures.dart';
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
  static List<SketchLine> eraseFromLine(
    SketchLine line,
    Offset from,
    Offset to,
    double radius, {
    bool wholeStroke = false,
  }) {
    final reach = radius + line.width / 2;
    final pieces = <List<Point>>[];
    var current = <Point>[];
    var touched = false;
    for (final p in line.points) {
      if (_distanceToSegment(Offset(p.x, p.y), from, to) <= reach) {
        touched = true;
        if (current.isNotEmpty) pieces.add(current);
        current = <Point>[];
      } else {
        current.add(p);
      }
    }
    if (!touched) return [line];
    if (wholeStroke) return const [];
    if (current.isNotEmpty) pieces.add(current);
    return [
      for (final points in pieces)
        // A lone point left at a cut would show up as a stray dot.
        if (points.length > 1) line.copyWith(points: points),
    ];
  }

  static double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lengthSquared = ab.distanceSquared;
    if (lengthSquared == 0) return (p - a).distance;
    final t = (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / lengthSquared)
        .clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }
}
