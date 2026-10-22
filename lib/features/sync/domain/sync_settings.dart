import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mnote/models/note_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The user's global cloud-sync choices, saved on this device.
class SyncSettings extends ChangeNotifier {
  SyncSettings({
    this._enabled = true,
    this._syncInk = true,
    int maxContentBytes = hardLimitBytes,
  }) : _maxContentBytes = maxContentBytes.clamp(1, hardLimitBytes);

  static const enabledKey = 'mnote_sync_enabled';
  static const inkKey = 'mnote_sync_ink';
  static const maxBytesKey = 'mnote_sync_max_bytes';

  /// Firestore documents hold at most 1 MiB; leave room for the other fields.
  static const hardLimitBytes = 900 * 1024;

  /// Limits offered in the settings dialog.
  static const limitChoices = [
    50 * 1024,
    100 * 1024,
    250 * 1024,
    500 * 1024,
    hardLimitBytes,
  ];

  bool _enabled;
  bool _syncInk;
  int _maxContentBytes;

  /// Master switch. When off nothing is uploaded or downloaded.
  bool get enabled => _enabled;

  bool get syncInk => _syncInk;

  /// Largest document (or ink) synced automatically.
  int get maxContentBytes => _maxContentBytes;

  set enabled(bool value) => _update(() => _enabled = value, enabledKey, value);

  set syncInk(bool value) => _update(() => _syncInk = value, inkKey, value);

  set maxContentBytes(int value) {
    final clamped = value.clamp(1, hardLimitBytes);
    _update(() => _maxContentBytes = clamped, maxBytesKey, clamped);
  }

  /// Restores saved choices. Never throws: defaults are kept on failure.
  static Future<SyncSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return SyncSettings(
        enabled: prefs.getBool(enabledKey) ?? true,
        syncInk: prefs.getBool(inkKey) ?? true,
        maxContentBytes: prefs.getInt(maxBytesKey) ?? hardLimitBytes,
      );
    } catch (e) {
      debugPrint('Could not load sync settings: $e');
      return SyncSettings();
    }
  }

  /// Whether [doc] may be uploaded and updated from the cloud.
  bool allows(DocumentItem doc) {
    if (!_enabled) return false;
    return switch (doc.syncMode) {
      SyncMode.never => false,
      SyncMode.always => fits(doc.content, hardLimitBytes),
      SyncMode.auto => fits(doc.content, _maxContentBytes),
    };
  }

  /// Whether ink of [bytes] for [mode] may be synced.
  bool allowsInk(SyncMode mode, int bytes) {
    if (!_enabled || !_syncInk || mode == SyncMode.never) return false;
    return bytes <=
        (mode == SyncMode.always ? hardLimitBytes : _maxContentBytes);
  }

  /// UTF-8 size check that avoids encoding unless the answer is unclear.
  static bool fits(String content, int limit) {
    // A UTF-16 unit is 1-3 UTF-8 bytes.
    if (content.length * 3 <= limit) return true;
    if (content.length > limit) return false;
    return utf8.encode(content).length <= limit;
  }

  void _update(VoidCallback apply, String key, Object value) {
    apply();
    notifyListeners();
    _save(key, value);
  }

  Future<void> _save(String key, Object value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      }
    } catch (e) {
      debugPrint('Could not save sync settings: $e');
    }
  }
}
