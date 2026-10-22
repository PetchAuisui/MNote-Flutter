import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnote/app/mnote_app.dart';
import 'package:mnote/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('AppTheme', () {
    test('defines the core colors matching Material Theme Builder', () {
      expect(AppTheme.primarySeed, const Color(0xFF9CB6FF));
      expect(AppTheme.secondarySeed, const Color(0xFF8B90A3));
      expect(AppTheme.tertiarySeed, const Color(0xFF7D93AB));
      expect(AppTheme.errorSeed, const Color(0xFFFF5449));
      expect(AppTheme.neutralSeed, const Color(0xFF919095));
      expect(AppTheme.seedColor, AppTheme.primarySeed);
    });

    test('builds light ThemeData with Material 3 and custom colors', () {
      final theme = AppTheme.light;
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.brightness, Brightness.light);
      expect(
        theme.scaffoldBackgroundColor,
        theme.colorScheme.surfaceContainerLowest,
      );
      expect(theme.cardTheme.color, theme.colorScheme.surfaceContainerLow);
      expect(
        theme.inputDecorationTheme.fillColor,
        theme.colorScheme.surfaceContainerLowest,
      );
    });

    test('builds dark ThemeData with Material 3 and custom colors', () {
      final theme = AppTheme.dark;
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(
        theme.scaffoldBackgroundColor,
        theme.colorScheme.surfaceContainerLowest,
      );
      expect(theme.cardTheme.color, theme.colorScheme.surfaceContainerLow);
      expect(
        theme.inputDecorationTheme.fillColor,
        theme.colorScheme.surfaceContainerLowest,
      );
    });

    test('offers exactly 7 accent colors in the requested order', () {
      expect(AppAccent.values.map((a) => a.label), [
        'ฟ้า',
        'ม่วง',
        'เขียว',
        'แดง',
        'เหลือง',
        'ชมพู',
        'ส้ม',
      ]);
    });

    test('blue accent keeps the original default palette', () {
      expect(
        AppTheme.colorScheme(Brightness.light, accent: AppAccent.blue),
        AppTheme.colorScheme(Brightness.light),
      );
    });

    test('every accent produces a distinct primary color in both modes', () {
      for (final brightness in Brightness.values) {
        final primaries = AppAccent.values
            .map((a) => AppTheme.colorScheme(brightness, accent: a).primary)
            .toSet();
        expect(primaries.length, AppAccent.values.length);
      }
    });

    test('theme() applies the chosen accent to the color scheme', () {
      final theme = AppTheme.theme(Brightness.light, accent: AppAccent.green);
      expect(
        theme.colorScheme.primary,
        AppTheme.colorScheme(Brightness.light, accent: AppAccent.green).primary,
      );
    });

    test(
      'yellow accent produces vivid primary matching swatch in light mode',
      () {
        final scheme = AppTheme.colorScheme(
          Brightness.light,
          accent: AppAccent.yellow,
        );
        expect(scheme.primary, AppAccent.yellow.swatch);
        expect(scheme.onPrimary, const Color(0xDD000000));
      },
    );

    test('all accents preserve hand-tuned secondary and tertiary colors', () {
      for (final accent in AppAccent.values) {
        final lightScheme = AppTheme.colorScheme(
          Brightness.light,
          accent: accent,
        );
        final darkScheme = AppTheme.colorScheme(
          Brightness.dark,
          accent: accent,
        );
        expect(lightScheme.secondary, const Color(0xFF595E6F));
        expect(darkScheme.secondary, const Color(0xFFC1C6DA));
        expect(lightScheme.tertiary, const Color(0xFF4B6077));
        expect(darkScheme.tertiary, const Color(0xFFB2C9E2));
      }
    });
  });

  group('Theme Persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      MnoteApp.themeModeNotifier.value = ThemeMode.system;
    });

    test(
      'loadThemeMode loads saved theme mode from SharedPreferences',
      () async {
        SharedPreferences.setMockInitialValues({'mnote_theme_mode': 'dark'});
        await MnoteApp.loadThemeMode();
        expect(MnoteApp.themeModeNotifier.value, ThemeMode.dark);

        SharedPreferences.setMockInitialValues({'mnote_theme_mode': 'light'});
        await MnoteApp.loadThemeMode();
        expect(MnoteApp.themeModeNotifier.value, ThemeMode.light);

        SharedPreferences.setMockInitialValues({'mnote_theme_mode': 'system'});
        await MnoteApp.loadThemeMode();
        expect(MnoteApp.themeModeNotifier.value, ThemeMode.system);
      },
    );

    test(
      'loadThemeMode defaults to system when saved value is unknown or absent',
      () async {
        SharedPreferences.setMockInitialValues({
          'mnote_theme_mode': 'unknown_mode',
        });
        await MnoteApp.loadThemeMode();
        expect(MnoteApp.themeModeNotifier.value, ThemeMode.system);

        SharedPreferences.setMockInitialValues({});
        await MnoteApp.loadThemeMode();
        expect(MnoteApp.themeModeNotifier.value, ThemeMode.system);
      },
    );

    test(
      'setThemeMode updates notifier and persists value to SharedPreferences',
      () async {
        await MnoteApp.setThemeMode(ThemeMode.dark);
        expect(MnoteApp.themeModeNotifier.value, ThemeMode.dark);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('mnote_theme_mode'), 'dark');

        await MnoteApp.setThemeMode(ThemeMode.light);
        expect(MnoteApp.themeModeNotifier.value, ThemeMode.light);
        expect(prefs.getString('mnote_theme_mode'), 'light');
      },
    );
  });
}
