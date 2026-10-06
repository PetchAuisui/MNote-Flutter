import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/workspace/presentation/markdown_workspace_page.dart';
import 'package:mnote/models/note_item.dart';
import 'package:mnote/screens/note_list_screen.dart';

import '../helpers/fakes.dart';

void main() {
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

  testWidgets('seeds Welcome.md on initial launch when library is uninitialized', (tester) async {
    final fakeRepo = FakeDocumentRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: NoteListScreen(repository: fakeRepo),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome'), findsOneWidget);
    final savedMeta = await fakeRepo.loadMetadata();
    expect(savedMeta, isNotNull);
    expect(savedMeta!.documents.any((d) => d.name == 'Welcome.md'), isTrue);
  });

  testWidgets('renders empty state when there are no folders or documents', (tester) async {
    final fakeRepo = FakeDocumentRepository()
      ..storedMetadata = LibraryMetadata(folders: [], documents: []);
    await tester.pumpWidget(
      MaterialApp(
        home: NoteListScreen(repository: fakeRepo),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่มีไฟล์หรือโฟลเดอร์'), findsOneWidget);
    expect(find.text('กดปุ่ม "+ ใหม่" ด้านบน เพื่อสร้างไฟล์ Markdown, ไฟล์ TXT หรือโฟลเดอร์'), findsOneWidget);
  });

  testWidgets('renders Document and Folder Library with folders and files (.md, .txt)', (tester) async {
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
    expect(find.text('เอกสาร'), findsOneWidget);

    // Initial Folders
    expect(find.text('ใบประกอบวิชาชีพครู'), findsOneWidget);
    expect(find.text('ปี 1'), findsOneWidget);

    // Initial Documents (.md and .txt)
    expect(find.text('2569-01-CT05-report02'), findsOneWidget);
    expect(find.text('2569-01-CT05-report03'), findsOneWidget);

    // Filter and "+ ใหม่" Button
    expect(find.text('ทั้งหมด'), findsOneWidget);
    expect(find.text('ใหม่'), findsOneWidget);
  });

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

    // Returned to root "เอกสาร"
    expect(find.text('เอกสาร'), findsOneWidget);
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
  });

  testWidgets('tapping settings icon opens settings dialog with system theme default', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NoteListScreen(
          repository: FakeDocumentRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('การตั้งค่า'), findsOneWidget);
    expect(find.text('โหมดการแสดงผล (Theme)'), findsOneWidget);
    expect(find.text('ตามเครื่อง'), findsOneWidget);
    expect(find.text('ฟอนต์ตัวอักษร (Typography)'), findsNothing);
  });

  testWidgets('MarkdownWorkspacePage does not show settings icon', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MarkdownWorkspacePage(
          repository: FakeDocumentRepository(),
        ),
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

  testWidgets('emptying trash clears all trashed items permanently', (tester) async {
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

  testWidgets('renders symmetrical folder cards and moves folder to trash', (tester) async {
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

    final textWidgets = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList();
    final zIndex = textWidgets.indexOf('z_starred');
    final aIndex = textWidgets.indexOf('a_unstarred');
    expect(zIndex != -1 && aIndex != -1 && zIndex < aIndex, isTrue);
  });

  testWidgets('starred document moves ahead of unstarred folders to the very front', (tester) async {
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

    final textWidgets = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList();
    final txtIndex = textWidgets.indexOf('บันทึก_โปรด');
    final folderIndex = textWidgets.indexOf('โฟลเดอร์_ปกติ');
    final mdIndex = textWidgets.indexOf('เอกสาร_ปกติ');

    // Starred txt must come before unstarred folder and md!
    expect(txtIndex != -1 && folderIndex != -1 && mdIndex != -1, isTrue);
    expect(txtIndex < folderIndex, isTrue);
    expect(folderIndex < mdIndex, isTrue);
  });

  testWidgets('permanently deleting document deletes backing file via repository and persists metadata', (tester) async {
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
  });

  testWidgets('persists starred and trash states across screen reloads', (tester) async {
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
    expect(meta!.documents.firstWhere((d) => d.id == 'doc_1').isStarred, isTrue);

    // Second session: create a new NoteListScreen without initialDocuments, it loads from metadata
    await tester.pumpWidget(
      MaterialApp(
        home: NoteListScreen(
          repository: fakeRepo,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('note1'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
  });

  testWidgets('reloads fresh content from backing file when opening document', (tester) async {
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
    final editor = tester.widget<TextField>(
      find.byKey(const Key('markdown-editor')),
    );
    expect(editor.controller?.text, 'Brand new external content');
  });
}

