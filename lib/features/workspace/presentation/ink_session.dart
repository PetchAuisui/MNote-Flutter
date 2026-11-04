import 'dart:math' as math;
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:scribble/scribble.dart';

import 'editor_settings.dart';
import 'ink_pen.dart';
import 'ink_picture.dart';
import 'ink_settings.dart';
import 'markdown_document_canvas.dart';
import 'markdown_document_style.dart';

/// Coordinates belong to the page, never to Markdown blocks or the viewport.
class InkSession extends ChangeNotifier {
  static const pageWidth = DocumentPageMetrics.width;
  double height = DocumentPageMetrics.initialHeight;
  late final InkPenNotifier pen = InkPenNotifier(
    allowedPointersMode: InkSettings.instance.fingerDrawing
        ? ScribblePointerMode.all
        : ScribblePointerMode.penOnly,
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

  /// Whether the eraser deletes whole strokes rather than only what it covers.
  bool get eraseWholeStroke => pen.eraseWholeStroke;

  void setEraseWholeStroke(bool whole) {
    if (pen.eraseWholeStroke == whole) return;
    pen.eraseWholeStroke = whole;
    notifyListeners();
  }

  static Color highlightInk(Color color) => color.withValues(alpha: 0.5);

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

  DocumentTextOptions? _layout;

  /// Whether anything has been drawn on the page.
  bool get hasInk => pen.currentSketch.lines.isNotEmpty;

  final List<InkPicture> _pictures = [];

  /// Pictures placed freely on the page, beneath the ink, bottom first.
  List<InkPicture> get pictures => List.unmodifiable(_pictures);

  /// The picture being moved or resized, if any.
  String? selectedPicture;

  /// Whether the picture tool is on: pictures can be moved and resized, and
  /// the pen is paused.
  bool movingPictures = false;

  void setMovingPictures(bool moving) {
    if (movingPictures == moving && (moving || selectedPicture == null)) {
      return;
    }
    movingPictures = moving;
    if (!moving) selectedPicture = null;
    notifyListeners();
  }

  /// The page point at the middle of what's on screen, set by the page that
  /// shows this session, so new pictures land where the person is looking.
  Offset Function()? visibleCenter;

  /// Whether the page has ink or pictures on it.
  bool get hasContent => hasInk || _pictures.isNotEmpty;

  int _pictureSerial = 0;

  /// Places the picture at [src] (natural size [size]) centred on [center],
  /// shrunk to at most half the page width, and selects it.
  InkPicture addPicture(
    String src, {
    required Size size,
    required Offset center,
  }) {
    final scale = size.width > pageWidth / 2 ? pageWidth / 2 / size.width : 1.0;
    final width = math.max(InkPicture.minSide, size.width * scale);
    final height = math.max(InkPicture.minSide, size.height * scale);
    final picture = InkPicture(
      id: '${DateTime.now().microsecondsSinceEpoch}-${_pictureSerial++}',
      src: src,
      rect: () {
        final rect = Rect.fromCenter(
          center: center,
          width: width,
          height: height,
        );
        return InkPicture.fitOnPage(
          rect,
          pageWidth,
          math.max(this.height, rect.bottom),
        );
      }(),
    );
    _pictures.add(picture);
    selectedPicture = picture.id;
    grow(picture.rect.bottom);
    notifyListeners();
    return picture;
  }

  /// Moves or resizes a picture, keeping it on the page.
  void placePicture(String id, Rect rect) {
    final i = _pictures.indexWhere((p) => p.id == id);
    if (i < 0) return;
    _pictures[i] = _pictures[i].copyWith(
      rect: InkPicture.fitOnPage(rect, pageWidth, height),
    );
    notifyListeners();
  }

  void removePicture(String id) {
    _pictures.removeWhere((p) => p.id == id);
    if (selectedPicture == id) selectedPicture = null;
    notifyListeners();
  }

  void selectPicture(String? id) {
    if (selectedPicture == id) return;
    selectedPicture = id;
    notifyListeners();
  }

  /// How the page text must be laid out under this ink. Ink is drawn at fixed
  /// positions, so once a page has ink its text keeps the size, line height
  /// and font it had when the first stroke was drawn, whatever the editor
  /// settings say now. Ink saved before layouts existed used the defaults.
  /// A page without ink follows [preferred].
  DocumentTextOptions layoutFor(DocumentTextOptions preferred) =>
      hasInk ? (_layout ?? const DocumentTextOptions()) : preferred;

  void _syncLayoutLock() {
    if (hasInk) {
      _layout ??= EditorSettings.instance.textOptions;
    } else {
      _layout = null;
    }
  }

  static DocumentTextOptions? _decodeLayout(Object? data) {
    if (data is! Map) return null;
    final size = data['size'];
    final lineHeight = data['lineHeight'];
    final font = data['font'];
    if (size is! num ||
        lineHeight is! num ||
        !size.isFinite ||
        !lineHeight.isFinite) {
      return null;
    }
    final known = EditorFont.values.any((f) => f.familyName == font);
    return DocumentTextOptions(
      bodySize: size.toDouble().clamp(
        EditorSettings.minFontSize,
        EditorSettings.maxFontSize,
      ),
      lineHeight: lineHeight.toDouble().clamp(
        EditorSettings.minLineHeight,
        EditorSettings.maxLineHeight,
      ),
      fontFamily: known ? font as String? : null,
    );
  }

  String _saved = _savedState(const Sketch(lines: []).toJson(), const []);

  static String _savedState(Object? sketch, Object? pictures) =>
      jsonEncode({'sketch': sketch, 'pictures': pictures ?? const []});

  List<Map<String, Object>> get _picturesJson => [
    for (final p in _pictures) p.toJson(),
  ];

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
    _syncLayoutLock();
    if (!_straightening) _straightenFinishedHighlight();
    notifyListeners();
  }

  /// Highlighter strokes are translucent and free-form. Keep the path as
  /// drawn but give it a constant thickness: scribble simulates pressure from
  /// drawing speed when every point has the same pressure, which makes strokes
  /// and dots uneven. A pressure difference too small to see switches that
  /// simulation off.
  void _straightenFinishedHighlight() {
    final lines = pen.currentSketch.lines;
    final added = lines.length == _lineCount + 1;
    _lineCount = lines.length;
    if (!added) return;
    final line = lines.last;
    if (line.points.isEmpty || (line.color >> 24) & 0xFF == 0xFF) return;
    final first = line.points.first;
    final last = line.points.last;
    final List<Point> points;
    if (line.points.length == 1 ||
        (line.points.length == 2 &&
            (last.x - first.x) * (last.x - first.x) +
                    (last.y - first.y) * (last.y - first.y) <
                16)) {
      // A tap: a zero-length stroke renders as a dot as wide as the line.
      points = [
        Point(first.x, first.y),
        Point(first.x + 0.01, first.y, pressure: 0.5001),
      ];
    } else {
      if (line.points.skip(1).every((p) => p.pressure == 0.5001) &&
          first.pressure == 0.5) {
        return;
      }
      points = [
        Point(first.x, first.y),
        for (final p in line.points.skip(1)) Point(p.x, p.y, pressure: 0.5001),
      ];
    }
    final straight = line.copyWith(points: points);
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

  bool get isDirty =>
      _savedState(pen.currentSketch.toJson(), _picturesJson) != _saved;

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
    if (_pictures.isNotEmpty) 'pictures': _picturesJson,
    if (hasInk && _layout != null)
      'layout': {
        'size': _layout!.bodySize,
        'lineHeight': _layout!.lineHeight,
        'font': _layout!.fontFamily,
      },
  });

  void markSaved(String snapshot) {
    final data = jsonDecode(snapshot) as Map<String, dynamic>;
    _saved = _savedState(data['sketch'], data['pictures']);
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
    final pictures = data['pictures'];
    if (pictures != null && pictures is! List) {
      throw const FormatException('Invalid ink pictures');
    }
    final loadedPictures = [
      for (final p in (pictures as List?) ?? const [])
        InkPicture.fromJson(p, pageWidth: pageWidth, pageHeight: extent),
    ];
    height = extent;
    pen.setSketch(sketch: sketch);
    _pictures
      ..clear()
      ..addAll(loadedPictures);
    selectedPicture = null;
    _layout = sketch.lines.isEmpty
        ? null
        : _decodeLayout(data['layout']) ?? const DocumentTextOptions();
    _saved = _savedState(sketch.toJson(), _picturesJson);
    notifyListeners();
  }

  @override
  void dispose() {
    pen.removeListener(notifyListeners);
    pen.dispose();
    super.dispose();
  }
}
