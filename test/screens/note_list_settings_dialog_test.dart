import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnote/app/mnote_app.dart';
import 'package:mnote/core/theme/app_theme.dart';
import 'package:mnote/features/auth/domain/auth_user.dart';
import 'package:mnote/features/sync/domain/sync_settings.dart';
import 'package:mnote/screens/widgets/note_list_settings_dialog.dart';

import '../helpers/fake_auth_repository.dart';
import '../helpers/fake_syncable_repository.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  tearDown(() {
    MnoteApp.themeModeNotifier.value = ThemeMode.system;
    MnoteApp.accentNotifier.value = AppAccent.blue;
  });

  Future<void> openSettings(WidgetTester tester) async {
    await tester.pumpWidget(
      MnoteApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const NoteListSettingsDialog(),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows all 7 accent colors in the settings dialog', (
    tester,
  ) async {
    await openSettings(tester);

    expect(find.text('สีของแอป (Accent)'), findsOneWidget);
    for (final accent in AppAccent.values) {
      expect(find.byKey(ValueKey('accent_${accent.name}')), findsOneWidget);
    }
    // Theme mode selector is still there, separate from the accent picker.
    expect(find.text('ตามเครื่อง'), findsOneWidget);
    expect(find.text('สว่าง'), findsOneWidget);
    expect(find.text('มืด'), findsOneWidget);
  });

  testWidgets('tapping a swatch changes the app accent live', (tester) async {
    await openSettings(tester);
    expect(MnoteApp.accentNotifier.value, AppAccent.blue);

    await tester.tap(find.byKey(const ValueKey('accent_purple')));
    await tester.pumpAndSettle();

    expect(MnoteApp.accentNotifier.value, AppAccent.purple);
    final context = tester.element(find.byType(NoteListSettingsDialog));
    expect(
      Theme.of(context).colorScheme.primary,
      AppTheme.colorScheme(Brightness.light, accent: AppAccent.purple).primary,
    );
  });

  testWidgets('selected swatch shows a check mark', (tester) async {
    await openSettings(tester);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('accent_orange')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('accent_orange')),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('light swatch (yellow) uses dark check icon for high contrast', (
    tester,
  ) async {
    await openSettings(tester);
    await tester.tap(find.byKey(const ValueKey('accent_yellow')));
    await tester.pumpAndSettle();

    final icon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const ValueKey('accent_yellow')),
        matching: find.byIcon(Icons.check_rounded),
      ),
    );
    expect(icon.color, const Color(0xDD000000));
  });

  testWidgets('dark swatch (purple) uses white check icon for high contrast', (
    tester,
  ) async {
    await openSettings(tester);
    await tester.tap(find.byKey(const ValueKey('accent_purple')));
    await tester.pumpAndSettle();

    final icon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const ValueKey('accent_purple')),
        matching: find.byIcon(Icons.check_rounded),
      ),
    );
    expect(icon.color, Colors.white);
  });

  testWidgets('theme mode labels stay on one line on a phone', (tester) async {
    tester.view.physicalSize = const Size(392, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await openSettings(tester);

    expect(tester.takeException(), isNull);
    for (final label in ['ตามเครื่อง', 'สว่าง', 'มืด']) {
      // A wrapped label is taller than one 14sp line.
      expect(
        tester.getSize(find.text(label)).height,
        lessThan(24),
        reason: label,
      );
    }
  });

  group('account section', () {
    Future<void> openWith(
      WidgetTester tester,
      FakeAuthRepository? auth, {
      required void Function(String) onDelete,
      required VoidCallback onSignOut,
    }) async {
      tester.view.physicalSize = const Size(600, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MnoteApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => NoteListSettingsDialog(
                    authRepository: auth,
                    onSignOut: () async => onSignOut(),
                    onDeleteAccount: (p) async => onDelete(p),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('is hidden when signed out', (tester) async {
      await openWith(
        tester,
        FakeAuthRepository(),
        onDelete: (_) {},
        onSignOut: () {},
      );
      expect(find.text('บัญชี (Account)'), findsNothing);
    });

    testWidgets('shows the user and signs out', (tester) async {
      var signedOut = 0;
      await openWith(
        tester,
        FakeAuthRepository(
          currentUser: const AuthUser(
            uid: '1',
            email: 'pet@mail.com',
            displayName: 'Pet',
          ),
        ),
        onDelete: (_) {},
        onSignOut: () => signedOut++,
      );
      expect(find.text('Pet'), findsOneWidget);
      expect(find.text('pet@mail.com'), findsOneWidget);
      await tester.tap(find.byKey(const Key('settings-sign-out')));
      await tester.pumpAndSettle();
      expect(signedOut, 1);
      expect(find.byType(NoteListSettingsDialog), findsNothing);
    });

    testWidgets('email account must type its password to delete', (
      tester,
    ) async {
      String? deleted;
      await openWith(
        tester,
        FakeAuthRepository(
          currentUser: const AuthUser(
            uid: '1',
            email: 'pet@mail.com',
            providerIds: ['password'],
          ),
        ),
        onDelete: (p) => deleted = p,
        onSignOut: () {},
      );
      await tester.tap(find.byKey(const Key('settings-account-tile')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('account-delete')));
      await tester.pumpAndSettle();
      TextButton confirm() => tester.widget<TextButton>(
        find.byKey(const Key('delete-account-confirm')),
      );
      expect(confirm().onPressed, isNull);
      await tester.enterText(
        find.byKey(const Key('delete-account-password')),
        'secret1',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('delete-account-confirm')));
      await tester.pumpAndSettle();
      expect(deleted, 'secret1');
      expect(find.byType(NoteListSettingsDialog), findsNothing);
    });

    testWidgets('Google account confirms without a password', (tester) async {
      String? deleted;
      await openWith(
        tester,
        FakeAuthRepository(
          currentUser: const AuthUser(
            uid: '1',
            email: 'g@mail.com',
            providerIds: ['google.com'],
          ),
        ),
        onDelete: (p) => deleted = p,
        onSignOut: () {},
      );
      await tester.tap(find.byKey(const Key('settings-account-tile')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('account-delete')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('delete-account-password')), findsNothing);
      await tester.tap(find.byKey(const Key('delete-account-confirm')));
      await tester.pumpAndSettle();
      expect(deleted, '');
    });
  });

  group('cloud sync section', () {
    Future<void> openWith(
      WidgetTester tester,
      SyncSettings? settings, {
      FakeSyncableRepository? repository,
    }) async {
      tester.view.physicalSize = const Size(600, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MnoteApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => NoteListSettingsDialog(
                    syncSettings: settings,
                    syncRepository: repository,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('is hidden without sync settings', (tester) async {
      await openWith(tester, null);
      expect(find.text('ซิงก์กับบัญชี (Cloud sync)'), findsNothing);
    });

    testWidgets('Wi-Fi only switch updates the settings', (tester) async {
      final settings = SyncSettings();
      await openWith(tester, settings);
      await tester.scrollUntilVisible(
        find.byKey(const Key('sync-wifi-only-switch')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('sync-wifi-only-switch')));
      await tester.pumpAndSettle();
      expect(settings.wifiOnly, isTrue);
    });

    testWidgets('shows the last sync and syncs on demand', (tester) async {
      final settings = SyncSettings();
      final repo = FakeSyncableRepository(settings: settings);
      await openWith(tester, settings, repository: repo);
      await tester.scrollUntilVisible(
        find.byKey(const Key('sync-status-tile')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('ยังไม่ได้ซิงก์ในรอบนี้'), findsOneWidget);

      await tester.tap(find.byKey(const Key('sync-now-button')));
      await tester.pumpAndSettle();

      expect(repo.syncNowCalls, 1);
      expect(find.text('ซิงก์ล่าสุด: เมื่อสักครู่'), findsOneWidget);
    });

    testWidgets('a failed sync now tells the user', (tester) async {
      final settings = SyncSettings();
      final repo = FakeSyncableRepository(settings: settings)
        ..syncNowResult = false;
      await openWith(tester, settings, repository: repo);
      await tester.scrollUntilVisible(
        find.byKey(const Key('sync-now-button')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('sync-now-button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('ซิงก์ไม่สำเร็จ'), findsOneWidget);
    });

    testWidgets('sync now is disabled while sync is off', (tester) async {
      final settings = SyncSettings()..enabled = false;
      final repo = FakeSyncableRepository(settings: settings);
      await openWith(tester, settings, repository: repo);
      await tester.scrollUntilVisible(
        find.byKey(const Key('sync-now-button')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      final button = tester.widget<TextButton>(
        find.byKey(const Key('sync-now-button')),
      );
      expect(button.onPressed, isNull);
      expect(find.text('ปิดการซิงก์อยู่'), findsOneWidget);
    });

    testWidgets('switches update the settings', (tester) async {
      final settings = SyncSettings();
      await openWith(tester, settings);
      await tester.scrollUntilVisible(
        find.byKey(const Key('sync-enabled-switch')),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.tap(find.byKey(const Key('sync-ink-switch')));
      await tester.pumpAndSettle();
      expect(settings.syncInk, isFalse);

      await tester.tap(find.byKey(const Key('sync-enabled-switch')));
      await tester.pumpAndSettle();
      expect(settings.enabled, isFalse);
      expect(find.byKey(const Key('sync-limit-dropdown')), findsNothing);
      // The dependent controls are disabled with the master switch.
      final ink = tester.widget<SwitchListTile>(
        find.byKey(const Key('sync-ink-switch')),
      );
      expect(ink.onChanged, isNull);
    });
  });

  for (final width in [320.0, 392.0, 600.0, 1000.0]) {
    testWidgets('accent colors share one row at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await openSettings(tester);

      final ys = {
        for (final accent in AppAccent.values)
          tester.getCenter(find.byKey(ValueKey('accent_${accent.name}'))).dy,
      };
      expect(ys, hasLength(1), reason: 'all swatches on a single row');
      final sizes = {
        for (final accent in AppAccent.values)
          tester.getSize(find.byKey(ValueKey('accent_${accent.name}'))).width,
      };
      expect(sizes, hasLength(1), reason: 'swatches stay the same size');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('accent swatches have a gap between them on a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await openSettings(tester);

    final rects = [
      for (final accent in AppAccent.values)
        tester.getRect(find.byKey(ValueKey('accent_${accent.name}'))),
    ];
    for (var i = 0; i < rects.length - 1; i++) {
      expect(
        rects[i + 1].left - rects[i].right,
        greaterThanOrEqualTo(4),
        reason: 'swatch $i touches the next one',
      );
    }
  });

  testWidgets('theme labels share one size even with a large system font', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 1600);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await openSettings(tester);

    final heights = {
      for (final label in ['ตามเครื่อง', 'สว่าง', 'มืด'])
        tester.getSize(find.text(label)).height,
    };
    expect(heights, hasLength(1), reason: 'labels render at different sizes');
    expect(heights.single, lessThan(24));
    // Icons make way for the labels on a narrow phone.
    expect(find.byIcon(Icons.brightness_auto_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
