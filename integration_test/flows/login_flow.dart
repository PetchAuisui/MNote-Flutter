import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/app/mnote_app.dart';
import 'package:mnote/features/auth/domain/auth_exception.dart';
import 'package:mnote/features/auth/presentation/auth_page.dart';
import 'package:mnote/features/auth/presentation/login_page.dart';
import 'package:mnote/features/workspace/data/local_document_repository.dart';
import 'package:mnote/screens/note_list_screen.dart';

import '../../test/helpers/fake_auth_repository.dart';
import '../helpers/harness.dart';

/// End-to-end: from a cold start the user goes through the splash screen,
/// fails one login, logs in, skips the guide and lands in their library.
/// Firebase Auth is replaced by a fake so the run needs no network.
void main() {
  testWidgets('cold start → login → guide → library', (tester) async {
    prepareDevice(tester, size: const Size(820, 1180));
    final storage = await createStorage(tester);
    final auth = FakeAuthRepository();

    await tester.pumpWidget(
      MnoteApp(
        documentRepository: LocalDocumentRepository(storage),
        skipAuth: false,
        authRepository: auth,
      ),
    );
    // The splash moves on by itself after a moment.
    await Future<void>.delayed(const Duration(seconds: 3));
    await settle(tester);
    expect(find.byType(AuthPage), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'เข้าสู่ระบบ'));
    await settle(tester);
    expect(find.byType(LoginPage), findsOneWidget);

    final email = find.byType(TextFormField).at(0);
    final password = find.byType(TextFormField).at(1);
    final submit = find.widgetWithText(FilledButton, 'เข้าสู่ระบบ');

    // Empty form: validation stops it before anything reaches Firebase.
    await tester.tap(submit);
    await settle(tester);
    expect(find.text('กรุณากรอกอีเมล'), findsOneWidget);
    expect(auth.signInCalls, 0);

    // Wrong password: the error is shown and the user stays here.
    auth.error = const AuthException(AuthErrorCode.wrongCredentials);
    await tester.enterText(email, 'student@example.com');
    await tester.enterText(password, 'wrong-pass');
    await tester.tap(submit);
    await settle(tester);
    expect(find.byKey(const Key('auth-error')), findsOneWidget);
    expect(find.byType(LoginPage), findsOneWidget);

    // Right password: signed in.
    auth.error = null;
    await tester.enterText(password, 'right-pass');
    await tester.tap(submit);
    await settle(tester);
    expect(auth.currentUser?.email, 'student@example.com');

    // First run shows the guide; skipping it opens the library.
    final skip = find.byKey(const Key('app-guide-skip-button'));
    if (skip.evaluate().isNotEmpty) {
      await tester.tap(skip);
      await settle(tester);
    }
    expect(find.byType(NoteListScreen), findsOneWidget);
    expect(find.text('Welcome'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
