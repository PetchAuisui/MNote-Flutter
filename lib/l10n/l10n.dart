import 'package:flutter/widgets.dart';
import 'package:mnote/core/theme/app_theme.dart';
import 'package:mnote/l10n/app_localizations.dart';
import 'package:mnote/l10n/app_localizations_th.dart';

export 'package:mnote/l10n/app_localizations.dart';

/// The language the user picked in Settings.
enum AppLanguage {
  system(null),
  thai(Locale('th')),
  english(Locale('en'));

  const AppLanguage(this.locale);

  /// Null follows the device.
  final Locale? locale;
}

extension AppLocalizationsContext on BuildContext {
  /// The app's strings. Falls back to Thai (the default language) when the
  /// widget tree has no localizations, e.g. a bare widget in a test.
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      AppLocalizationsTh();
}

extension AppLocalizationsText on AppLocalizations {
  String accentLabel(AppAccent accent) => switch (accent) {
    AppAccent.blue => accentBlue,
    AppAccent.purple => accentPurple,
    AppAccent.green => accentGreen,
    AppAccent.red => accentRed,
    AppAccent.yellow => accentYellow,
    AppAccent.pink => accentPink,
    AppAccent.orange => accentOrange,
  };

  /// A short date: `5 มี.ค. 2569` (Buddhist year) in Thai, `Mar 5, 2026` in
  /// English.
  String shortDate(DateTime date) {
    const thMonths = [
      'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.', //
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
    ];
    const enMonths = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final d = date.toLocal();
    if (localeName == 'th') {
      return '${d.day} ${thMonths[d.month - 1]} ${d.year + 543}';
    }
    return '${enMonths[d.month - 1]} ${d.day}, ${d.year}';
  }

  /// How long ago [at] was, relative to [now].
  String timeAgo(DateTime at, DateTime now) {
    final diff = now.difference(at);
    if (diff.inSeconds < 60) return syncJustNow;
    if (diff.inMinutes < 60) return syncMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return syncHoursAgo(diff.inHours);
    return syncDaysAgo(diff.inDays);
  }
}
