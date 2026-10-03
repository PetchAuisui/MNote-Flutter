import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppFontFamily {
  prompt('Prompt (โมเดิร์น)', 'Prompt'),
  sarabun('Sarabun (ทางการ)', 'Sarabun'),
  kanit('Kanit (มินิมอล)', 'Kanit'),
  notoSansThai('Noto Sans (สากล)', 'Noto Sans Thai');

  final String label;
  final String familyName;
  const AppFontFamily(this.label, this.familyName);
}

abstract final class AppTheme {
  /// Core colors from the Material Theme Builder design palette.
  static const primarySeed = Color(0xFF9CB6FF);
  static const secondarySeed = Color(0xFF8B90A3);
  static const tertiarySeed = Color(0xFF7D93AB);
  static const errorSeed = Color(0xFFFF5449);
  static const neutralSeed = Color(0xFF919095);

  /// Backward compatible alias for the primary seed color.
  static const seedColor = primarySeed;

  static ThemeData get light => theme(Brightness.light);

  static ThemeData get dark => theme(Brightness.dark);

  static ColorScheme colorScheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ColorScheme.fromSeed(
      seedColor: primarySeed,
      brightness: brightness,
      secondary: isDark ? const Color(0xFFC1C6DA) : const Color(0xFF595E6F),
      secondaryContainer:
          isDark ? const Color(0xFF414657) : const Color(0xFFDDE2F7),
      onSecondaryContainer:
          isDark ? const Color(0xFFDDE2F7) : const Color(0xFF161B2B),
      tertiary: isDark ? const Color(0xFFB2C9E2) : const Color(0xFF4B6077),
      tertiaryContainer:
          isDark ? const Color(0xFF33495E) : const Color(0xFFCEE5FF),
      onTertiaryContainer:
          isDark ? const Color(0xFFCEE5FF) : const Color(0xFF041D32),
      error: isDark ? const Color(0xFFFFB4AB) : const Color(0xFFBA1A1A),
    );
  }

  static TextTheme _createTextTheme(Brightness brightness, AppFontFamily font) {
    GoogleFonts.config.allowRuntimeFetching = false;
    final base = ThemeData(brightness: brightness).textTheme;
    final TextTheme textTheme;
    switch (font) {
      case AppFontFamily.prompt:
        textTheme = GoogleFonts.promptTextTheme(base);
        break;
      case AppFontFamily.sarabun:
        textTheme = GoogleFonts.sarabunTextTheme(base);
        break;
      case AppFontFamily.kanit:
        textTheme = GoogleFonts.kanitTextTheme(base);
        break;
      case AppFontFamily.notoSansThai:
        textTheme = GoogleFonts.notoSansThaiTextTheme(base);
        break;
    }
    return textTheme.copyWith(
      headlineLarge: textTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
        height: 1.3,
      ),
      headlineMedium: textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.bold,
        letterSpacing: -0.4,
        height: 1.3,
      ),
      headlineSmall: textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.bold,
        letterSpacing: -0.3,
        height: 1.3,
      ),
      titleLarge: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
        letterSpacing: -0.3,
        height: 1.3,
      ),
      titleMedium: textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.35,
      ),
      titleSmall: textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        height: 1.35,
      ),
      bodyLarge: textTheme.bodyLarge?.copyWith(
        height: 1.5,
        letterSpacing: 0.1,
      ),
      bodyMedium: textTheme.bodyMedium?.copyWith(
        height: 1.45,
        letterSpacing: 0.1,
      ),
      bodySmall: textTheme.bodySmall?.copyWith(
        height: 1.4,
        letterSpacing: 0.1,
      ),
      labelLarge: textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
  }

  static ThemeData theme(
    Brightness brightness, {
    AppFontFamily font = AppFontFamily.prompt,
  }) {
    final scheme = colorScheme(brightness);
    final textTheme = _createTextTheme(brightness, font);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      fontFamily: font.familyName,
      scaffoldBackgroundColor: scheme.surfaceContainerLowest,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
