import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnote/app/mnote_app.dart';
import 'package:mnote/l10n/l10n.dart';
import 'package:mnote/models/note_item.dart';
import 'package:mnote/screens/note_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  tearDown(() => MnoteApp.languageNotifier.value = AppLanguage.system);

  Future<FakeDocumentRepository> pump(
    WidgetTester tester,
    AppLanguage language,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    MnoteApp.languageNotifier.value = language;
    final repo = FakeDocumentRepository()
      ..storedMetadata = LibraryMetadata(
        folders: [
          FolderItem(id: 'f1', name: 'Work', updatedAt: DateTime(2026, 10, 24)),
        ],
        documents: [
          DocumentItem(
            id: 'a',
            name: 'Alpha.md',
            content: '# Alpha',
            updatedAt: DateTime(2026, 10, 24),
            folderId: 'f1',
          ),
          DocumentItem(
            id: 'b',
            name: 'Beta.md',
            content: '# Beta',
            updatedAt: DateTime(2026, 10, 23),
          ),
        ],
      );
    await tester.pumpWidget(MnoteApp(home: NoteListScreen(repository: repo)));
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('English: toolbar, filters and cards', (tester) async {
    await pump(tester, AppLanguage.english);

    expect(find.text('New'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(find.byTooltip('Search'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    // One note in the folder: the singular form.
    expect(find.textContaining('1 file'), findsOneWidget);
    expect(find.textContaining('Oct 24, 2026'), findsWidgets);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text('Starred (favorites)'), findsOneWidget);
    expect(find.text('Folders'), findsOneWidget);
    expect(find.text('Trash'), findsWidgets);
  });

  testWidgets('English: the New menu', (tester) async {
    await pump(tester, AppLanguage.english);

    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    expect(find.text('New Markdown note (.md)'), findsOneWidget);
    expect(find.text('New text file (.txt)'), findsOneWidget);
    expect(find.text('Import a file from this device'), findsOneWidget);

    await tester.tap(find.text('New folder').last);
    await tester.pumpAndSettle();
    expect(find.text('Folder name'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('English: deleting asks in English', (tester) async {
    await pump(tester, AppLanguage.english);

    await tester.tap(find.byTooltip('Note options').first);
    await tester.pumpAndSettle();
    expect(find.text('Move to trash'), findsOneWidget);
    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);
  });

  testWidgets('Thai stays the same', (tester) async {
    await pump(tester, AppLanguage.thai);

    expect(find.text('ใหม่'), findsOneWidget);
    expect(find.byTooltip('การตั้งค่า (Settings)'), findsOneWidget);
    expect(find.textContaining('1 ไฟล์'), findsOneWidget);
    expect(find.textContaining('24 ต.ค. 69'), findsWidgets);
  });

  testWidgets('switching the language updates the open page', (tester) async {
    await pump(tester, AppLanguage.thai);
    expect(find.text('ใหม่'), findsOneWidget);

    MnoteApp.languageNotifier.value = AppLanguage.english;
    await tester.pumpAndSettle();

    expect(find.text('New'), findsOneWidget);
    expect(find.text('ใหม่'), findsNothing);
  });
}
