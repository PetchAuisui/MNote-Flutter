import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnote/core/theme/app_theme.dart';

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
  });
}
