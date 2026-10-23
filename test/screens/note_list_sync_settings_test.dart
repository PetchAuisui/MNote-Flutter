import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/auth/domain/auth_user.dart';
import 'package:mnote/features/auth/presentation/auth_page.dart';
import 'package:mnote/models/note_item.dart';
import 'package:mnote/screens/note_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_auth_repository.dart';
import '../helpers/fake_syncable_repository.dart';

void main() {
  late FakeSyncableRepository repo;

  DocumentItem note() => DocumentItem(
    id: 'n1',
    name: 'Notes.md',
    content: 'hello',
    updatedAt: DateTime(2026),
    uri: Uri.file('/tmp/Notes.md'),
  );

  Future<void> pump(WidgetTester tester, {FakeAuthRepository? auth}) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'mnote_welcome_removed': true});
    repo = FakeSyncableRepository()
      ..storedMetadata = LibraryMetadata(documents: [note()]);
    await tester.pumpWidget(
      MaterialApp(
        home: NoteListScreen(repository: repo, authRepository: auth),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a note can be set to never sync from its menu', (tester) async {
    await pump(tester);

    await tester.longPress(find.text('Notes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ตั้งค่าการซิงก์'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sync-mode-auto')), findsOneWidget);
    expect(find.byKey(const ValueKey('sync-mode-always')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('sync-mode-never')));
    await tester.pumpAndSettle();

    final saved = (await repo.loadMetadata())!.documents.single;
    expect(saved.syncMode, SyncMode.never);
    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
  });

  // SharedPreferences needs real async time, which fake-async tests skip.
  Future<void> letPreferencesFinish(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  Future<FakeAuthRepository> startSignOut(WidgetTester tester) async {
    final auth = FakeAuthRepository(
      currentUser: const AuthUser(uid: 'u1', email: 'a@b.c', displayName: 'A'),
    );
    await pump(tester, auth: auth);
    repo.unsynced = 2;
    await tester.tap(find.byTooltip('การตั้งค่า (Settings)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-sign-out')));
    await tester.pumpAndSettle();
    expect(find.text('มีไฟล์ที่ไม่ได้ซิงก์'), findsOneWidget);
    return auth;
  }

  testWidgets('cancelling the sign-out warning keeps the user signed in', (
    tester,
  ) async {
    final auth = await startSignOut(tester);

    await tester.tap(find.text('ยกเลิก').last);
    await tester.pumpAndSettle();

    expect(auth.currentUser, isNotNull);
    expect(find.byType(AuthPage), findsNothing);
  });

  testWidgets('confirming the sign-out warning signs out', (tester) async {
    final auth = await startSignOut(tester);

    await tester.tap(find.text('ออกจากระบบและลบ'));
    await letPreferencesFinish(tester);

    expect(auth.currentUser, isNull);
    expect(find.byType(AuthPage), findsOneWidget);
  });

  testWidgets('no warning when everything is synced', (tester) async {
    final auth = FakeAuthRepository(
      currentUser: const AuthUser(uid: 'u1', email: 'a@b.c', displayName: 'A'),
    );
    await pump(tester, auth: auth);

    await tester.tap(find.byTooltip('การตั้งค่า (Settings)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-sign-out')));
    await letPreferencesFinish(tester);

    expect(find.text('มีไฟล์ที่ไม่ได้ซิงก์'), findsNothing);
    expect(auth.currentUser, isNull);
  });
}
