import 'package:flutter/material.dart';
import 'package:mnote/core/theme/app_theme.dart';

/// The light, soft palette used by the entry flow (splash, guide, login,
/// register) and a few branded widgets, derived from the chosen [AppAccent].
///
/// Blue keeps the exact original colors; other accents share the same
/// lightness/saturation recipe so every accent looks consistent.
@immutable
class BrandPalette extends ThemeExtension<BrandPalette> {
  const BrandPalette({
    required this.primary,
    required this.onPrimary,
    required this.primaryDisabled,
    required this.background,
    required this.splashBackground,
    required this.border,
    required this.mid,
    required this.soft,
    required this.softBorder,
    required this.headline,
  });

  /// Buttons, focus borders, badges.
  final Color primary;

  /// Text/icons drawn on top of [primary].
  final Color onPrimary;
  final Color primaryDisabled;

  /// Page background of the entry flow.
  final Color background;
  final Color splashBackground;

  /// Text field / outlined button borders.
  final Color border;

  /// Mid-tone accent for icons and active indicators.
  final Color mid;
  final Color soft;
  final Color softBorder;

  /// Strong title text tinted with the accent.
  final Color headline;

  static const BrandPalette _blue = BrandPalette(
    primary: Color(0xFF4A89DC),
    onPrimary: Colors.white,
    primaryDisabled: Color(0xFF9EBFDC),
    background: Color(0xFFEBF3FA),
    splashBackground: Color(0xFFB9D7F2),
    border: Color(0xFF9EBFDC),
    mid: Color(0xFF5B8CB9),
    soft: Color(0xFFDCE8F5),
    softBorder: Color(0xFFB0C7DE),
    headline: Color(0xFF1E3A5F),
  );

  factory BrandPalette.fromAccent(AppAccent accent) {
    if (accent == AppAccent.blue) return _blue;
    final hue = HSLColor.fromColor(accent.swatch).hue;
    Color tone(double saturation, double lightness) =>
        HSLColor.fromAHSL(1, hue, saturation, lightness).toColor();
    final primary = accent.swatch;
    final isLightPrimary =
        ThemeData.estimateBrightnessForColor(primary) == Brightness.light;
    return BrandPalette(
      primary: primary,
      onPrimary: isLightPrimary ? const Color(0xDD000000) : Colors.white,
      primaryDisabled: tone(0.45, 0.78),
      background: tone(0.55, 0.95),
      splashBackground: tone(0.65, 0.85),
      border: tone(0.45, 0.78),
      mid: tone(0.38, 0.5),
      soft: tone(0.55, 0.92),
      softBorder: tone(0.4, 0.8),
      headline: tone(0.5, 0.22),
    );
  }

  /// The palette of the current theme, or the default blue when the theme
  /// was not built through [AppTheme] (e.g. a bare `MaterialApp` in tests).
  static BrandPalette of(BuildContext context) =>
      Theme.of(context).extension<BrandPalette>() ?? _blue;

  @override
  BrandPalette copyWith({
    Color? primary,
    Color? onPrimary,
    Color? primaryDisabled,
    Color? background,
    Color? splashBackground,
    Color? border,
    Color? mid,
    Color? soft,
    Color? softBorder,
    Color? headline,
  }) {
    return BrandPalette(
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryDisabled: primaryDisabled ?? this.primaryDisabled,
      background: background ?? this.background,
      splashBackground: splashBackground ?? this.splashBackground,
      border: border ?? this.border,
      mid: mid ?? this.mid,
      soft: soft ?? this.soft,
      softBorder: softBorder ?? this.softBorder,
      headline: headline ?? this.headline,
    );
  }

  @override
  BrandPalette lerp(ThemeExtension<BrandPalette>? other, double t) {
    if (other is! BrandPalette) return this;
    return BrandPalette(
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      primaryDisabled: Color.lerp(primaryDisabled, other.primaryDisabled, t)!,
      background: Color.lerp(background, other.background, t)!,
      splashBackground: Color.lerp(
        splashBackground,
        other.splashBackground,
        t,
      )!,
      border: Color.lerp(border, other.border, t)!,
      mid: Color.lerp(mid, other.mid, t)!,
      soft: Color.lerp(soft, other.soft, t)!,
      softBorder: Color.lerp(softBorder, other.softBorder, t)!,
      headline: Color.lerp(headline, other.headline, t)!,
    );
  }
}
