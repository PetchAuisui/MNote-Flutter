import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnote/app/mnote_app.dart';
import 'package:mnote/core/theme/app_theme.dart';
import 'package:mnote/core/theme/brand_palette.dart';
import 'package:mnote/features/auth/presentation/app_guide_page.dart';
import 'package:mnote/features/auth/presentation/splash_page.dart';

import '../../../helpers/fakes.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  tearDown(() {
    MnoteApp.accentNotifier.value = AppAccent.blue;
  });

  group('BrandPalette', () {
    test('blue keeps the original entry-flow colors', () {
      final p = BrandPalette.fromAccent(AppAccent.blue);
      expect(p.primary, const Color(0xFF4A89DC));
      expect(p.background, const Color(0xFFEBF3FA));
      expect(p.splashBackground, const Color(0xFFB9D7F2));
    });

    test('every accent gets its own primary and background', () {
      final palettes = AppAccent.values.map(BrandPalette.fromAccent).toList();
      expect(palettes.map((p) => p.primary).toSet().length, 7);
      expect(palettes.map((p) => p.background).toSet().length, 7);
    });

    test('light accents (yellow) get dark text for contrast', () {
      expect(
        BrandPalette.fromAccent(AppAccent.yellow).onPrimary,
        isNot(Colors.white),
      );
      expect(BrandPalette.fromAccent(AppAccent.purple).onPrimary, Colors.white);
    });

    test('AppTheme registers a palette for every accent', () {
      for (final accent in AppAccent.values) {
        final theme = AppTheme.theme(Brightness.light, accent: accent);
        expect(
          theme.extension<BrandPalette>()!.primary,
          BrandPalette.fromAccent(accent).primary,
        );
      }
    });

    test('supports dark mode with dark background and light headline', () {
      for (final accent in AppAccent.values) {
        final darkPalette = BrandPalette.fromAccent(
          accent,
          brightness: Brightness.dark,
        );
        expect(
          ThemeData.estimateBrightnessForColor(darkPalette.background),
          Brightness.dark,
        );
        expect(
          ThemeData.estimateBrightnessForColor(darkPalette.headline),
          Brightness.light,
        );
      }
    });

    test('AppTheme dark mode registers a dark BrandPalette', () {
      final theme = AppTheme.theme(Brightness.dark, accent: AppAccent.blue);
      final palette = theme.extension<BrandPalette>()!;
      expect(
        ThemeData.estimateBrightnessForColor(palette.background),
        Brightness.dark,
      );
    });
  });

  testWidgets('splash background uses the saved accent from the first frame', (
    tester,
  ) async {
    MnoteApp.accentNotifier.value = AppAccent.green;
    await tester.pumpWidget(
      MnoteApp(home: SplashPage(repository: FakeDocumentRepository())),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(
      scaffold.backgroundColor,
      BrandPalette.fromAccent(AppAccent.green).splashBackground,
    );
    // Let the splash timer finish so no timer is left pending.
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  testWidgets('guide page recolors live when the accent changes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MnoteApp(
        home: AppGuidePage(
          repository: FakeDocumentRepository(),
          nextPage: const SizedBox(),
        ),
      ),
    );
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      BrandPalette.fromAccent(AppAccent.blue).background,
    );

    MnoteApp.accentNotifier.value = AppAccent.pink;
    await tester.pumpAndSettle();

    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      BrandPalette.fromAccent(AppAccent.pink).background,
    );
  });
}
