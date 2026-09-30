import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/workspace/presentation/markdown_workspace_page.dart';
import 'package:mnote/screens/note_list_screen.dart';

import '../helpers/fakes.dart';

void main() {
  testWidgets('renders Document and Folder Library with folders and files (.md, .txt)', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: NoteListScreen(repository: FakeDocumentRepository()),
      ),
    );
    await tester.pumpAndSettle();

    // Title checks
    expect(find.text('เอกสาร'), findsOneWidget);

    // Initial Folders
    expect(find.text('ใบประกอบวิชาชีพครู'), findsOneWidget);
    expect(find.text('ปี 1'), findsOneWidget);

    // Initial Documents (.md and .txt)
    expect(find.text('2569-01-CT05-report02.md'), findsOneWidget);
    expect(find.text('2569-01-CT05-report03.txt'), findsOneWidget);

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
        home: NoteListScreen(repository: FakeDocumentRepository()),
      ),
    );
    await tester.pumpAndSettle();

    // Click on folder "ปี 1"
    await tester.tap(find.text('ปี 1'));
    await tester.pumpAndSettle();

    // Now inside "ปี 1" folder
    expect(find.text('แบบร่างความคิด.md'), findsOneWidget);

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
        home: NoteListScreen(repository: FakeDocumentRepository()),
      ),
    );
    await tester.pumpAndSettle();

    // Tap on document card
    await tester.tap(find.text('2569-01-CT05-report02.md'));
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
        home: NoteListScreen(repository: FakeDocumentRepository()),
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
}
