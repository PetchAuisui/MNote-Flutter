import 'package:flutter/material.dart';
import 'package:mnote/app/mnote_app.dart';
import 'package:mnote/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's theme choices (accent color and light/dark/system mode)
/// so they are restored on the next launch, starting from the very first page.
abstract final class ThemePreferences {
  static const modeKey = 'theme_mode';
  static const accentKey = 'theme_accent';

  static bool _persisting = false;

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
    MnoteApp.themeModeNotifier.addListener(
      () => _save(modeKey, MnoteApp.themeModeNotifier.value.name),
    );
    MnoteApp.accentNotifier.addListener(
      () => _save(accentKey, MnoteApp.accentNotifier.value.name),
    );
  }

  static Future<void> _save(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (e) {
      debugPrint('Could not save theme preference "$key": $e');
    }
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
