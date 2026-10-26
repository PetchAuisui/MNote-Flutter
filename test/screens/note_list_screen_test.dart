import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/workspace/presentation/editor_settings.dart';
import 'package:mnote/features/workspace/presentation/markdown_workspace_page.dart';
import 'package:mnote/features/workspace/presentation/markdown_live_editor.dart';
import 'package:mnote/models/note_item.dart';
import 'package:mnote/screens/note_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

void main() {
  for (final edited in [false, true]) {
    testWidgets('existing Welcome migration preserves edits: $edited', (
      tester,
    ) async {
      final oldContent = File(
        'assets/examples/welcome_v1.md',
      ).readAsStringSync();
      final content = edited ? '$oldContent\nMy notes' : oldContent;
      final repo = FakeDocumentRepository()
        ..storedMetadata = LibraryMetadata(
          folders: [],
          documents: [
            DocumentItem(
              id: 'welcome_initial_doc',
              name: 'Welcome.md',
              content: content,
              updatedAt: DateTime(2026),
              isStarred: true,
            ),
          ],
        );
      await tester.pumpWidget(
        MaterialApp(home: NoteListScreen(repository: repo)),
      );
      await tester.pumpAndSettle();
      final result = (await repo.loadMetadata())!.documents.single;
      expect(result.isStarred, isTrue);
      if (edited) {
        expect(result.content, content);
      } else {
        expect(result.content, contains('## ตาราง'));
        await tester.tap(find.text('Welcome'));
        await tester.pumpAndSettle();
        expect(find.byType(Table), findsOneWidget);
      }
    });
  }
  final sampleFolders = [
    FolderItem(
      id: 'f1',
      name: 'ใบประกอบวิชาชีพครู',
      updatedAt: DateTime(2026, 9, 20),
    ),
    FolderItem(
      id: 'f2',
      name: 'ปี 1',
      updatedAt: DateTime(2026, 7, 1),
      isStarred: true,
    ),
  ];

  final sampleDocuments = [
    DocumentItem(
      id: 'd1',
      name: '2569-01-CT05-report02.md',
      content: 'report content',
      updatedAt: DateTime(2026, 8, 14),
    ),
    DocumentItem(
      id: 'd2',
      name: '2569-01-CT05-report03.txt',
      content: 'todo list',
      updatedAt: DateTime(2026, 9, 23),
      isStarred: true,
    ),
    DocumentItem(
      id: 'd3',
      name: 'แบบร่างความคิด.md',
      content: 'draft',
      updatedAt: DateTime(2026, 9, 28),
      folderId: 'f2',
    ),
  ];

  Future<void> pumpLibrary(
    WidgetTester tester,
    FakeDocumentRepository repo,
  ) async {
    rootBundle.evict('assets/examples/welcome.md');
    rootBundle.evict('assets/examples/welcome_v1.md');
    await tester.runAsync(() async {
      await rootBundle.loadString('assets/examples/welcome.md');
      await rootBundle.loadString('assets/examples/welcome_v1.md');
    });
    await tester.pumpWidget(
      MaterialApp(home: NoteListScreen(repository: repo)),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  LibraryMetadata libraryWithNote() => LibraryMetadata(
    documents: [
      DocumentItem(
        id: 'n1',
        name: 'Notes.md',
        content: 'hi',
        updatedAt: DateTime(2026),
        uri: Uri.file('/tmp/Notes.md'),
      ),
    ],
  );

  testWidgets('adds Welcome to an existing synced library without one', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repo = FakeDocumentRepository()..storedMetadata = libraryWithNote();
    await pumpLibrary(tester, repo);

    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
  });

  testWidgets('does not bring Welcome back after the user deleted it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'mnote_welcome_removed': true});
    final repo = FakeDocumentRepository()..storedMetadata = libraryWithNote();
    await pumpLibrary(tester, repo);

    expect(find.text('Welcome'), findsNothing);
    expect(find.text('Notes'), findsOneWidget);
  });

  testWidgets(
    'seeds Welcome.md on initial launch when library is uninitialized',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      rootBundle.evict('assets/examples/welcome.md');
      rootBundle.evict('assets/examples/welcome_v1.md');
      await tester.runAsync(() async {
        await rootBundle.loadString('assets/examples/welcome.md');
        await rootBundle.loadString('assets/examples/welcome_v1.md');
      });
      final fakeRepo = FakeDocumentRepository();
      await tester.pumpWidget(
        MaterialApp(home: NoteListScreen(repository: fakeRepo)),
      );
      await tester.pumpAndSettle();

      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Welcome'), findsOneWidget);
      final savedMeta = await fakeRepo.loadMetadata();
      expect(savedMeta, isNotNull);
      expect(savedMeta!.documents.any((d) => d.name == 'Welcome.md'), isTrue);
      final welcome = savedMeta.documents.singleWhere(
        (d) => d.name == 'Welcome.md',
      );
      expect(welcome.content, contains('## ตาราง'));
      expect(welcome.content, contains('| สิ่งที่ต้องทำ | สถานะ | หมายเหตุ |'));
      await tester.tap(find.text('Welcome'));
      await tester.pumpAndSettle();
      expect(find.byType(Table), findsOneWidget);
    },
  );

  testWidgets('renders empty state when there are no folders or documents', (
    tester,
  ) async {
    final fakeRepo = FakeDocumentRepository()
      ..storedMetadata = LibraryMetadata(folders: [], documents: []);
    await tester.pumpWidget(
      MaterialApp(home: NoteListScreen(repository: fakeRepo)),
    );
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่มีไฟล์หรือโฟลเดอร์'), findsOneWidget);
    expect(
      find.text(
        'กดปุ่ม "+ ใหม่" ด้านบน เพื่อสร้างไฟล์ Markdown, ไฟล์ TXT หรือโฟลเดอร์',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'renders Document and Folder Library with folders and files (.md, .txt)',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: NoteListScreen(
            repository: FakeDocumentRepository(),
            initialFolders: sampleFolders,
            initialDocuments: sampleDocuments,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Title checks
      expect(find.text('Mnote'), findsOneWidget);

      // Initial Folders
      expect(find.text('ใบประกอบวิชาชีพครู'), findsOneWidget);
      expect(find.text('ปี 1'), findsOneWidget);

      // Initial Documents (.md and .txt)
      expect(find.text('2569-01-CT05-report02'), findsOneWidget);
      expect(find.text('2569-01-CT05-report03'), findsOneWidget);

      // Filter and "+ ใหม่" Button
      expect(find.text('ทั้งหมด'), findsOneWidget);
      expect(find.text('ใหม่'), findsOneWidget);
    },
  );

  testWidgets('enters folder and navigates back to root', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: NoteListScreen(
          repository: FakeDocumentRepository(),
          initialFolders: sampleFolders,
          initialDocuments: sampleDocuments,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Click on folder "ปี 1"
    await tester.tap(find.text('ปี 1'));
    await tester.pumpAndSettle();

    // Now inside "ปี 1" folder
    expect(find.text('แบบร่างความคิด'), findsOneWidget);

    // Tap back button
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();

    // Returned to root "Mnote"
    expect(find.text('Mnote'), findsOneWidget);
    expect(find.text('ใบประกอบวิชาชีพครู'), findsOneWidget);
  });

  testWidgets('tapping document opens MarkdownWorkspacePage', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: NoteListScreen(
          repository: FakeDocumentRepository(),
          initialFolders: sampleFolders,
          initialDocuments: sampleDocuments,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap on document card
    await tester.tap(find.text('2569-01-CT05-report02'));
    await tester.pumpAndSettle();

    // Workspace opened
    expect(find.byType(MarkdownWorkspacePage), findsOneWidget);
  });

  testWidgets('toggles between grid view and list view', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: NoteListScreen(
          repository: FakeDocumentRepository(),
          initialFolders: sampleFolders,
          initialDocuments: sampleDocuments,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GridView), findsOneWidget);
    expect(find.byType(ListView), findsNothing);

    // Tap view toggle button
    await tester.tap(find.byIcon(Icons.view_agenda_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(ListView), findsOneWidget);

    // Long press on document in ListView opens bottom sheet
    await tester.longPress(find.text('2569-01-CT05-report02'));
    await tester.pumpAndSettle();
    expect(find.text('ย้ายไปยังโฟลเดอร์'), findsOneWidget);
  });

  testWidgets(
    'tapping settings icon opens settings dialog with system theme default',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: NoteListScreen(repository: FakeDocumentRepository())),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      expect(find.text('การตั้งค่า'), findsOneWidget);
      expect(find.text('โหมดการแสดงผล (Theme)'), findsOneWidget);
      expect(find.text('ตามเครื่อง'), findsOneWidget);
      expect(find.text('ฟอนต์ตัวอักษร (Typography)'), findsNothing);
      expect(find.text('Prompt (โมเดิร์น)'), findsNothing);
    },
  );

  testWidgets('MarkdownWorkspacePage does not show settings icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: NoteListScreen(repository: FakeDocumentRepository())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('การตั้งค่า'), findsOneWidget);
    expect(find.text('โหมดการแสดงผล (Theme)'), findsOneWidget);
    expect(find.text('ตามเครื่อง'), findsOneWidget);
    expect(find.text('ฟอนต์ตัวอักษร (Typography)'), findsNothing);
  });

  testWidgets('MarkdownWorkspacePage does not show settings icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MarkdownWorkspacePage(repository: FakeDocumentRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.settings_outlined), findsNothing);
  });

  testWidgets('moves document to trash and restores it', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: NoteListScreen(
          repository: FakeDocumentRepository(),
          initialFolders: sampleFolders,
          initialDocuments: sampleDocuments,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify document is present
    expect(find.text('2569-01-CT05-report02'), findsOneWidget);

    // Open options for that document by long-pressing
    await tester.longPress(find.text('2569-01-CT05-report02'));
    await tester.pumpAndSettle();

    // Tap "ย้ายไปถังขยะ"
    expect(find.text('ย้ายไปถังขยะ'), findsOneWidget);
    await tester.tap(find.text('ย้ายไปถังขยะ'));
    await tester.pumpAndSettle();

    // Document is moved to trash and no longer in main view
    expect(find.text('2569-01-CT05-report02'), findsNothing);

    // Open filter menu to navigate to trash
    await tester.tap(find.text('ทั้งหมด'));
    await tester.pumpAndSettle();

    expect(find.text('ถังขยะ'), findsOneWidget);
    await tester.tap(find.text('ถังขยะ'));
    await tester.pumpAndSettle();

    // Document is visible in trash
    expect(find.text('2569-01-CT05-report02'), findsOneWidget);

    // Long press on the document in trash to open options
    await tester.longPress(find.text('2569-01-CT05-report02'));
    await tester.pumpAndSettle();

    // Restore it
    expect(find.text('กู้คืน'), findsOneWidget);
    await tester.tap(find.text('กู้คืน'));
    await tester.pumpAndSettle();

    // Now trash is empty
    expect(find.text('ถังขยะว่างเปล่า'), findsOneWidget);

    // Navigate back to all files
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();

    // Document is back in main view
    expect(find.text('2569-01-CT05-report02'), findsOneWidget);
  });

  testWidgets('emptying trash clears all trashed items permanently', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: NoteListScreen(
          repository: FakeDocumentRepository(),
          initialFolders: sampleFolders,
          initialDocuments: [
            DocumentItem(
              id: 'trash_doc',
              name: 'ขยะ.md',
              content: 'trash',
              updatedAt: DateTime.now(),
              isTrash: true,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open filter menu and go to Trash
    await tester.tap(find.text('ทั้งหมด'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ถังขยะ'));
    await tester.pumpAndSettle();

    expect(find.text('ขยะ'), findsOneWidget);
    expect(find.text('ล้างถังขยะ'), findsOneWidget);

    // Tap Empty Trash
    await tester.tap(find.text('ล้างถังขยะ'));
    await tester.pumpAndSettle();

    // Confirm dialog
    expect(find.text('ล้างถังขยะ?'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('ล้างถังขยะ'),
      ),
    );
    await tester.pumpAndSettle();

    // Trash should be empty
    expect(find.text('ถังขยะว่างเปล่า'), findsOneWidget);
    expect(find.text('ขยะ'), findsNothing);
  });

  testWidgets('renders symmetrical folder cards and moves folder to trash', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: NoteListScreen(
          repository: FakeDocumentRepository(),
          initialFolders: sampleFolders,
          initialDocuments: sampleDocuments,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify folder badge exists ('1 ไฟล์' for 'ปี 1' folder because d3 is in f2)
    expect(find.text('1 ไฟล์'), findsOneWidget);
    expect(find.text('0 ไฟล์'), findsOneWidget);

    // Open options menu for 'ใบประกอบวิชาชีพครู' folder by long-pressing
    await tester.longPress(find.text('ใบประกอบวิชาชีพครู'));
    await tester.pumpAndSettle();

    expect(find.text('ย้ายไปถังขยะ'), findsOneWidget);
    await tester.tap(find.text('ย้ายไปถังขยะ'));
    await tester.pumpAndSettle();

    // Folder is removed from main view
    expect(find.text('ใบประกอบวิชาชีพครู'), findsNothing);

    // Go to Trash
    await tester.tap(find.text('ทั้งหมด'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ถังขยะ'));
    await tester.pumpAndSettle();

    // Folder is present in Trash
    expect(find.text('ใบประกอบวิชาชีพครู'), findsOneWidget);
  });

  testWidgets('always places starred items first', (tester) async {
    final testDocs = [
      DocumentItem(
        id: 'doc1',
        name: 'a_unstarred.md',
        content: 'content',
        updatedAt: DateTime(2026, 9, 20),
        isStarred: false,
      ),
      DocumentItem(
        id: 'doc2',
        name: 'z_starred.md',
        content: 'content',
        updatedAt: DateTime(2026, 9, 10),
        isStarred: true,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: NoteListScreen(
          repository: FakeDocumentRepository(),
          initialFolders: [],
          initialDocuments: testDocs,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final textWidgets = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .toList();
    final zIndex = textWidgets.indexOf('z_starred');
    final aIndex = textWidgets.indexOf('a_unstarred');
    expect(zIndex != -1 && aIndex != -1 && zIndex < aIndex, isTrue);
  });

  testWidgets(
    'starred document moves ahead of unstarred folders to the very front',
    (tester) async {
      final sampleFolders = [
        FolderItem(
          id: 'f1',
          name: 'โฟลเดอร์_ปกติ',
          updatedAt: DateTime(2026, 9, 20),
          isStarred: false,
        ),
      ];
      final sampleDocuments = [
        DocumentItem(
          id: 'd1',
          name: 'บันทึก_โปรด.txt',
          content: 'content',
          updatedAt: DateTime(2026, 9, 21),
          isStarred: true,
        ),
        DocumentItem(
          id: 'd2',
          name: 'เอกสาร_ปกติ.md',
          content: 'content',
          updatedAt: DateTime(2026, 9, 22),
          isStarred: false,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: NoteListScreen(
            repository: FakeDocumentRepository(),
            initialFolders: sampleFolders,
            initialDocuments: sampleDocuments,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textWidgets = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .toList();
      final txtIndex = textWidgets.indexOf('บันทึก_โปรด');
      final folderIndex = textWidgets.indexOf('โฟลเดอร์_ปกติ');
      final mdIndex = textWidgets.indexOf('เอกสาร_ปกติ');

      // Starred txt must come before unstarred folder and md!
      expect(txtIndex != -1 && folderIndex != -1 && mdIndex != -1, isTrue);
      expect(txtIndex < folderIndex, isTrue);
      expect(folderIndex < mdIndex, isTrue);
    },
  );

  testWidgets(
    'permanently deleting document deletes backing file via repository and persists metadata',
    (tester) async {
      final fakeRepo = FakeDocumentRepository();
      final fileUri = Uri.parse('file:///data/docs/delete_me.md');

      final testDoc = DocumentItem(
        id: 'd_delete',
        name: 'delete_me.md',
        content: 'sample content',
        updatedAt: DateTime(2026, 9, 21),
        uri: fileUri,
        isTrash: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: NoteListScreen(
            repository: fakeRepo,
            initialFolders: [],
            initialDocuments: [testDoc],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to trash filter
      await tester.tap(find.text('ทั้งหมด'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ถังขยะ'));
      await tester.pumpAndSettle();

      // Verify document is in trash view
      expect(find.text('delete_me'), findsOneWidget);

      // Long press on the document card to open options
      await tester.longPress(find.text('delete_me'));
      await tester.pumpAndSettle();

      // Tap 'ลบถาวร'
      await tester.tap(find.text('ลบถาวร'));
      await tester.pumpAndSettle();

      // Confirm dialog
      expect(find.text('ลบไฟล์ถาวร?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'ลบถาวร'));
      await tester.pumpAndSettle();

      // Backing file should be deleted in repo
      expect(fakeRepo.deletedUris, contains(fileUri));

      // Metadata should have been persisted without the deleted doc
      final savedMeta = await fakeRepo.loadMetadata();
      expect(savedMeta, isNotNull);
      expect(savedMeta!.documents.any((d) => d.id == 'd_delete'), isFalse);
    },
  );

  testWidgets('persists starred and trash states across screen reloads', (
    tester,
  ) async {
    final fakeRepo = FakeDocumentRepository();
    final docUri = Uri.parse('file:///data/docs/note1.md');

    final testDoc = DocumentItem(
      id: 'doc_1',
      name: 'note1.md',
      content: 'hello world',
      updatedAt: DateTime(2026, 9, 21),
      uri: docUri,
    );

    // First session: open NoteListScreen and star the document
    await tester.pumpWidget(
      MaterialApp(
        home: NoteListScreen(
          repository: fakeRepo,
          initialFolders: [],
          initialDocuments: [testDoc],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap star icon
    await tester.tap(find.byIcon(Icons.star_outline_rounded));
    await tester.pumpAndSettle();

    // Verify metadata was saved with starred status
    final meta = await fakeRepo.loadMetadata();
    expect(meta, isNotNull);
    expect(
      meta!.documents.firstWhere((d) => d.id == 'doc_1').isStarred,
      isTrue,
    );

    // Second session: create a new NoteListScreen without initialDocuments, it loads from metadata
    await tester.pumpWidget(
      MaterialApp(home: NoteListScreen(repository: fakeRepo)),
    );
    await tester.pumpAndSettle();

    expect(find.text('note1'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
  });

  testWidgets('reloads fresh content from backing file when opening document', (
    tester,
  ) async {
    final fakeRepo = FakeDocumentRepository();
    final docUri = Uri.parse('file:///data/docs/live.md');
    fakeRepo.documentContents[docUri] = 'Brand new external content';

    final testDoc = DocumentItem(
      id: 'doc_live',
      name: 'live.md',
      content: 'old cached content',
      updatedAt: DateTime(2026, 9, 21),
      uri: docUri,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NoteListScreen(
          repository: fakeRepo,
          initialFolders: [],
          initialDocuments: [testDoc],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap the document to open it in MarkdownWorkspacePage
    await tester.tap(find.text('live'));
    await tester.pumpAndSettle();

    // The editor should contain the fresh content from repo.readDocument
    final editor = tester.widget<MarkdownLiveEditor>(
      find.byType(MarkdownLiveEditor),
    );
    expect(editor.controller.text, 'Brand new external content');
  });

  testWidgets(
    'renders centered document name with maxLines: 2 and bounded 3-dots button',
    (tester) async {
      final fakeRepo = FakeDocumentRepository();
      final longDoc = DocumentItem(
        id: 'long-doc',
        name: 'รายงานการประชุมประจำปีการศึกษา2569ระดับผู้บริหาร.md',
        content: 'hello',
        updatedAt: DateTime(2026, 10, 7),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: NoteListScreen(
            repository: fakeRepo,
            initialFolders: [],
            initialDocuments: [longDoc],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textWidget = tester.widget<Text>(find.text(longDoc.displayName));
      expect(textWidget.textAlign, TextAlign.center);
      expect(textWidget.maxLines, 2);
      expect(textWidget.overflow, TextOverflow.ellipsis);

      // Verify 3-dots button is rendered and can be tapped
      final menuButton = find.byKey(Key('doc-menu-${longDoc.id}'));
      expect(menuButton, findsOneWidget);
      await tester.tap(menuButton);
      await tester.pumpAndSettle();

      expect(find.text('เปลี่ยนชื่อไฟล์'), findsOneWidget);
      expect(find.text('ส่งออก'), findsOneWidget);
      expect(find.text('ย้ายไปถังขยะ'), findsOneWidget);
    },
  );

  testWidgets(
    'renders grouped filter menu with dividers, refined wording, and active checkmark',
    (tester) async {
      final fakeRepo = FakeDocumentRepository();
      final folder = FolderItem(
        id: 'f1',
        name: 'โฟลเดอร์ทดสอบ',
        updatedAt: DateTime(2026, 10, 7),
      );
      final doc1 = DocumentItem(
        id: 'd1',
        name: 'โน้ต1.md',
        content: 'เนื้อหา',
        updatedAt: DateTime(2026, 10, 7),
      );
      final doc2 = DocumentItem(
        id: 'd2',
        name: 'โน้ต2.txt',
        content: 'เนื้อหา txt',
        updatedAt: DateTime(2026, 10, 7),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: NoteListScreen(
            repository: fakeRepo,
            initialFolders: [folder],
            initialDocuments: [doc1, doc2],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap filter button (currently showing 'ทั้งหมด')
      await tester.tap(find.text('ทั้งหมด'));
      await tester.pumpAndSettle();

      // Verify Group 1: มุมมองหลัก
      expect(find.text('ติดดาว (รายการโปรด)'), findsOneWidget);

      // Verify Group 2: ประเภทเนื้อหา (Refined wording without 'เฉพาะ' and 'เอกสารทั้งหมด')
      expect(find.text('โฟลเดอร์'), findsOneWidget);
      expect(find.text('เอกสารทั้งหมด'), findsOneWidget);
      expect(find.text('Markdown (.md)'), findsOneWidget);
      expect(find.text('Text (.txt)'), findsOneWidget);

      // Verify Group 3: ระบบ
      expect(find.text('ถังขยะ'), findsOneWidget);

      // Verify PopupMenuDividers are present (at least 2 dividers)
      expect(find.byType(PopupMenuDivider), findsNWidgets(2));

      // Verify checkmark is rendered for the currently active filter ('ทั้งหมด')
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      // Switch filter to 'เอกสารทั้งหมด'
      await tester.tap(find.text('เอกสารทั้งหมด'));
      await tester.pumpAndSettle();

      // Documents are visible, folder is filtered out
      expect(find.text('โน้ต1'), findsOneWidget);
      expect(find.text('โน้ต2'), findsOneWidget);
      expect(find.text('โฟลเดอร์ทดสอบ'), findsNothing);

      // Button label now displays 'เอกสารทั้งหมด'
      expect(find.text('เอกสารทั้งหมด'), findsOneWidget);
    },
  );

  testWidgets('a folder can be given a color and reset to the default', (
    tester,
  ) async {
    final repo = FakeDocumentRepository();
    final folder = FolderItem(
      id: 'f_color',
      name: 'โฟลเดอร์สี',
      updatedAt: DateTime(2026, 10, 8),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: NoteListScreen(repository: repo, initialFolders: [folder]),
      ),
    );
    await tester.pumpAndSettle();

    Icon folderIcon() => tester
        .widgetList<Icon>(find.byIcon(Icons.folder_rounded))
        .firstWhere((icon) => icon.size == 128);
    final defaultColor = folderIcon().color;

    await tester.tap(find.byKey(const Key('folder-menu-f_color')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('folder-menu-color')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('folder-color-ffe53935')));
    await tester.pumpAndSettle();

    expect(folderIcon().color, const Color(0xFFE53935));
    expect(repo.storedMetadata!.folders.single.colorValue, 0xFFE53935);

    await tester.longPress(find.text('โฟลเดอร์สี'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('folder-change-color')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('folder-color-default')));
    await tester.pumpAndSettle();

    expect(folderIcon().color, defaultColor);
    expect(repo.storedMetadata!.folders.single.colorValue, isNull);
  });

  testWidgets('moves document to folder and back to root successfully', (
    tester,
  ) async {
    final fakeRepo = FakeDocumentRepository();
    final folder = FolderItem(
      id: 'f_work',
      name: 'โฟลเดอร์งาน',
      updatedAt: DateTime(2026, 10, 8),
    );
    final doc = DocumentItem(
      id: 'd_test',
      name: 'เอกสารสำคัญ.md',
      content: 'ทดสอบเนื้อหา',
      updatedAt: DateTime(2026, 10, 8),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NoteListScreen(
          repository: fakeRepo,
          initialFolders: [folder],
          initialDocuments: [doc],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Initially both folder and doc are in root
    expect(find.text('โฟลเดอร์งาน'), findsOneWidget);
    expect(find.text('เอกสารสำคัญ'), findsOneWidget);

    // Open doc menu
    final docMenu = find.byKey(Key('doc-menu-${doc.id}'));
    expect(docMenu, findsOneWidget);
    await tester.tap(docMenu);
    await tester.pumpAndSettle();

    // Tap 'ย้ายไปยังโฟลเดอร์'
    expect(find.text('ย้ายไปยังโฟลเดอร์'), findsOneWidget);
    await tester.tap(find.text('ย้ายไปยังโฟลเดอร์'));
    await tester.pumpAndSettle();

    // Destination dialog shows folder option
    expect(find.text('ย้ายเอกสารไปที่...'), findsOneWidget);
    expect(find.text('โฟลเดอร์งาน'), findsWidgets);

    // Tap 'โฟลเดอร์งาน' in dialog
    await tester.tap(find.widgetWithText(ListTile, 'โฟลเดอร์งาน'));
    await tester.pumpAndSettle();

    // Doc should now be moved out of root view
    expect(find.text('เอกสารสำคัญ'), findsNothing);

    // Enter the folder
    await tester.tap(find.text('โฟลเดอร์งาน'));
    await tester.pumpAndSettle();

    // Inside folder, doc should now be visible
    expect(find.text('เอกสารสำคัญ'), findsOneWidget);

    // Move it back to root
    final insideMenu = find.byKey(Key('doc-menu-${doc.id}'));
    await tester.tap(insideMenu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ย้ายไปยังโฟลเดอร์'));
    await tester.pumpAndSettle();

    // Option 'หน้าหลัก (นอกสุด)' should appear
    expect(find.text('หน้าหลัก (นอกสุด)'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'หน้าหลัก (นอกสุด)'));
    await tester.pumpAndSettle();

    // Inside folder, doc should disappear
    expect(find.text('เอกสารสำคัญ'), findsNothing);

    // Back to root
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();

    // Back in root, doc should be visible again
    expect(find.text('เอกสารสำคัญ'), findsOneWidget);
  });

  testWidgets('sorts items when sort mode is selected from sort menu', (
    tester,
  ) async {
    final fakeRepo = FakeDocumentRepository();
    final docB = DocumentItem(
      id: 'doc_b',
      name: 'B_Note.md',
      content: 'content',
      updatedAt: DateTime(2026, 1, 10),
      isStarred: false,
      isTrash: false,
    );
    final docA = DocumentItem(
      id: 'doc_a',
      name: 'A_Note.md',
      content: 'content',
      updatedAt: DateTime(2026, 1, 1),
      isStarred: false,
      isTrash: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NoteListScreen(
          repository: fakeRepo,
          initialFolders: [],
          initialDocuments: [docB, docA],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // ค่าเริ่มต้นเป็น newest: B_Note (10 ม.ค.) ต้องมาก่อน A_Note (1 ม.ค.)
    // ใน GridView รายการแรกจะอยู่ทางซ้าย (dx น้อยกว่า)
    expect(
      tester.getTopLeft(find.text('B_Note')).dx <
          tester.getTopLeft(find.text('A_Note')).dx,
      isTrue,
      reason: 'B_Note ควรอยู่ก่อน A_Note ตามเวลาแก้ไขล่าสุด',
    );

    // Open sort menu
    await tester.tap(find.byTooltip('จัดเรียงตาม'));
    await tester.pumpAndSettle();

    expect(find.text('แก้ไขล่าสุด'), findsOneWidget);
    expect(find.text('เก่าที่สุด'), findsOneWidget);
    expect(find.text('ชื่อ (ก - ฮ)'), findsOneWidget);
    expect(find.text('ชื่อ (ฮ - ก)'), findsOneWidget);

    // 1. เลือก 'เก่าที่สุด' -> A_Note (1 ม.ค.) ต้องสลับมาอยู่ก่อน B_Note (10 ม.ค.)
    await tester.tap(find.text('เก่าที่สุด'));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('A_Note')).dx <
          tester.getTopLeft(find.text('B_Note')).dx,
      isTrue,
      reason: 'A_Note ควรอยู่ก่อน B_Note เมื่อเรียงตามเก่าที่สุด',
    );

    // 2. เลือก 'ชื่อ (ฮ - ก)' -> B_Note ต้องมาก่อน A_Note
    await tester.tap(find.byTooltip('จัดเรียงตาม'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ชื่อ (ฮ - ก)'));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('B_Note')).dx <
          tester.getTopLeft(find.text('A_Note')).dx,
      isTrue,
      reason: 'B_Note ควรอยู่ก่อน A_Note เมื่อเรียงชื่อ ฮ - ก',
    );

    // 3. เลือก 'ชื่อ (ก - ฮ)' -> A_Note ต้องกลับมาอยู่ก่อน B_Note
    await tester.tap(find.byTooltip('จัดเรียงตาม'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ชื่อ (ก - ฮ)'));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('A_Note')).dx <
          tester.getTopLeft(find.text('B_Note')).dx,
      isTrue,
      reason: 'A_Note ควรอยู่ก่อน B_Note เมื่อเรียงชื่อ ก - ฮ',
    );
  });

  testWidgets('document cards use two columns and do not overflow on a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(411, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'mnote_welcome_removed': true});
    final docs = [
      for (var i = 0; i < 4; i++)
        DocumentItem(
          id: 'n$i',
          name: 'Note$i.md',
          content: '# Hello Everyone\nPersonal Information - Name : Siwapat',
          updatedAt: DateTime(2026),
        ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: NoteListScreen(
          repository: FakeDocumentRepository(),
          initialDocuments: docs,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final first = tester.getTopLeft(find.text('Note0'));
    final second = tester.getTopLeft(find.text('Note1'));
    final third = tester.getTopLeft(find.text('Note2'));
    expect(second.dx, greaterThan(first.dx));
    expect(third.dx, first.dx, reason: 'third card wraps to a second row');
    final card = tester.getSize(find.byKey(const ValueKey('doc-card-n0')));
    expect(card.width, 148);
  });

  for (final width in [320.0, 411.0, 600.0, 700.0, 834.0, 1200.0]) {
    testWidgets('document cards are never squeezed at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({'mnote_welcome_removed': true});
      await tester.pumpWidget(
        MaterialApp(
          home: NoteListScreen(
            repository: FakeDocumentRepository(),
            initialDocuments: [
              DocumentItem(
                id: 'n0',
                name: 'Note0.md',
                content: '# Hello Everyone\nPersonal Information - Name',
                updatedAt: DateTime(2026),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final card = tester.getSize(find.byKey(const ValueKey('doc-card-n0')));
      // 320dp phones cannot fit two full cards; everything wider must.
      if (width >= 360) expect(card.width, 148);
    });
  }

  testWidgets('card previews use the editor font, live', (tester) async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(EditorSettings.instance.resetLook);
    final repo = FakeDocumentRepository()
      ..storedMetadata = LibraryMetadata(
        folders: [],
        documents: [
          DocumentItem(
            id: 'a',
            name: 'Alpha.md',
            content: '# Alpha title\n\nbody words here',
            updatedAt: DateTime(2026),
          ),
        ],
      );
    await tester.pumpWidget(
      MaterialApp(home: NoteListScreen(repository: repo)),
    );
    await tester.pumpAndSettle();
    String? family() =>
        tester.widget<Text>(find.text('Alpha title')).style?.fontFamily;
    final before = family();

    EditorSettings.instance.font = EditorFont.sarabun;
    await tester.pumpAndSettle();

    expect(family(), isNot(before));
    expect(family(), contains('Sarabun'));
  });
}
