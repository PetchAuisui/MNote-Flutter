import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnote/app/mnote_app.dart';
import 'package:mnote/core/theme/app_theme.dart';
import 'package:mnote/core/theme/theme_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  tearDown(() {
    ThemePreferences.resetForTesting();
    MnoteApp.themeModeNotifier.value = ThemeMode.system;
    MnoteApp.accentNotifier.value = AppAccent.blue;
  });

  group('ThemePreferences', () {
    test('falls back to defaults for missing or unknown values', () {
      expect(ThemePreferences.modeFromName(null), ThemeMode.system);
      expect(ThemePreferences.modeFromName('nope'), ThemeMode.system);
      expect(ThemePreferences.accentFromName(null), AppAccent.blue);
      expect(ThemePreferences.accentFromName('nope'), AppAccent.blue);
    });

    test('parses every stored name back to the same value', () {
      for (final mode in ThemeMode.values) {
        expect(ThemePreferences.modeFromName(mode.name), mode);
      }
      for (final accent in AppAccent.values) {
        expect(ThemePreferences.accentFromName(accent.name), accent);
      }
    });

    test('load() restores saved accent and mode', () async {
      SharedPreferences.setMockInitialValues({
        ThemePreferences.modeKey: 'dark',
        ThemePreferences.accentKey: 'pink',
      });

      await ThemePreferences.load();

      expect(MnoteApp.themeModeNotifier.value, ThemeMode.dark);
      expect(MnoteApp.accentNotifier.value, AppAccent.pink);
    });

    test('changes after load() are saved', () async {
      SharedPreferences.setMockInitialValues({});
      await ThemePreferences.load();

      MnoteApp.accentNotifier.value = AppAccent.orange;
      MnoteApp.themeModeNotifier.value = ThemeMode.light;
      await ThemePreferences.pendingSaves();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ThemePreferences.accentKey), 'orange');
      expect(prefs.getString(ThemePreferences.modeKey), 'light');
    });

    test('rapid consecutive changes are saved in order without race conditions', () async {
      SharedPreferences.setMockInitialValues({});
      await ThemePreferences.load();

      // Trigger multiple changes in rapid succession.
      MnoteApp.accentNotifier.value = AppAccent.orange;
      MnoteApp.accentNotifier.value = AppAccent.green;
      MnoteApp.accentNotifier.value = AppAccent.yellow;
      MnoteApp.accentNotifier.value = AppAccent.purple;

      await ThemePreferences.pendingSaves();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ThemePreferences.accentKey), AppAccent.purple.name);
    });

    test('resetForTesting() detaches listeners and prevents leaks across tests', () async {
      SharedPreferences.setMockInitialValues({});
      await ThemePreferences.load();
      expect(ThemePreferences.isPersisting, isTrue);

      ThemePreferences.resetForTesting();
      expect(ThemePreferences.isPersisting, isFalse);

      // Changes after reset must not trigger saves to SharedPreferences.
      MnoteApp.accentNotifier.value = AppAccent.red;
      MnoteApp.themeModeNotifier.value = ThemeMode.dark;
      await ThemePreferences.pendingSaves();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ThemePreferences.accentKey), isNull);
      expect(prefs.getString(ThemePreferences.modeKey), isNull);
    });
  });

  testWidgets('MnoteApp applies the chosen accent from the first page', (
    tester,
  ) async {
    MnoteApp.accentNotifier.value = AppAccent.green;
    await tester.pumpWidget(
      MnoteApp(home: Builder(builder: (_) => const SizedBox())),
    );

    final context = tester.element(find.byType(SizedBox));
    expect(
      Theme.of(context).colorScheme.primary,
      AppTheme.colorScheme(Brightness.light, accent: AppAccent.green).primary,
    );

    MnoteApp.accentNotifier.value = AppAccent.red;
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(SizedBox))).colorScheme.primary,
      AppTheme.colorScheme(Brightness.light, accent: AppAccent.red).primary,
    );
  });
}
