import 'package:flutter/material.dart';

abstract final class AppTheme {
  /// Core colors from the Material Theme Builder design palette.
  static const primarySeed = Color(0xFF9CB6FF);
  static const secondarySeed = Color(0xFF8B90A3);
  static const tertiarySeed = Color(0xFF7D93AB);
  static const errorSeed = Color(0xFFFF5449);
  static const neutralSeed = Color(0xFF919095);

  /// Backward compatible alias for the primary seed color.
  static const seedColor = primarySeed;

  static ThemeData get light => _theme(Brightness.light);

  static ThemeData get dark => _theme(Brightness.dark);

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

  static ThemeData _theme(Brightness brightness) {
    final scheme = colorScheme(brightness);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surfaceContainerLowest,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
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
