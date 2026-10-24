import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How the pen starts when a note is opened, and whether a finger can draw.
/// Saved on this device. Changes made in a note's own toolbar are not saved
/// here; they last until the note is closed.
class InkSettings extends ChangeNotifier {
  InkSettings({
    this._penColor = defaultPenColor,
    this._penWidth = defaultPenWidth,
    this._highlightColor = defaultHighlightColor,
    this._fingerDrawing = false,
  });

  /// The settings the app uses; restored once at startup.
  static final InkSettings instance = InkSettings();

  static const penColors = [
    Color(0xFF202124),
    Color(0xFF275DAD),
    Color(0xFFB3261E),
    Color(0xFF237A3B),
    Color(0xFF7B4BA0),
  ];
  static const penWidths = [3.0, 6.0, 12.0];

  /// Opaque; the highlighter adds its own translucency.
  static const highlightColors = [
    Color(0xFFFFD54F),
    Color(0xFF81C784),
    Color(0xFFF48FB1),
    Color(0xFF64B5F6),
    Color(0xFFFFB74D),
  ];

  static const defaultPenColor = Color(0xFF202124);
  static const defaultPenWidth = 3.0;
  static const defaultHighlightColor = Color(0xFFFFD54F);

  static const penColorKey = 'mnote_ink_pen_color';
  static const penWidthKey = 'mnote_ink_pen_width';
  static const highlightColorKey = 'mnote_ink_highlight_color';
  static const fingerDrawingKey = 'mnote_ink_finger_drawing';

  Color _penColor;
  double _penWidth;
  Color _highlightColor;
  bool _fingerDrawing;

  Color get penColor => _penColor;
  double get penWidth => _penWidth;
  Color get highlightColor => _highlightColor;

  /// When off, only a pen or stylus draws and a finger scrolls the page.
  bool get fingerDrawing => _fingerDrawing;

  bool get isDefault =>
      _penColor == defaultPenColor &&
      _penWidth == defaultPenWidth &&
      _highlightColor == defaultHighlightColor &&
      !_fingerDrawing;

  set penColor(Color value) {
    if (!penColors.contains(value) || value == _penColor) return;
    _penColor = value;
    _changed((p) => p.setInt(penColorKey, value.toARGB32()));
  }

  set penWidth(double value) {
    if (!penWidths.contains(value) || value == _penWidth) return;
    _penWidth = value;
    _changed((p) => p.setDouble(penWidthKey, value));
  }

  set highlightColor(Color value) {
    if (!highlightColors.contains(value) || value == _highlightColor) return;
    _highlightColor = value;
    _changed((p) => p.setInt(highlightColorKey, value.toARGB32()));
  }

  set fingerDrawing(bool value) {
    if (value == _fingerDrawing) return;
    _fingerDrawing = value;
    _changed((p) => p.setBool(fingerDrawingKey, value));
  }

  void reset() {
    penColor = defaultPenColor;
    penWidth = defaultPenWidth;
    highlightColor = defaultHighlightColor;
    fingerDrawing = false;
  }

  /// Restores saved choices. Never throws: defaults are kept on failure, and
  /// a saved value that is no longer on offer is ignored.
  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      Color? pick(String key, List<Color> options) {
        final saved = prefs.getInt(key);
        if (saved == null) return null;
        for (final c in options) {
          if (c.toARGB32() == saved) return c;
        }
        return null;
      }

      _penColor = pick(penColorKey, penColors) ?? defaultPenColor;
      _highlightColor =
          pick(highlightColorKey, highlightColors) ?? defaultHighlightColor;
      final width = prefs.getDouble(penWidthKey);
      _penWidth = penWidths.contains(width) ? width! : defaultPenWidth;
      _fingerDrawing = prefs.getBool(fingerDrawingKey) ?? false;
      notifyListeners();
    } catch (e) {
      debugPrint('Could not load ink settings: $e');
    }
  }

  void _changed(Future<bool> Function(SharedPreferences prefs) save) {
    notifyListeners();
    _save(save);
  }

  Future<void> _save(Future<bool> Function(SharedPreferences) save) async {
    try {
      await save(await SharedPreferences.getInstance());
    } catch (e) {
      debugPrint('Could not save ink settings: $e');
    }
  }
}
