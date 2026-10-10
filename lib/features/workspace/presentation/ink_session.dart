import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:scribble/scribble.dart';

import 'markdown_document_canvas.dart';

/// Coordinates belong to the page, never to Markdown blocks or the viewport.
class InkSession extends ChangeNotifier {
  static const pageWidth = DocumentPageMetrics.width;
  double height = DocumentPageMetrics.initialHeight;
  late final ScribbleNotifier pen = ScribbleNotifier(
    allowedPointersMode: ScribblePointerMode.penOnly,
    widths: const [3, 6, 12],
  )..addListener(_onPenChanged);
  final List<Color> colorPresets = [
    const Color(0xFF202124),
    const Color(0xFF275DAD),
    const Color(0xFFB3261E),
    const Color(0xFF237A3B),
    const Color(0xFF7B4BA0),
  ];
  final List<double> widthPresets = [3, 6, 12];

  /// Highlighter settings are kept apart from the pen's. Colours are stored
  /// opaque (so swatches read clearly); [highlightInk] applies the translucency.
  final List<Color> highlightPresets = [
    const Color(0xFFFFD54F),
    const Color(0xFF81C784),
    const Color(0xFFF48FB1),
    const Color(0xFF64B5F6),
    const Color(0xFFFFB74D),
  ];
  final List<double> highlightWidthPresets = [12, 18, 28];
  Color highlightColor = const Color(0xFFFFD54F);
  double highlightWidth = 18;

  static Color highlightInk(Color color) => color.withValues(alpha: 0.4);

  void setHighlightPreset(int index, Color color) {
    highlightPresets[index] = color;
    notifyListeners();
  }

  void setHighlightWidthPreset(int index, double width) {
    highlightWidthPresets[index] = width;
    notifyListeners();
  }

  void selectHighlight({Color? color, double? width}) {
    highlightColor = color ?? highlightColor;
    highlightWidth = width ?? highlightWidth;
    notifyListeners();
  }

  String _savedSketch = jsonEncode(const Sketch(lines: []).toJson());

  void setColorPreset(int index, Color color) {
    colorPresets[index] = color;
    notifyListeners();
  }

  void setWidthPreset(int index, double width) {
    widthPresets[index] = width;
    notifyListeners();
  }

  int _lineCount = 0;
  bool _straightening = false;

  void _onPenChanged() {
    if (!_straightening) _straightenFinishedHighlight();
    notifyListeners();
  }

  /// Highlighter strokes are translucent; snap each finished one to a clean
  /// straight segment (exactly horizontal/vertical when nearly so).
  void _straightenFinishedHighlight() {
    final lines = pen.currentSketch.lines;
    final added = lines.length == _lineCount + 1;
    _lineCount = lines.length;
    if (!added) return;
    final line = lines.last;
    if (line.points.length <= 2 || (line.color >> 24) & 0xFF == 0xFF) return;
    final first = line.points.first;
    final last = line.points.last;
    final dx = last.x - first.x;
    final dy = last.y - first.y;
    if (dx * dx + dy * dy < 16) return;
    var endY = last.y;
    var endX = last.x;
    // Within about 10 degrees of an axis: lock to it.
    if (dy.abs() < dx.abs() * 0.18) endY = first.y;
    if (dx.abs() < dy.abs() * 0.18) endX = first.x;
    final straight = line.copyWith(
      points: [
        first,
        last.copyWith(x: endX, y: endY),
      ],
    );
    _straightening = true;
    try {
      pen.setSketch(
        sketch: Sketch(
          lines: [...lines.sublist(0, lines.length - 1), straight],
        ),
        addToUndoHistory: false,
      );
    } finally {
      _straightening = false;
    }
  }

  bool get isDirty => jsonEncode(pen.currentSketch.toJson()) != _savedSketch;

  void grow(double value) {
    if (!value.isFinite || value <= height) return;
    height = value;
    notifyListeners();
  }

  String encode() => jsonEncode({
    'format': 'mnote-ink',
    'version': 1,
    'width': pageWidth,
    'height': height,
    'sketch': pen.currentSketch.toJson(),
  });

  void markSaved(String snapshot) {
    final data = jsonDecode(snapshot) as Map<String, dynamic>;
    _savedSketch = jsonEncode(data['sketch']);
    notifyListeners();
  }

  void load(String source) {
    final data = jsonDecode(source);
    if (data is! Map<String, dynamic> ||
        data['format'] != 'mnote-ink' ||
        data['version'] != 1 ||
        data['width'] != pageWidth ||
        data['height'] is! num) {
      throw const FormatException('Unsupported ink file');
    }
    final extent = (data['height'] as num).toDouble();
    if (!extent.isFinite || extent < 1400 || extent > 1000000) {
      throw const FormatException('Invalid page height');
    }
    final sketch = Sketch.fromJson(data['sketch'] as Map<String, dynamic>);
    for (final line in sketch.lines) {
      if (!line.width.isFinite || line.width <= 0 || line.width > 1000) {
        throw const FormatException('Invalid stroke width');
      }
      for (final point in line.points) {
        if (!point.x.isFinite ||
            !point.y.isFinite ||
            !point.pressure.isFinite ||
            point.pressure < 0 ||
            point.pressure > 1 ||
            point.x < 0 ||
            point.x > pageWidth ||
            point.y < 0 ||
            point.y > extent) {
          throw const FormatException('Invalid ink coordinates');
        }
      }
    }
    height = extent;
    pen.setSketch(sketch: sketch);
    _savedSketch = jsonEncode(sketch.toJson());
    notifyListeners();
  }

  @override
  void dispose() {
    pen.removeListener(notifyListeners);
    pen.dispose();
    super.dispose();
  }
}
