import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/auth/domain/auth_exception.dart';
import 'package:mnote/features/auth/presentation/auth_page.dart';
import 'package:mnote/features/auth/presentation/login_page.dart';
import 'package:mnote/features/auth/presentation/register_page.dart';

import '../../../helpers/fake_auth_repository.dart';

const _next = Scaffold(body: Text('next-page'));

Future<void> _pump(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: page));
}

void main() {
  group('Mandatory login', () {
    testWidgets('AuthPage offers email login', (tester) async {
      await _pump(
        tester,
        AuthPage(authRepository: FakeAuthRepository(), nextPage: _next),
      );

      await tester.tap(find.widgetWithText(FilledButton, 'เข้าสู่ระบบ'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets('Continue with Google signs in and opens next page',
        (tester) async {
      final repo = FakeAuthRepository();
      await _pump(tester, AuthPage(authRepository: repo, nextPage: _next));

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(repo.googleCalls, 1);
      expect(find.text('next-page'), findsOneWidget);
    });

    testWidgets('Google sign-in cancelled stays on AuthPage silently',
        (tester) async {
      final repo = FakeAuthRepository(
        error: const AuthException(AuthErrorCode.cancelled),
      );
      await _pump(tester, AuthPage(authRepository: repo, nextPage: _next));

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(find.text('next-page'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('Google sign-in failure shows an error', (tester) async {
      final repo = FakeAuthRepository(
        error: const AuthException(AuthErrorCode.network),
      );
      await _pump(tester, AuthPage(authRepository: repo, nextPage: _next));

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();

      expect(find.text('เชื่อมต่ออินเทอร์เน็ตไม่ได้'), findsOneWidget);
      expect(find.text('next-page'), findsNothing);
    });
  });

  group('LoginPage', () {
    testWidgets('shows validation errors and does not call repository', (
      tester,
    ) async {
      final repo = FakeAuthRepository();
      await _pump(tester, LoginPage(authRepository: repo, nextPage: _next));

      await tester.tap(find.widgetWithText(FilledButton, 'เข้าสู่ระบบ'));
      await tester.pump();

      expect(find.text('กรุณากรอกอีเมล'), findsOneWidget);
      expect(find.text('กรุณากรอกรหัสผ่าน'), findsOneWidget);
      expect(repo.signInCalls, 0);
    });

    testWidgets('successful login navigates to next page', (tester) async {
      final repo = FakeAuthRepository();
      await _pump(tester, LoginPage(authRepository: repo, nextPage: _next));

      await tester.enterText(find.byType(TextFormField).at(0), 'a@b.co');
      await tester.enterText(find.byType(TextFormField).at(1), 'secret1');
      await tester.tap(find.widgetWithText(FilledButton, 'เข้าสู่ระบบ'));
      await tester.pumpAndSettle();

      expect(repo.signInCalls, 1);
      expect(repo.lastEmail, 'a@b.co');
      expect(find.text('next-page'), findsOneWidget);
    });

    testWidgets('shows error message on wrong credentials', (tester) async {
      final repo = FakeAuthRepository(
        error: const AuthException(AuthErrorCode.wrongCredentials),
      );
      await _pump(tester, LoginPage(authRepository: repo, nextPage: _next));

      await tester.enterText(find.byType(TextFormField).at(0), 'a@b.co');
      await tester.enterText(find.byType(TextFormField).at(1), 'badpass');
      await tester.tap(find.widgetWithText(FilledButton, 'เข้าสู่ระบบ'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('auth-error')), findsOneWidget);
      expect(find.text('อีเมลหรือรหัสผ่านไม่ถูกต้อง'), findsOneWidget);
      expect(find.text('next-page'), findsNothing);
    });
  });

  group('RegisterPage', () {
    testWidgets('rejects mismatched passwords', (tester) async {
      final repo = FakeAuthRepository();
      await _pump(tester, RegisterPage(authRepository: repo, nextPage: _next));

      await tester.enterText(find.byType(TextFormField).at(0), 'Pet');
      await tester.enterText(find.byType(TextFormField).at(1), 'a@b.co');
      await tester.enterText(find.byType(TextFormField).at(2), 'secret1');
      await tester.enterText(find.byType(TextFormField).at(3), 'secret2');
      await tester.tap(find.widgetWithText(FilledButton, 'สมัครสมาชิก'));
      await tester.pump();

      expect(find.text('รหัสผ่านไม่ตรงกัน'), findsOneWidget);
      expect(repo.registerCalls, 0);
    });

    testWidgets('successful registration navigates to next page', (
      tester,
    ) async {
      final repo = FakeAuthRepository();
      await _pump(tester, RegisterPage(authRepository: repo, nextPage: _next));

      await tester.enterText(find.byType(TextFormField).at(0), 'Pet');
      await tester.enterText(find.byType(TextFormField).at(1), 'a@b.co');
      await tester.enterText(find.byType(TextFormField).at(2), 'secret1');
      await tester.enterText(find.byType(TextFormField).at(3), 'secret1');
      await tester.tap(find.widgetWithText(FilledButton, 'สมัครสมาชิก'));
      await tester.pumpAndSettle();

      expect(repo.registerCalls, 1);
      expect(repo.lastDisplayName, 'Pet');
      expect(find.text('next-page'), findsOneWidget);
    });

    testWidgets('shows error when email already in use', (tester) async {
      final repo = FakeAuthRepository(
        error: const AuthException(AuthErrorCode.emailAlreadyInUse),
      );
      await _pump(tester, RegisterPage(authRepository: repo, nextPage: _next));

      await tester.enterText(find.byType(TextFormField).at(0), 'Pet');
      await tester.enterText(find.byType(TextFormField).at(1), 'a@b.co');
      await tester.enterText(find.byType(TextFormField).at(2), 'secret1');
      await tester.enterText(find.byType(TextFormField).at(3), 'secret1');
      await tester.tap(find.widgetWithText(FilledButton, 'สมัครสมาชิก'));
      await tester.pumpAndSettle();

      expect(find.text('อีเมลนี้ถูกใช้งานแล้ว'), findsOneWidget);
    });
  });
}
