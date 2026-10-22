import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnote/core/theme/brand_palette.dart';

enum AppFontFamily {
  prompt('Prompt (โมเดิร์น)', 'Prompt'),
  sarabun('Sarabun (ทางการ)', 'Sarabun'),
  kanit('Kanit (มินิมอล)', 'Kanit'),
  notoSansThai('Noto Sans (สากล)', 'Noto Sans Thai');

  final String label;
  final String familyName;
  const AppFontFamily(this.label, this.familyName);
}

/// App accent colors the user can pick from in Settings.
///
/// [seed] drives the Material 3 [ColorScheme]; [swatch] is the vivid color
/// shown in the picker.
enum AppAccent {
  blue('ฟ้า', AppTheme.primarySeed, Color(0xFF4A89DC)),
  purple('ม่วง', Color(0xFF7E57C2), Color(0xFF7E57C2)),
  green('เขียว', Color(0xFF43A047), Color(0xFF43A047)),
  red('แดง', Color(0xFFE53935), Color(0xFFE53935)),
  yellow('เหลือง', Color(0xFFFBC02D), Color(0xFFFBC02D)),
  pink('ชมพู', Color(0xFFEC407A), Color(0xFFEC407A)),
  orange('ส้ม', Color(0xFFFB8C00), Color(0xFFFB8C00));

  final String label;
  final Color seed;
  final Color swatch;
  const AppAccent(this.label, this.seed, this.swatch);
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

  static ColorScheme colorScheme(
    Brightness brightness, {
    AppAccent accent = AppAccent.blue,
  }) {
    final isDark = brightness == Brightness.dark;
    final isLightPrimary =
        ThemeData.estimateBrightnessForColor(accent.swatch) == Brightness.light;

    // In light mode, yellow's seed produces a dull olive-brown tone 40 primary.
    // We override it with the vivid swatch so ColorScheme and BrandPalette match.
    final Color? primaryOverride = (accent == AppAccent.yellow && !isDark)
        ? accent.swatch
        : null;
    final Color? onPrimaryOverride = (accent == AppAccent.yellow && !isDark)
        ? (isLightPrimary ? const Color(0xDD000000) : Colors.white)
        : null;

    return ColorScheme.fromSeed(
      seedColor: accent.seed,
      brightness: brightness,
      primary: primaryOverride,
      onPrimary: onPrimaryOverride,
      secondary: isDark ? const Color(0xFFC1C6DA) : const Color(0xFF595E6F),
      secondaryContainer: isDark
          ? const Color(0xFF414657)
          : const Color(0xFFDDE2F7),
      onSecondaryContainer: isDark
          ? const Color(0xFFDDE2F7)
          : const Color(0xFF161B2B),
      tertiary: isDark ? const Color(0xFFB2C9E2) : const Color(0xFF4B6077),
      tertiaryContainer: isDark
          ? const Color(0xFF33495E)
          : const Color(0xFFCEE5FF),
      onTertiaryContainer: isDark
          ? const Color(0xFFCEE5FF)
          : const Color(0xFF041D32),
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
      bodyLarge: textTheme.bodyLarge?.copyWith(height: 1.5, letterSpacing: 0.1),
      bodyMedium: textTheme.bodyMedium?.copyWith(
        height: 1.45,
        letterSpacing: 0.1,
      ),
      bodySmall: textTheme.bodySmall?.copyWith(height: 1.4, letterSpacing: 0.1),
      labelLarge: textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
  }

  static ThemeData theme(
    Brightness brightness, {
    AppFontFamily font = AppFontFamily.prompt,
    AppAccent accent = AppAccent.blue,
  }) {
    final scheme = colorScheme(brightness, accent: accent);
    final textTheme = _createTextTheme(brightness, font);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      extensions: [BrandPalette.fromAccent(accent, brightness: brightness)],
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
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        color: scheme.surfaceContainerHigh,
      ),
    );
  }
}
