import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnote/app/mnote_app.dart';
import 'package:mnote/core/theme/app_theme.dart';
import 'package:mnote/features/auth/domain/auth_user.dart';
import 'package:mnote/features/auth/presentation/login_page.dart';
import 'package:mnote/features/auth/presentation/register_page.dart';
import 'package:mnote/l10n/app_localizations_en.dart';
import 'package:mnote/l10n/app_localizations_th.dart';
import 'package:mnote/l10n/l10n.dart';
import 'package:mnote/l10n/language_preferences.dart';
import 'package:mnote/screens/widgets/note_list_settings_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_auth_repository.dart';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  tearDown(() => MnoteApp.languageNotifier.value = AppLanguage.system);

  group('translation files', () {
    Map<String, dynamic> read(String name) =>
        jsonDecode(File('lib/l10n/$name').readAsStringSync())
            as Map<String, dynamic>;

    test('Thai and English define exactly the same strings', () {
      Set<String> keys(Map<String, dynamic> arb) =>
          arb.keys.where((k) => !k.startsWith('@')).toSet();
      expect(keys(read('app_en.arb')), keys(read('app_th.arb')));
    });

    test('no string is empty', () {
      for (final name in ['app_th.arb', 'app_en.arb']) {
        for (final e in read(name).entries) {
          if (e.key.startsWith('@')) continue;
          expect((e.value as String).trim(), isNotEmpty, reason: e.key);
        }
      }
    });

    test('English strings contain no Thai text', () {
      for (final e in read('app_en.arb').entries) {
        if (e.key.startsWith('@') || e.key == 'languageThai') continue;
        expect(
          RegExp('[฀-๿]').hasMatch(e.value as String),
          isFalse,
          reason: e.key,
        );
      }
    });
  });

  group('helpers', () {
    test('dates use the Buddhist year in Thai', () {
      expect(
        AppLocalizationsTh().shortDate(DateTime(2026, 3, 5)),
        '5 มี.ค. 2569',
      );
      expect(
        AppLocalizationsEn().shortDate(DateTime(2026, 3, 5)),
        'Mar 5, 2026',
      );
    });

    test('every accent color has a name in both languages', () {
      for (final accent in AppAccent.values) {
        expect(AppLocalizationsTh().accentLabel(accent), accent.label);
        expect(AppLocalizationsEn().accentLabel(accent), isNotEmpty);
      }
    });

    test('time ago reads naturally in both languages', () {
      final now = DateTime(2026, 1, 1, 12);
      expect(
        AppLocalizationsEn().timeAgo(
          now.subtract(const Duration(minutes: 5)),
          now,
        ),
        '5 min ago',
      );
      expect(
        AppLocalizationsTh().timeAgo(
          now.subtract(const Duration(hours: 2)),
          now,
        ),
        '2 ชั่วโมงที่แล้ว',
      );
    });
  });

  group('LanguagePreferences', () {
    test('the choice is saved and restored', () async {
      await LanguagePreferences.set(AppLanguage.english);
      expect(MnoteApp.languageNotifier.value, AppLanguage.english);

      MnoteApp.languageNotifier.value = AppLanguage.system;
      await LanguagePreferences.load();
      expect(MnoteApp.languageNotifier.value, AppLanguage.english);
    });

    test('an unknown saved value follows the device', () async {
      SharedPreferences.setMockInitialValues({
        LanguagePreferences.key: 'klingon',
      });
      await LanguagePreferences.load();
      expect(MnoteApp.languageNotifier.value, AppLanguage.system);
    });
  });

  group('in the app', () {
    Widget app({Widget? home}) =>
        MnoteApp(home: home ?? const Scaffold(body: Text('home')));

    testWidgets('follows the device language', (tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
      await tester.pumpWidget(
        app(
          home: Builder(
            builder: (context) => Scaffold(body: Text(context.l10n.login)),
          ),
        ),
      );
      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets('shows Thai when the device language is not supported', (
      tester,
    ) async {
      tester.platformDispatcher.localesTestValue = const [Locale('ja', 'JP')];
      await tester.pumpWidget(
        app(
          home: Builder(
            builder: (context) => Scaffold(body: Text(context.l10n.login)),
          ),
        ),
      );
      expect(find.text('เข้าสู่ระบบ'), findsOneWidget);
    });

    testWidgets('the settings switch changes the whole app live', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(600, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        app(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => NoteListSettingsDialog(
                    authRepository: FakeAuthRepository(
                      currentUser: const AuthUser(uid: '1', email: 'a@b.c'),
                    ),
                    onSignOut: () async {},
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
      expect(find.text('การตั้งค่า'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('language-selector')),
          matching: find.text('English'),
        ),
      );
      await tester.pumpAndSettle();

      expect(MnoteApp.languageNotifier.value, AppLanguage.english);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('การตั้งค่า'), findsNothing);
      expect(find.text('Sign out'), findsOneWidget);
      expect(find.text('Cloud sync'), findsNothing); // sync needs a repository
      expect(find.text('Editor'), findsOneWidget);
    });
  });

  group('sign-in pages in English', () {
    Future<void> pump(WidgetTester tester, Widget page) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      MnoteApp.languageNotifier.value = AppLanguage.english;
      await tester.pumpWidget(MnoteApp(home: page));
      await tester.pumpAndSettle();
    }

    testWidgets('login page', (tester) async {
      await pump(
        tester,
        LoginPage(
          authRepository: FakeAuthRepository(),
          nextPage: const SizedBox(),
        ),
      );
      expect(find.text('Sign in'), findsWidgets);
      expect(find.text('Forgot password?'), findsOneWidget);
      expect(find.text('No account yet? Sign up'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter your email'), findsOneWidget);
    });

    testWidgets('register page', (tester) async {
      await pump(
        tester,
        RegisterPage(
          authRepository: FakeAuthRepository(),
          nextPage: const SizedBox(),
        ),
      );
      expect(find.text('Sign up with Google'), findsOneWidget);
      expect(find.text('Display name'), findsWidgets);
      expect(find.text('Confirm password'), findsWidgets);
    });
  });
}
