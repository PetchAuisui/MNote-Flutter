import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether a finger can draw, saved on this device. The pen's color and width
/// are chosen in each note's toolbar, so they are not repeated here.
class InkSettings extends ChangeNotifier {
  InkSettings({this._fingerDrawing = false});

  /// The settings the app uses; restored once at startup.
  static final InkSettings instance = InkSettings();

  static const fingerDrawingKey = 'mnote_ink_finger_drawing';

  bool _fingerDrawing;

  /// When off, only a pen or stylus draws and a finger scrolls the page.
  bool get fingerDrawing => _fingerDrawing;

  set fingerDrawing(bool value) {
    if (value == _fingerDrawing) return;
    _fingerDrawing = value;
    notifyListeners();
    _save(value);
  }

  /// Restores the saved choice. Never throws: the default is kept on failure.
  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _fingerDrawing = prefs.getBool(fingerDrawingKey) ?? false;
      notifyListeners();
    } catch (e) {
      debugPrint('Could not load ink settings: $e');
    }
  }

  Future<void> _save(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(fingerDrawingKey, value);
    } catch (e) {
      debugPrint('Could not save ink settings: $e');
    }
  }
}
