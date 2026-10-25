import 'package:flutter/foundation.dart';
import 'package:mnote/app/mnote_app.dart';
import 'package:mnote/l10n/app_localizations_en.dart';
import 'package:mnote/l10n/app_localizations_th.dart';
import 'package:mnote/l10n/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Saves the language the user picked so it is restored on the next launch.
abstract final class LanguagePreferences {
  static const key = 'mnote_language';

  /// Restores the saved language into [MnoteApp.languageNotifier]. Never
  /// throws: on failure the app follows the device.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      MnoteApp.languageNotifier.value = fromName(prefs.getString(key));
    } catch (e) {
      debugPrint('Could not load the language: $e');
    }
  }

  /// Applies [language] right away and saves it.
  static Future<void> set(AppLanguage language) async {
    MnoteApp.languageNotifier.value = language;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, language.name);
    } catch (e) {
      debugPrint('Could not save the language: $e');
    }
  }

  /// The strings for the language in use right now, for code that has no
  /// [BuildContext]. Thai when the language is unsupported.
  static AppLocalizations current() {
    final locale =
        MnoteApp.languageNotifier.value.locale ??
        PlatformDispatcher.instance.locale;
    return locale.languageCode == 'en'
        ? AppLocalizationsEn()
        : AppLocalizationsTh();
  }

  static AppLanguage fromName(String? name) {
    for (final language in AppLanguage.values) {
      if (language.name == name) return language;
    }
    return AppLanguage.system;
  }
}
