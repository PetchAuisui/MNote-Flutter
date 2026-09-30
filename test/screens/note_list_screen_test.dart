import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/workspace/presentation/markdown_workspace_page.dart';
import 'package:mnote/screens/note_list_screen.dart';

import '../helpers/fakes.dart';

void main() {
  testWidgets('renders NoteListScreen with app bar, search bar, and filter chips', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NoteListScreen(repository: FakeDocumentRepository()),
      ),
    );

    // Header checks
    expect(find.text('Mnote'), findsOneWidget);
    expect(find.byType(SearchBar), findsOneWidget);

    // Filter Chips
    expect(find.text('ทั้งหมด'), findsOneWidget);
    expect(find.text('⭐ ปักหมุด'), findsOneWidget);
    expect(find.text('📝 Markdown'), findsOneWidget);
    expect(find.text('🎨 Drawing'), findsOneWidget);

    // Initial Notes
    expect(find.text('Sprint Planning & Notes'), findsOneWidget);
    expect(find.text('System Architecture'), findsOneWidget);

    // FAB
    expect(find.text('โน้ตใหม่'), findsOneWidget);
  });

  testWidgets('filters notes based on search query', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NoteListScreen(repository: FakeDocumentRepository()),
      ),
    );

    // Search for Architecture
    await tester.enterText(find.byType(SearchBar), 'Architecture');
    await tester.pumpAndSettle();

    expect(find.text('System Architecture'), findsOneWidget);
    expect(find.text('สูตรอาหาร & วัตถุดิบ'), findsNothing);
  });

  testWidgets('toggles between list view and grid view', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NoteListScreen(repository: FakeDocumentRepository()),
      ),
    );

    expect(find.byType(ListView), findsOneWidget);
    expect(find.byType(GridView), findsNothing);

    // Tap toggle view button
    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(GridView), findsOneWidget);
  });

  testWidgets('tapping FAB opens MarkdownWorkspacePage', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NoteListScreen(repository: FakeDocumentRepository()),
      ),
    );

    await tester.tap(find.text('โน้ตใหม่'));
    await tester.pumpAndSettle();

    expect(find.byType(MarkdownWorkspacePage), findsOneWidget);
  });
}
