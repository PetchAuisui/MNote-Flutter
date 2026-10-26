import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mnote/models/note_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The user's global cloud-sync choices, saved on this device.
class SyncSettings extends ChangeNotifier {
  SyncSettings({
    this._enabled = true,
    this._syncInk = true,
    this._wifiOnly = false,
  });

  static const enabledKey = 'mnote_sync_enabled';
  static const inkKey = 'mnote_sync_ink';
  static const wifiOnlyKey = 'mnote_sync_wifi_only';

  /// Firestore documents hold at most 1 MiB; leave room for the other fields.
  /// Larger documents and ink are never synced.
  static const hardLimitBytes = 900 * 1024;

  bool _enabled;
  bool _syncInk;
  bool _wifiOnly;

  /// Master switch. When off nothing is uploaded or downloaded.
  bool get enabled => _enabled;

  bool get syncInk => _syncInk;

  /// When on, nothing syncs over mobile data.
  bool get wifiOnly => _wifiOnly;

  set enabled(bool value) => _update(() => _enabled = value, enabledKey, value);

  set syncInk(bool value) => _update(() => _syncInk = value, inkKey, value);

  set wifiOnly(bool value) =>
      _update(() => _wifiOnly = value, wifiOnlyKey, value);

  /// Restores saved choices. Never throws: defaults are kept on failure.
  static Future<SyncSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return SyncSettings(
        enabled: prefs.getBool(enabledKey) ?? true,
        syncInk: prefs.getBool(inkKey) ?? true,
        wifiOnly: prefs.getBool(wifiOnlyKey) ?? false,
      );
    } catch (e) {
      debugPrint('Could not load sync settings: $e');
      return SyncSettings();
    }
  }

  /// Whether [doc] may be uploaded and updated from the cloud.
  bool allows(DocumentItem doc) {
    if (!_enabled || doc.syncMode == SyncMode.never) return false;
    return fits(doc.content, hardLimitBytes);
  }

  /// Whether ink of [bytes] for [mode] may be synced.
  bool allowsInk(SyncMode mode, int bytes) {
    if (!_enabled || !_syncInk || mode == SyncMode.never) return false;
    return bytes <= hardLimitBytes;
  }

  /// UTF-8 size check that avoids encoding unless the answer is unclear.
  static bool fits(String content, int limit) {
    // A UTF-16 unit is 1-3 UTF-8 bytes.
    if (content.length * 3 <= limit) return true;
    if (content.length > limit) return false;
    return utf8.encode(content).length <= limit;
  }

  void _update(VoidCallback apply, String key, bool value) {
    apply();
    notifyListeners();
    _save(key, value);
  }

  Future<void> _save(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (e) {
      debugPrint('Could not save sync settings: $e');
    }
  }
}
