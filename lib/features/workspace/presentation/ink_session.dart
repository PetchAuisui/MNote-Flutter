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
  )..addListener(notifyListeners);
  final List<Color> colorPresets = [
    const Color(0xFF202124),
    const Color(0xFF275DAD),
    const Color(0xFFB3261E),
    const Color(0xFF237A3B),
    const Color(0xFF7B4BA0),
  ];
  final List<double> widthPresets = [3, 6, 12];
  String _savedSketch = jsonEncode(const Sketch(lines: []).toJson());

  void setColorPreset(int index, Color color) {
    colorPresets[index] = color;
    notifyListeners();
  }

  void setWidthPreset(int index, double width) {
    widthPresets[index] = width;
    notifyListeners();
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
