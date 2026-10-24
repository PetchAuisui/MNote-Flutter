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

  @override
  String noteImported(String name) {
    return 'Imported \"$name\"';
  }

  @override
  String noteImportFailed(String error) {
    return 'Could not import the file: $error';
  }

  @override
  String defaultDocName(int n) {
    return 'Document_$n';
  }

  @override
  String defaultTextName(int n) {
    return 'Text_$n';
  }

  @override
  String get newMarkdownTitle => 'New Markdown file';

  @override
  String get newTextTitle => 'New text file (.txt)';

  @override
  String get fileNameLabel => 'File name';

  @override
  String get createFile => 'Create file';

  @override
  String newMarkdownBody(String name) {
    return '# $name\n\nStart typing or jot down your notes here...';
  }

  @override
  String newTextBody(String name) {
    return 'Text note $name\n\n';
  }

  @override
  String get newFolderTitle => 'New folder';

  @override
  String get folderNameLabel => 'Folder name';

  @override
  String get folderNameHint => 'e.g. Seminar, Notes';

  @override
  String get create => 'Create';

  @override
  String folderCreated(String name) {
    return 'Folder \"$name\" created';
  }

  @override
  String get trashedDocTitle => 'This note is in the trash';

  @override
  String trashedDocBody(String name) {
    return 'Restore \"$name\" to open it?';
  }

  @override
  String get restoreAndOpen => 'Restore and open';

  @override
  String get unsyncedTitle => 'Some notes are not synced';

  @override
  String unsyncedBody(int count) {
    return '$count notes are not in the cloud. Signing out will permanently delete them from this device.';
  }

  @override
  String get signOutAndDelete => 'Sign out and delete';

  @override
  String get syncModeAuto => 'Sync';

  @override
  String get syncModeNever => 'Don\'t sync';

  @override
  String syncModeTitle(String name) {
    return 'Sync for \"$name\"';
  }

  @override
  String get syncModeAutoDesc =>
      'Upload to your account and receive edits from other devices';

  @override
  String get syncModeNeverDesc =>
      'Do not upload, and do not receive edits from other devices';

  @override
  String get undo => 'Undo';

  @override
  String folderTrashed(String name) {
    return 'Folder \"$name\" moved to the trash';
  }

  @override
  String folderRestored(String name) {
    return 'Folder \"$name\" restored';
  }

  @override
  String get deleteFolderTitle => 'Delete folder permanently?';

  @override
  String deleteFolderBody(String name) {
    return 'Delete the folder \"$name\" and everything in it permanently?\nThis cannot be undone.';
  }

  @override
  String get deleteForeverBtn => 'Delete permanently';

  @override
  String folderDeleted(String name) {
    return 'Folder \"$name\" deleted permanently';
  }

  @override
  String get renameDocTitle => 'Rename note';

  @override
  String get docNameLabel => 'Note name';

  @override
  String get docNameHint => 'Enter a new note name';

  @override
  String get docNameRequired => 'Please enter a note name';

  @override
  String docRenamed(String name) {
    return 'Note renamed to \"$name\"';
  }

  @override
  String get noFoldersToMove =>
      'There are no folders to move the note to. Create a folder first.';

  @override
  String get moveDocTitle => 'Move note to...';

  @override
  String get moveToHome => 'Home (top level)';

  @override
  String get homeName => 'Home';

  @override
  String get folderFallback => 'Folder';

  @override
  String docMoved(String name, String dest) {
    return 'Moved \"$name\" to \"$dest\"';
  }

  @override
  String get renameFolderTitle => 'Rename folder';

  @override
  String get folderNameNewHint => 'Enter a new folder name';

  @override
  String get folderNameRequired => 'Please enter a folder name';

  @override
  String folderRenamed(String name) {
    return 'Folder renamed to \"$name\"';
  }

  @override
  String docTrashed(String name) {
    return '\"$name\" moved to the trash';
  }

  @override
  String docRestored(String name) {
    return '\"$name\" restored';
  }

  @override
  String get deleteDocTitle => 'Delete note permanently?';

  @override
  String deleteDocBody(String name) {
    return 'Delete \"$name\" permanently?\nThis cannot be undone.';
  }

  @override
  String docDeleted(String name) {
    return '\"$name\" deleted permanently';
  }

  @override
  String get emptyTrashTitle => 'Empty the trash?';

  @override
  String get emptyTrashBody =>
      'Everything in the trash will be deleted permanently and cannot be recovered.';

  @override
  String get emptyTrash => 'Empty trash';

  @override
  String get trashEmptied => 'Trash emptied';

  @override
  String get trashedFolderTitle => 'This folder is in the trash';

  @override
  String trashedFolderBody(String name) {
    return 'Restore the folder \"$name\"?';
  }

  @override
  String get restore => 'Restore';

  @override
  String get searchHint => 'Search notes or folders...';

  @override
  String get trash => 'Trash';

  @override
  String get closeSearch => 'Close search';

  @override
  String get search => 'Search';

  @override
  String get settingsTooltip => 'Settings';

  @override
  String get filterAll => 'All';

  @override
  String get filterStarred => 'Starred (favorites)';

  @override
  String get filterStarredShort => 'Starred';

  @override
  String get filterFolders => 'Folders';

  @override
  String get filterAllDocs => 'All notes';

  @override
  String get openFolder => 'Open folder';

  @override
  String get renameFolder => 'Rename folder';

  @override
  String get folderColor => 'Change folder color';

  @override
  String get unfavorite => 'Remove from favorites';

  @override
  String get favorite => 'Add to favorites';

  @override
  String get moveToTrash => 'Move to trash';

  @override
  String get openDoc => 'Open note';

  @override
  String get renameDoc => 'Rename';

  @override
  String get moveToFolder => 'Move to folder';

  @override
  String get export => 'Export';

  @override
  String get syncSettingsMenu => 'Sync settings';

  @override
  String get listView => 'List view';

  @override
  String get gridView => 'Grid view';

  @override
  String get sortBy => 'Sort by';

  @override
  String get sortNewest => 'Recently edited';

  @override
  String get sortOldest => 'Oldest';

  @override
  String get sortNameAsc => 'Name (A–Z)';

  @override
  String get sortNameDesc => 'Name (Z–A)';

  @override
  String get createOrImport => 'Create or import';

  @override
  String get newMarkdownItem => 'New Markdown note (.md)';

  @override
  String get newTextItem => 'New text file (.txt)';

  @override
  String get newFolderItem => 'New folder';

  @override
  String get importItem => 'Import a file from this device';

  @override
  String get newButton => 'New';

  @override
  String fileCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$_temp0';
  }

  @override
  String get folderOptions => 'Folder options';

  @override
  String get docOptions => 'Note options';

  @override
  String get emptyDoc => 'Empty note';

  @override
  String get textTypeName => 'TXT text';

  @override
  String get trashEmptyTitle => 'The trash is empty';

  @override
  String get trashEmptyBody => 'There are no notes or folders in the trash';

  @override
  String get emptyLibraryTitle => 'No notes or folders yet';

  @override
  String get emptyLibraryBody =>
      'Tap \"+ New\" above to create a Markdown note, a TXT file or a folder';

  @override
  String get folderColorTitle => 'Change folder color';

  @override
  String get defaultColor => 'Default color';

  @override
  String get folderColorLabel => 'Folder color';

  @override
  String get badgeSynced => 'Synced';

  @override
  String get badgePending => 'Waiting to sync';

  @override
  String get badgeOffSyncOff => 'Sync is off';

  @override
  String get badgeOffNever => 'This note is set not to sync';

  @override
  String get badgeOffTooBig =>
      'This note is larger than 900 KB, so it is not synced';
}
