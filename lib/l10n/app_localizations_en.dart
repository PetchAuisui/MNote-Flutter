// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get close => 'Close';

  @override
  String get done => 'Done';

  @override
  String get reset => 'Reset to default';

  @override
  String get followDevice => 'Device';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get accentTitle => 'App color (Accent)';

  @override
  String accentName(String color) {
    return '$color';
  }

  @override
  String get accentBlue => 'Blue';

  @override
  String get accentPurple => 'Purple';

  @override
  String get accentGreen => 'Green';

  @override
  String get accentRed => 'Red';

  @override
  String get accentYellow => 'Yellow';

  @override
  String get accentPink => 'Pink';

  @override
  String get accentOrange => 'Orange';

  @override
  String get themeTitle => 'Appearance (Theme)';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeHintSystem =>
      'Default: follows your device\'s light or dark mode';

  @override
  String get themeHintDark => 'Dark mode is on';

  @override
  String get themeHintLight => 'Light mode is on';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageSystem => 'Device';

  @override
  String get languageThai => 'ไทย';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageHint =>
      'If your device uses a language the app does not support, it is shown in Thai';

  @override
  String get accountTitle => 'Account';

  @override
  String get noName => 'No name';

  @override
  String get signOut => 'Sign out';

  @override
  String get displayNameLabel => 'Display name';

  @override
  String get editName => 'Edit name';

  @override
  String memberSince(String date) {
    return 'Member since $date';
  }

  @override
  String get changePasswordByEmail => 'Change password by email';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get providerGoogle => 'Signed in with Google';

  @override
  String get providerEmail => 'Signed in with email';

  @override
  String get providerMnote => 'Mnote account';

  @override
  String get nameSaved => 'Name saved';

  @override
  String resetLinkSentTo(String email) {
    return 'Password reset link sent to $email';
  }

  @override
  String deleteAccountBody(String email) {
    return 'The account $email and all your files in the cloud will be permanently deleted. Files on this device are deleted too, and this cannot be undone.';
  }

  @override
  String get deleteEnterPassword => 'Enter your password to confirm';

  @override
  String get deleteGoogleReauth =>
      'You will be asked to confirm with Google again';

  @override
  String get deleteForever => 'Delete permanently';

  @override
  String get syncTitle => 'Cloud sync';

  @override
  String get syncFiles => 'Sync notes to your account';

  @override
  String get syncFilesOffHint => 'When off, notes stay on this device only';

  @override
  String get syncInk => 'Sync pen ink';

  @override
  String get syncWifiOnly => 'Sync on Wi-Fi only';

  @override
  String get syncWifiOnlyHint => 'Do not use mobile data to sync';

  @override
  String get syncFailed => 'Sync failed. Check your connection and try again.';

  @override
  String get syncNotYet => 'Not synced yet this session';

  @override
  String get syncJustNow => 'just now';

  @override
  String syncMinutesAgo(int n) {
    return '$n min ago';
  }

  @override
  String syncHoursAgo(int n) {
    return '$n h ago';
  }

  @override
  String syncDaysAgo(int n) {
    return '$n d ago';
  }

  @override
  String syncLast(String ago) {
    return 'Last synced: $ago';
  }

  @override
  String get syncOff => 'Sync is off';

  @override
  String get syncNow => 'Sync now';

  @override
  String get editorTitle => 'Editor';

  @override
  String get editorOpenIn => 'Open notes in';

  @override
  String get tabWrite => 'Write';

  @override
  String get tabMarkdown => 'Markdown';

  @override
  String get editorFont => 'Text font';

  @override
  String get fontApp => 'App font';

  @override
  String get editorFontSize => 'Font size';

  @override
  String get editorLineHeight => 'Line spacing';

  @override
  String get editorSample => 'Sample text The quick brown fox';

  @override
  String get editorNote =>
      'Applies to the Write and Markdown tabs. Notes that already have ink keep their size so the ink always lines up with the text.';

  @override
  String get inkTitle => 'Pen (Ink)';

  @override
  String get inkFinger => 'Draw with a finger';

  @override
  String get inkFingerHint =>
      'Off: only a pen or Apple Pencil draws, and a finger scrolls the page';

  @override
  String get login => 'Sign in';

  @override
  String get register => 'Sign up';

  @override
  String get registerNew => 'Create an account';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get noAccountRegister => 'No account yet? Sign up';

  @override
  String get haveAccountLogin => 'Already have an account? Sign in';

  @override
  String get registerWithGoogle => 'Sign up with Google';

  @override
  String get orDivider => 'or';

  @override
  String get enterEmailFirst => 'Enter your email first to reset your password';

  @override
  String get resetLinkSent => 'Password reset link sent to your email';

  @override
  String get loginSuccess => 'Signed in';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get enterPassword => 'Please enter your password';

  @override
  String get enterEmail => 'Please enter your email';

  @override
  String get invalidEmail => 'The email format is not valid';

  @override
  String passwordTooShort(int min) {
    return 'The password must be at least $min characters';
  }

  @override
  String get enterName => 'Please enter your name';

  @override
  String get enterConfirmPassword => 'Please confirm your password';

  @override
  String get passwordMismatch => 'The passwords do not match';

  @override
  String get errWrongCredentials => 'The email or password is incorrect';

  @override
  String get errUserDisabled => 'This account has been disabled';

  @override
  String get errEmailInUse => 'This email is already in use';

  @override
  String get errWeakPassword => 'The password is too weak';

  @override
  String get errTooManyRequests => 'Too many attempts. Please wait a moment.';

  @override
  String get errNetwork => 'Cannot connect to the internet';

  @override
  String get errCancelled => 'Sign-in cancelled';

  @override
  String get errGoogleConfig =>
      'Google sign-in is unavailable right now. Please try again later.';

  @override
  String get errUnknown => 'Something went wrong. Please try again.';
}
