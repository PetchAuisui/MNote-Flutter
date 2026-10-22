import 'package:flutter/material.dart';
import 'package:mnote/app/mnote_app.dart';
import 'package:mnote/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's theme choices (accent color and light/dark/system mode)
/// so they are restored on the next launch, starting from the very first page.
abstract final class ThemePreferences {
  static const modeKey = 'mnote_theme_mode';
  static const accentKey = 'theme_accent';

  static bool _persisting = false;
  static VoidCallback? _modeListener;
  static VoidCallback? _accentListener;
  static Future<void> _saveQueue = Future.value();

  /// Whether changes to the global notifiers are currently persisted.
  @visibleForTesting
  static bool get isPersisting => _persisting;

  /// Restores saved choices into the global notifiers, then starts saving any
  /// later change. Call once before `runApp` so the first frame already uses
  /// the saved colors. Never throws: on failure the defaults are kept.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      MnoteApp.themeModeNotifier.value = modeFromName(prefs.getString(modeKey));
      MnoteApp.accentNotifier.value = accentFromName(
        prefs.getString(accentKey),
      );
    } catch (e) {
      debugPrint('Could not load theme preferences: $e');
    }
    _startPersisting();
  }

  static void _startPersisting() {
    if (_persisting) return;
    _persisting = true;
    _modeListener = () =>
        _enqueueSave(modeKey, MnoteApp.themeModeNotifier.value.name);
    _accentListener = () =>
        _enqueueSave(accentKey, MnoteApp.accentNotifier.value.name);
    MnoteApp.themeModeNotifier.addListener(_modeListener!);
    MnoteApp.accentNotifier.addListener(_accentListener!);
  }

  /// Enqueues a preference write sequentially so rapid consecutive changes
  /// are guaranteed to complete in the order they were triggered.
  static Future<void> _enqueueSave(String key, String value) {
    final next = _saveQueue.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(key, value);
      } catch (e) {
        debugPrint('Could not save theme preference "$key": $e');
      }
    });
    _saveQueue = next;
    return next;
  }

  /// Waits for all pending save operations to complete.
  @visibleForTesting
  static Future<void> pendingSaves() => _saveQueue;

  /// Detaches listeners and resets persistence state between tests.
  @visibleForTesting
  static void resetForTesting() {
    if (_modeListener != null) {
      MnoteApp.themeModeNotifier.removeListener(_modeListener!);
      _modeListener = null;
    }
    if (_accentListener != null) {
      MnoteApp.accentNotifier.removeListener(_accentListener!);
      _accentListener = null;
    }
    _persisting = false;
    _saveQueue = Future.value();
  }

  /// Falls back to [ThemeMode.system] for missing or unknown values.
  static ThemeMode modeFromName(String? name) {
    for (final mode in ThemeMode.values) {
      if (mode.name == name) return mode;
    }
    return ThemeMode.system;
  }

  /// Falls back to [AppAccent.blue] for missing or unknown values.
  static AppAccent accentFromName(String? name) {
    for (final accent in AppAccent.values) {
      if (accent.name == name) return accent;
    }
    return AppAccent.blue;
  }
}
