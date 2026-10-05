import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/auth/presentation/app_guide_page.dart';
import 'package:mnote/screens/note_list_screen.dart';

import '../../../helpers/fakes.dart';

void main() {
  group('AppGuidePage Tests', () {
    testWidgets('renders guide title, skip button, and slide 1 content', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AppGuidePage(repository: FakeDocumentRepository()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('app-guide-title')), findsOneWidget);
      expect(find.text('คู่มือการใช้ Mnote'), findsOneWidget);
      expect(find.byKey(const Key('app-guide-skip-button')), findsOneWidget);
      expect(find.text('ข้าม'), findsOneWidget);

      // Slide 1 text
      expect(find.text('เขียนและจัดรูปแบบ Markdown'), findsOneWidget);
      expect(find.text('ขั้นตอน 01 / 03'), findsOneWidget);

      // Previous button should be disabled on first slide
      final prevButton = tester.widget<IconButton>(
        find.byKey(const Key('app-guide-prev-button')),
      );
      expect(prevButton.onPressed, isNull);

      // Next button exists
      expect(find.byKey(const Key('app-guide-next-button')), findsOneWidget);
    });

    testWidgets('tapping skip button navigates to NoteListScreen', (
      tester,
    ) async {
      final repo = FakeDocumentRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: AppGuidePage(
            repository: repo,
            nextPage: NoteListScreen(repository: repo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final skipButton = find.byKey(const Key('app-guide-skip-button'));
      await tester.tap(skipButton);
      await tester.pumpAndSettle();

      expect(find.byType(NoteListScreen), findsOneWidget);
    });

    testWidgets('can navigate forward through all 3 slides and then enter Mnote', (
      tester,
    ) async {
      final repo = FakeDocumentRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: AppGuidePage(
            repository: repo,
            nextPage: NoteListScreen(repository: repo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Slide 1
      expect(find.text('เขียนและจัดรูปแบบ Markdown'), findsOneWidget);

      // Tap Next to Slide 2
      await tester.tap(find.byKey(const Key('app-guide-next-button')));
      await tester.pumpAndSettle();
      expect(find.text('วาดเขียน & จดโน้ตด้วยปากกา'), findsOneWidget);
      expect(find.text('ขั้นตอน 02 / 03'), findsOneWidget);

      // Tap Next to Slide 3 (Last slide)
      await tester.tap(find.byKey(const Key('app-guide-next-button')));
      await tester.pumpAndSettle();
      expect(find.text('สร้างไดอะแกรม Mermaid ทันใจ'), findsOneWidget);
      expect(find.text('ขั้นตอน 03 / 03'), findsOneWidget);

      // On last slide: "เข้าสู่ Mnote" button is shown
      expect(find.byKey(const Key('app-guide-enter-button')), findsOneWidget);
      expect(find.text('เข้าสู่ Mnote'), findsOneWidget);

      // Tap "เข้าสู่ Mnote"
      await tester.tap(find.byKey(const Key('app-guide-enter-button')));
      await tester.pumpAndSettle();

      // Navigated to NoteListScreen
      expect(find.byType(NoteListScreen), findsOneWidget);
    });

    testWidgets('can navigate backwards using previous arrow button', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AppGuidePage(repository: FakeDocumentRepository()),
        ),
      );
      await tester.pumpAndSettle();

      // Go to Slide 2
      await tester.tap(find.byKey(const Key('app-guide-next-button')));
      await tester.pumpAndSettle();
      expect(find.text('วาดเขียน & จดโน้ตด้วยปากกา'), findsOneWidget);

      // Tap Previous button
      await tester.tap(find.byKey(const Key('app-guide-prev-button')));
      await tester.pumpAndSettle();
      expect(find.text('เขียนและจัดรูปแบบ Markdown'), findsOneWidget);
    });
  });
}
