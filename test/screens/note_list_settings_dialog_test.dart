import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnote/app/mnote_app.dart';
import 'package:mnote/core/theme/app_theme.dart';
import 'package:mnote/features/sync/domain/sync_settings.dart';
import 'package:mnote/screens/widgets/note_list_settings_dialog.dart';

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

  group('cloud sync section', () {
    Future<void> openWith(WidgetTester tester, SyncSettings? settings) async {
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
                  builder: (_) =>
                      NoteListSettingsDialog(syncSettings: settings),
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

    testWidgets('switches and size limit update the settings', (tester) async {
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

      await tester.tap(find.byKey(const Key('sync-limit-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('100 KB').last);
      await tester.pumpAndSettle();
      expect(settings.maxContentBytes, 100 * 1024);

      await tester.tap(find.byKey(const Key('sync-enabled-switch')));
      await tester.pumpAndSettle();
      expect(settings.enabled, isFalse);
      // The dependent controls are disabled with the master switch.
      final ink = tester.widget<SwitchListTile>(
        find.byKey(const Key('sync-ink-switch')),
      );
      expect(ink.onChanged, isNull);
    });
  });
}
