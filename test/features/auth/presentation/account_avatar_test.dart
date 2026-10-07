import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/auth/domain/auth_user.dart';
import 'package:mnote/features/auth/presentation/auth_page.dart';
import 'package:mnote/features/auth/presentation/widgets/account_avatar_button.dart';
import 'package:mnote/screens/note_list_screen.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/fakes.dart';

void main() {
  test('accountInitial uses name, falls back to email, uppercases', () {
    expect(
      accountInitial(
        const AuthUser(uid: '1', email: 'x@y.co', displayName: 'pet'),
      ),
      'P',
    );
    expect(accountInitial(const AuthUser(uid: '1', email: 'x@y.co')), 'X');
    expect(
      accountInitial(
        const AuthUser(uid: '1', email: 'x@y.co', displayName: 'สิวัช'),
      ),
      'ส',
    );
    expect(
      accountInitial(
        const AuthUser(uid: '1', email: 'x@y.co', displayName: 'เพชร'),
      ),
      'พ',
    );
  });

  testWidgets('avatar loads the Google photo when available', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AccountAvatar(
          user: AuthUser(
            uid: '1',
            email: 'x@y.co',
            photoUrl: 'https://example.com/p.png',
          ),
        ),
      ),
    );
    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.foregroundImage, isA<NetworkImage>());

    await tester.pumpWidget(
      const MaterialApp(
        home: AccountAvatar(
          user: AuthUser(uid: '1', email: 'x@y.co'),
        ),
      ),
    );
    expect(
      tester.widget<CircleAvatar>(find.byType(CircleAvatar)).foregroundImage,
      isNull,
    );
  });

  testWidgets('note list shows initial icon, dialog, and signs out', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final auth = FakeAuthRepository(
      currentUser: const AuthUser(
        uid: 'u1',
        email: 'pet@mail.com',
        displayName: 'Pet',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: NoteListScreen(
          repository: FakeDocumentRepository(),
          authRepository: auth,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('P'), findsOneWidget);
    await tester.tap(find.byTooltip('บัญชีของฉัน'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('account-name')), findsOneWidget);
    expect(find.text('pet@mail.com'), findsOneWidget);

    await tester.tap(find.text('ออกจากระบบ'));
    await tester.pumpAndSettle();

    expect(auth.currentUser, isNull);
    expect(find.byType(AuthPage), findsOneWidget);
  });

  group('account dialog', () {
    Future<FakeAuthRepository> openDialog(
      WidgetTester tester,
      AuthUser user,
    ) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final auth = FakeAuthRepository(currentUser: user);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccountAvatarButton(
              user: user,
              authRepository: auth,
              onSignOut: auth.signOut,
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('บัญชีของฉัน'));
      await tester.pumpAndSettle();
      return auth;
    }

    testWidgets('Google user sees provider and member-since, no reset', (
      tester,
    ) async {
      await openDialog(
        tester,
        AuthUser(
          uid: '1',
          email: 'g@mail.com',
          displayName: 'Gee',
          providerIds: const ['google.com'],
          createdAt: DateTime(2026, 3, 5),
        ),
      );
      expect(find.text('เข้าสู่ระบบด้วย Google'), findsOneWidget);
      expect(find.text('สมาชิกตั้งแต่ 5 มี.ค. 2569'), findsOneWidget);
      expect(find.byKey(const Key('account-reset-password')), findsNothing);
    });

    testWidgets('email user can request a password reset', (tester) async {
      final auth = await openDialog(
        tester,
        const AuthUser(
          uid: '1',
          email: 'e@mail.com',
          providerIds: ['password'],
        ),
      );
      await tester.tap(find.byKey(const Key('account-reset-password')));
      await tester.pumpAndSettle();
      expect(auth.resetEmail, 'e@mail.com');
      expect(find.byKey(const Key('account-message')), findsOneWidget);
    });

    testWidgets('edits and saves the display name', (tester) async {
      final auth = await openDialog(
        tester,
        const AuthUser(uid: '1', email: 'e@mail.com', displayName: 'Old'),
      );
      await tester.tap(find.byKey(const Key('account-edit-name')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('account-name-field')),
        'New Name',
      );
      await tester.tap(find.byKey(const Key('account-save-name')));
      await tester.pumpAndSettle();

      expect(auth.updatedName, 'New Name');
      expect(find.byKey(const Key('account-name')), findsOneWidget);
      expect(find.text('New Name'), findsOneWidget);
    });

    testWidgets('rejects an empty display name', (tester) async {
      final auth = await openDialog(
        tester,
        const AuthUser(uid: '1', email: 'e@mail.com', displayName: 'Old'),
      );
      await tester.tap(find.byKey(const Key('account-edit-name')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('account-name-field')), ' ');
      await tester.tap(find.byKey(const Key('account-save-name')));
      await tester.pumpAndSettle();

      expect(auth.updatedName, isNull);
      expect(find.text('กรุณากรอกชื่อ'), findsOneWidget);
    });
  });
}
