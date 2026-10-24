import 'package:flutter/foundation.dart';
import 'package:mnote/features/workspace/presentation/markdown_document_style.dart';
import 'package:mnote/features/workspace/presentation/workspace_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fonts offered for typing; all are bundled with the app.
enum EditorFont {
  app('ตามแอป', null),
  sarabun('Sarabun', 'Sarabun'),
  kanit('Kanit', 'Kanit'),
  notoSansThai('Noto Sans', 'Noto Sans Thai');

  const EditorFont(this.label, this.familyName);

  final String label;

  /// Google Fonts family, or null to keep the app font.
  final String? familyName;
}

/// How the typing view looks, and how new notes open. Saved on this device.
///
/// These only change the typing view. The writing view and exports keep the
/// fixed page metrics, so ink always stays where it was drawn.
class EditorSettings extends ChangeNotifier {
  EditorSettings({
    this._fontSize = defaultFontSize,
    this._lineHeight = defaultLineHeight,
    this._font = EditorFont.app,
    this._openMode = WorkspaceMode.ink,
  });

  /// The settings the app uses; restored once at startup.
  static final EditorSettings instance = EditorSettings();

  static const defaultFontSize = MarkdownDocumentStyle.bodySize;
  static const defaultLineHeight = MarkdownDocumentStyle.lineHeight;
  static const minFontSize = 14.0;
  static const maxFontSize = 26.0;
  static const minLineHeight = 1.3;
  static const maxLineHeight = 2.0;

  static const fontSizeKey = 'mnote_editor_font_size';
  static const lineHeightKey = 'mnote_editor_line_height';
  static const fontKey = 'mnote_editor_font';
  static const openModeKey = 'mnote_editor_open_mode';

  double _fontSize;
  double _lineHeight;
  EditorFont _font;
  WorkspaceMode _openMode;

  double get fontSize => _fontSize;
  double get lineHeight => _lineHeight;
  EditorFont get font => _font;

  /// Mode a note opens in: [WorkspaceMode.ink] (writing) or
  /// [WorkspaceMode.split] (typing).
  WorkspaceMode get openMode => _openMode;

  DocumentTextOptions get textOptions => DocumentTextOptions(
    bodySize: _fontSize,
    lineHeight: _lineHeight,
    fontFamily: _font.familyName,
  );

  bool get isDefaultLook =>
      _fontSize == defaultFontSize &&
      _lineHeight == defaultLineHeight &&
      _font == EditorFont.app;

  set fontSize(double value) {
    final v = value.clamp(minFontSize, maxFontSize).toDouble();
    if (v == _fontSize) return;
    _fontSize = v;
    _changed((p) => p.setDouble(fontSizeKey, v));
  }

  set lineHeight(double value) {
    final v = value.clamp(minLineHeight, maxLineHeight).toDouble();
    if (v == _lineHeight) return;
    _lineHeight = v;
    _changed((p) => p.setDouble(lineHeightKey, v));
  }

  set font(EditorFont value) {
    if (value == _font) return;
    _font = value;
    _changed((p) => p.setString(fontKey, value.name));
  }

  set openMode(WorkspaceMode value) {
    final mode = value == WorkspaceMode.split
        ? WorkspaceMode.split
        : WorkspaceMode.ink;
    if (mode == _openMode) return;
    _openMode = mode;
    _changed((p) => p.setString(openModeKey, mode.name));
  }

  /// Puts the font, size and line height back to the defaults.
  void resetLook() {
    fontSize = defaultFontSize;
    lineHeight = defaultLineHeight;
    font = EditorFont.app;
  }

  /// Restores saved choices into this object. Never throws: defaults are kept
  /// on failure.
  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _fontSize = (prefs.getDouble(fontSizeKey) ?? defaultFontSize)
          .clamp(minFontSize, maxFontSize)
          .toDouble();
      _lineHeight = (prefs.getDouble(lineHeightKey) ?? defaultLineHeight)
          .clamp(minLineHeight, maxLineHeight)
          .toDouble();
      final fontName = prefs.getString(fontKey);
      _font = EditorFont.values.firstWhere(
        (f) => f.name == fontName,
        orElse: () => EditorFont.app,
      );
      _openMode = prefs.getString(openModeKey) == WorkspaceMode.split.name
          ? WorkspaceMode.split
          : WorkspaceMode.ink;
      notifyListeners();
    } catch (e) {
      debugPrint('Could not load editor settings: $e');
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
      debugPrint('Could not save editor settings: $e');
    }
  }
}
