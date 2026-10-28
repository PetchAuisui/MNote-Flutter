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

  @override
  String get aboutTitle => 'About';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get aboutLicenses => 'Open-source licenses';

  @override
  String get aboutFeedback => 'Report a problem or send feedback';

  @override
  String get aboutFeedbackHint => 'Opens GitHub Issues in your browser';

  @override
  String get aboutSource => 'Source code on GitHub';

  @override
  String get aboutOpenFailed => 'Could not open the link';

  @override
  String get wsOpened => 'Note opened';

  @override
  String get wsNotMnoteFile =>
      'This file is not a Mnote note that can be opened';

  @override
  String get wsMnoteSaveFailed => 'Could not save the opened note';

  @override
  String get wsSaved => 'Note saved';

  @override
  String get phHeading => 'Heading';

  @override
  String get phItem => 'Item';

  @override
  String get phData => 'Data';

  @override
  String get phBold => 'bold text';

  @override
  String get phItalic => 'italic text';

  @override
  String get phLinkName => 'link name';

  @override
  String get phStrike => 'strikethrough text';

  @override
  String get phTask => 'Task';

  @override
  String get phQuote => 'Quote';

  @override
  String get tableInsertTitle => 'Insert table';

  @override
  String get tableColumns => 'Number of columns';

  @override
  String get tableRows => 'Number of data rows';

  @override
  String get insert => 'Insert';

  @override
  String get openFileFailed => 'Could not open the file. Please try again.';

  @override
  String get imageSaveFailed => 'Could not save the image next to this note';

  @override
  String get trashQuestionTitle => 'Move to trash?';

  @override
  String get trashFailed => 'Could not move the note to the trash';

  @override
  String get linkOpenFailed => 'Could not open this link';

  @override
  String get editDocName => 'Edit note name';

  @override
  String get aiAssistant => 'AI assistant';

  @override
  String get moreActions => 'More actions';

  @override
  String get newDocMenu => 'New note';

  @override
  String get openOtherDoc => 'Open another note';

  @override
  String get openMnote => 'Open Mnote note (.mnote)';

  @override
  String get insertFromFile => 'Insert content from a file';

  @override
  String get saveAs => 'Save as';

  @override
  String get statusBusy => 'Working…';

  @override
  String get statusUnsaved => 'Not saved yet';

  @override
  String get statusExample => 'Sample note · ready to edit';

  @override
  String get statusSaved => 'Saved';

  @override
  String get clearInkTitle => 'Clear all ink?';

  @override
  String get clearInkBody => 'You can undo after clearing';

  @override
  String get clearAll => 'Clear all';

  @override
  String get lineNumberOne => 'Line number 1';

  @override
  String wsMnoteOpened(String name) {
    return 'Opened note $name';
  }

  @override
  String phHeadingN(int n) {
    return 'Heading $n';
  }

  @override
  String insertedFrom(String name) {
    return 'Inserted content from $name';
  }

  @override
  String trashQuestionBody(String name) {
    return 'Move \"$name\" to the trash?';
  }

  @override
  String statsLive(int lines, int chars) {
    return 'Live preview · $lines lines · $chars characters';
  }

  @override
  String statsPlain(int lines, int chars) {
    return '$lines lines · $chars characters';
  }

  @override
  String lineNumbers(int count) {
    return 'Line numbers 1 to $count';
  }

  @override
  String get exportSaveDialogTitle => 'Save exported file';

  @override
  String get fmtTxt => 'Plain text (.txt)';

  @override
  String get fmtPng => 'Image (.png)';

  @override
  String get fmtMnote => 'Mnote note (.mnote)';

  @override
  String get fmtPdf => 'PDF document (.pdf)';

  @override
  String get back => 'Back';

  @override
  String get exportTitle => 'Export note';

  @override
  String get pdfSubtitle => 'Includes the content, text and ink strokes';

  @override
  String get mnoteSubtitle =>
      'Markdown and ink in one file that you can open on another device';

  @override
  String get mdSubtitle => 'The original Markdown text file';

  @override
  String get txtSubtitle => 'Content only, without Markdown symbols';

  @override
  String get pngSubtitle => 'A high-resolution snapshot of the page and ink';

  @override
  String get mnoteInfo =>
      'This file keeps both the Markdown text and the ink strokes. Opened with Mnote on another device, you get the complete note.';

  @override
  String get saveFile => 'Save file';

  @override
  String get shareFile => 'Share file';

  @override
  String get includeInkLayer => 'Include pen ink (ink layer)';

  @override
  String get inkOnPdf => 'Renders ink and highlights onto the PDF';

  @override
  String get pdfTextOnly => 'Exports plain text only (no ink strokes)';

  @override
  String get pageSize => 'Page size';

  @override
  String get pageContinuousDesc => 'Continuous (one long page)';

  @override
  String get pageA4 => 'Standard A4 size';

  @override
  String get continuous => 'Continuous';

  @override
  String get savePdf => 'Save PDF file';

  @override
  String get sharePdf => 'Share PDF file';

  @override
  String get includeInk => 'Include pen ink';

  @override
  String get snapshotWithInk => 'A snapshot that includes all ink strokes';

  @override
  String get textOnlyDoc => 'Document text only';

  @override
  String get savePng => 'Save image (.png)';

  @override
  String get shareImage => 'Share image';

  @override
  String get exportMdAll => 'Exports all of the original Markdown code';

  @override
  String get exportPlain => 'Strips Markdown symbols and leaves plain text';

  @override
  String get needDocForImage =>
      'Open the note page to capture a high-resolution image';

  @override
  String get exportFailed => 'Could not export the file. Please try again.';

  @override
  String exportShareText(String name) {
    return 'Sharing $name';
  }

  @override
  String exportAs(String format) {
    return 'Export as $format';
  }

  @override
  String exportDone(String name) {
    return 'Exported $name';
  }

  @override
  String get tbBold => 'Bold';

  @override
  String get tbItalic => 'Italic';

  @override
  String get tbStrike => 'Strikethrough';

  @override
  String get tbBullets => 'Bulleted list';

  @override
  String get tbNumbered => 'Numbered list';

  @override
  String get tbTasks => 'Task list';

  @override
  String get tbIndent => 'Indent as sub-item';

  @override
  String get tbOutdent => 'Back to main list';

  @override
  String get tbQuote => 'Quote';

  @override
  String get tbLineBreak => 'Line break';

  @override
  String get tbLineBreakTip => 'Insert a new line with <br>';

  @override
  String get tbRule => 'Divider';

  @override
  String get tbRuleTip => 'Insert a horizontal rule with ---';

  @override
  String get tbTable => 'Table';

  @override
  String get tbCode => 'Code';

  @override
  String get tbInlineCode => 'Inline code';

  @override
  String get tbCodeBlock => 'Code block';

  @override
  String get tbDiagram => 'Diagram';

  @override
  String get tbImportMmd => 'Import from a .mmd file…';

  @override
  String get tbLink => 'Link';

  @override
  String get tbImage => 'Image';

  @override
  String get tbMore => 'More tools';

  @override
  String get inkUndo => 'Undo ink';

  @override
  String get inkRedo => 'Redo ink';

  @override
  String get inkGroupDraw => 'Drawing tools';

  @override
  String get inkPen => 'Pen';

  @override
  String get inkHighlighter => 'Highlighter';

  @override
  String get inkEraser => 'Stroke eraser';

  @override
  String get inkGroupStroke => 'Stroke style';

  @override
  String get inkChangeColor => 'Change the selected color';

  @override
  String get inkGroupPage => 'Page controls';

  @override
  String get inkFingerOn => 'Drawing with a finger';

  @override
  String get inkPencilOnly => 'Apple Pencil draws · finger scrolls';

  @override
  String get inkFitWidth => 'Fit to width';

  @override
  String get inkGroupManage => 'Ink actions';

  @override
  String get inkMore => 'More';

  @override
  String get inkClearAll => 'Clear all ink';

  @override
  String get inkCustomColor => 'Custom color';

  @override
  String get inkHue => 'Hue';

  @override
  String get inkSaturation => 'Saturation';

  @override
  String get inkBrightness => 'Brightness';

  @override
  String get ok => 'OK';

  @override
  String get inkCustomWidth => 'Custom stroke width';

  @override
  String get inkColorTip =>
      'Tap to choose · tap again or long-press to change this color';

  @override
  String get guideTitle => 'Mnote guide';

  @override
  String get guideSkip => 'Skip';

  @override
  String get guidePrev => 'Previous page';

  @override
  String get guideNext => 'Next page';

  @override
  String get guideStart => 'Enter Mnote';

  @override
  String get guide1Title => 'Write and format Markdown';

  @override
  String get guide1Body =>
      'Write notes quickly with Markdown syntax: headings, to-do lists, bold and italic, with a quick toolbar for instant formatting.';

  @override
  String get guide2Title => 'Draw and take notes with a pen';

  @override
  String get guide2Body =>
      'Write, highlight text and sketch freely on your notes with an accurate digital ink system (Ink & Stylus), complete with an eraser and plenty of colors.';

  @override
  String get guide3Title => 'Create Mermaid diagrams fast';

  @override
  String get guide3Body =>
      'Turn Mermaid code into flowcharts and clean diagrams, with a live preview alongside your writing.';

  @override
  String inkWidthTip(String width) {
    return 'Width $width · tap again or long-press to edit';
  }

  @override
  String guideStep(String step) {
    return 'Step $step / 03';
  }

  @override
  String get redo => 'Redo';

  @override
  String get tplFlowLabel => 'Flowchart';

  @override
  String get tplFlowStart => 'Start';

  @override
  String get tplFlowStep => 'Step';

  @override
  String get tplFlowCond => 'Condition?';

  @override
  String get tplYes => 'Yes';

  @override
  String get tplEnd => 'End';

  @override
  String get tplNo => 'No';

  @override
  String get tplSeqLabel => 'Sequence';

  @override
  String get tplUser => 'User';

  @override
  String get tplSystem => 'System';

  @override
  String get tplRequest => 'Send request';

  @override
  String get tplReply => 'Reply';

  @override
  String get tplClassLabel => 'Class';

  @override
  String get tplHas => 'has';

  @override
  String get mmdOnlyMmd => 'Only .mmd or .mermaid files are supported';

  @override
  String get mmdNotUtf8 => 'Cannot read the file. It must be UTF-8 text.';

  @override
  String get mmdEmpty => 'The file is empty and has no diagram code';

  @override
  String get copyCode => 'Copy code';

  @override
  String get viewCode => 'View code';

  @override
  String get codeCopied => 'Copied. You can paste it into your note.';

  @override
  String get diagramEmpty => 'Empty diagram';

  @override
  String get diagramUnsupported => 'This platform cannot display diagrams yet';

  @override
  String get diagramFailed => 'Could not display the diagram';

  @override
  String get diagramTimeout => 'Timed out while displaying the diagram';

  @override
  String get docNotUtf8 => 'This file is not UTF-8 text that Mnote supports';

  @override
  String get fileActionFailed =>
      'Could not do that with this file. Please try again.';

  @override
  String get inkSaveDialogTitle => 'Save ink separately from Markdown';

  @override
  String mmdTooBig(int kb) {
    return 'The file is too large (max $kb KB)';
  }

  @override
  String docListFailed(String error) {
    return 'Could not load the note list: $error';
  }

  @override
  String get aiCloseLabel => 'Close the AI assistant';

  @override
  String get aiSuggest1 => 'Explain Markdown in simple terms';

  @override
  String get aiSuggest2 => 'Draw a flowchart of the sign-up steps';

  @override
  String get aiSuggest3 => 'Help me think of headings for lesson summary notes';

  @override
  String get aiClearChat => 'Clear conversation';

  @override
  String get aiPrivacyNote =>
      'What you type is sent to Google Gemini for processing · The AI has not read your note';

  @override
  String get aiHint => 'Ask anything…';

  @override
  String get aiSend => 'Send';

  @override
  String get aiStart => 'Start chatting with the AI assistant';

  @override
  String get aiThinking => 'Thinking…';

  @override
  String get aiTabImage => 'Diagram';

  @override
  String get aiCopied => 'Copied';

  @override
  String get aiNoAnswer =>
      'The AI did not send an answer. Try asking again or rephrase your question.';

  @override
  String get aiFailed => 'The AI could not answer. Please try again.';

  @override
  String get aiQuota =>
      'You have used up the AI assistant quota. Wait a moment and try again. If it still fails, today\'s quota is used up; try again tomorrow.';

  @override
  String get aiUnavailable =>
      'The AI assistant is temporarily unavailable. Please try again later.';

  @override
  String get aiAppCheck =>
      'App security verification failed, so the AI assistant cannot be used right now.';

  @override
  String get aiConnect =>
      'Could not connect to the AI assistant. Check your internet connection and try again.';

  @override
  String aiTooLong(int max) {
    return 'The message is too long (max $max characters)';
  }

  @override
  String get aiPrivacyWithNote =>
      'What you type and the attached note are sent to Google Gemini for processing';

  @override
  String aiNoteChip(String title) {
    return 'AI will read: $title';
  }

  @override
  String get aiNoteRemove => 'Don\'t attach the note';

  @override
  String get aiNoteAttach => 'Attach this note';

  @override
  String aiNoteLabel(String title) {
    return 'Attached: $title';
  }

  @override
  String get aiNoteTooLong =>
      'The note is too long for the AI assistant. Tap x on the note name to send without it.';

  @override
  String get aiDisclaimer =>
      'Gemini is an AI and can make mistakes. Check important information.';

  @override
  String get startWriting => 'Start writing Markdown…';

  @override
  String get firebaseSetupError =>
      'Could not connect to Firebase.\nPlease set up Firebase as described in docs/firebase-setup.md';

  @override
  String get outlineTitle => 'Outline';

  @override
  String get outlineEmpty => 'No headings yet. Start a line with # to add one.';

  @override
  String get outlineUntitled => '(Untitled heading)';
}
