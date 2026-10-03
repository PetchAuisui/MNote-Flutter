import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/app/mnote_app.dart';
import 'package:mnote/features/auth/presentation/auth_page.dart';
import 'package:mnote/features/auth/presentation/splash_page.dart';
import 'package:mnote/features/workspace/presentation/markdown_workspace_page.dart';

import '../../../helpers/fakes.dart';

void main() {
  group('Auth Flow Tests', () {
    testWidgets('MnoteApp starts on SplashPage when auth is enabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        MnoteApp(
          documentRepository: FakeDocumentRepository(),
          skipAuth: false,
        ),
      );

      expect(find.byType(SplashPage), findsOneWidget);
    });

    testWidgets('SplashPage navigates to AuthPage after timer expires', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SplashPage(
            repository: FakeDocumentRepository(),
            duration: const Duration(milliseconds: 500),
          ),
        ),
      );

      expect(find.byType(SplashPage), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.byType(AuthPage), findsOneWidget);
      expect(find.text('Welcome to Mnote'), findsOneWidget);
    });

    testWidgets('SplashPage navigates immediately on tap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SplashPage(
            repository: FakeDocumentRepository(),
            duration: const Duration(seconds: 10),
          ),
        ),
      );

      expect(find.byType(SplashPage), findsOneWidget);

      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      expect(find.byType(AuthPage), findsOneWidget);
    });

    testWidgets('AuthPage shows logo, title, description, and google button', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AuthPage(repository: FakeDocumentRepository()),
        ),
      );

      expect(find.text('Welcome to Mnote'), findsOneWidget);
      expect(
        find.text(
          'Log in or create a new account\nusing your Google account.',
        ),
        findsOneWidget,
      );
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets(
      'Pressing Continue with Google shows "ล็อกอินสำเร็จ" and transitions to workspace',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: AuthPage(repository: FakeDocumentRepository()),
          ),
        );

        final googleButtonFinder = find.text('Continue with Google');
        expect(googleButtonFinder, findsOneWidget);

        await tester.tap(googleButtonFinder);
        await tester.pump();

        // ตรวจสอบว่ามี SnackBar แสดงข้อความ 'ล็อกอินสำเร็จ'
        expect(find.text('ล็อกอินสำเร็จ'), findsOneWidget);

        // รอเวลา transition เข้าสู่หน้า workspace
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // ตรวจสอบว่านำทางมายังหน้า MarkdownWorkspacePage เรียบร้อยแล้ว
        expect(find.byType(MarkdownWorkspacePage), findsOneWidget);
        expect(find.byKey(const Key('markdown-editor')), findsOneWidget);
      },
    );
  });
}
