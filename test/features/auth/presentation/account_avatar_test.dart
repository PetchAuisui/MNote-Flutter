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
}
