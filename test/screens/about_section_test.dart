import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnote/app/mnote_app.dart';
import 'package:mnote/l10n/l10n.dart';
import 'package:mnote/screens/widgets/about_section.dart';
import 'package:mnote/screens/widgets/note_list_settings_dialog.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  late List<Uri> opened;
  late bool openResult;
  final originalOpener = aboutLinkOpener;

  setUp(() {
    opened = [];
    openResult = true;
    aboutLinkOpener = (url) async {
      opened.add(url);
      return openResult;
    };
    PackageInfo.setMockInitialValues(
      appName: 'Mnote',
      packageName: 'com.example.mnote',
      version: '2.3.4',
      buildNumber: '56',
      buildSignature: '',
    );
  });

  tearDown(() {
    aboutLinkOpener = originalOpener;
    MnoteApp.languageNotifier.value = AppLanguage.system;
  });

  Future<void> openSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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

  test('the version includes the build number when there is one', () {
    expect(
      AboutSection.describeVersion(
        PackageInfo(
          appName: 'a',
          packageName: 'p',
          version: '1.0.0',
          buildNumber: '7',
        ),
      ),
      '1.0.0 (7)',
    );
    expect(
      AboutSection.describeVersion(
        PackageInfo(
          appName: 'a',
          packageName: 'p',
          version: '1.0.0',
          buildNumber: '',
        ),
      ),
      '1.0.0',
    );
  });

  testWidgets('shows the real app version in Thai', (tester) async {
    await openSettings(tester);
    final version = find.byKey(const Key('about-version'));
    await tester.ensureVisible(version);

    expect(find.text('เกี่ยวกับ (About)'), findsOneWidget);
    expect(
      find.text('เวอร์ชัน 2.3.4 (56) • Local-First Markdown Workspace'),
      findsOneWidget,
    );
    expect(find.textContaining('v1.0.0'), findsNothing);
  });

  testWidgets('shows the version in English', (tester) async {
    MnoteApp.languageNotifier.value = AppLanguage.english;
    await openSettings(tester);
    await tester.ensureVisible(find.byKey(const Key('about-version')));

    expect(find.text('About'), findsOneWidget);
    expect(
      find.text('Version 2.3.4 (56) • Local-First Markdown Workspace'),
      findsOneWidget,
    );
  });

  testWidgets('feedback and source open the GitHub pages', (tester) async {
    await openSettings(tester);
    await tester.ensureVisible(find.byKey(const Key('about-feedback')));
    await tester.tap(find.byKey(const Key('about-feedback')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('about-source')));
    await tester.tap(find.byKey(const Key('about-source')));
    await tester.pumpAndSettle();

    expect(opened, [aboutIssuesUrl, aboutRepositoryUrl]);
    expect(aboutIssuesUrl.toString(), endsWith('/MNote-Flutter/issues'));
  });

  testWidgets('tells the user when a link cannot be opened', (tester) async {
    openResult = false;
    await openSettings(tester);
    await tester.ensureVisible(find.byKey(const Key('about-feedback')));
    await tester.tap(find.byKey(const Key('about-feedback')));
    await tester.pumpAndSettle();

    expect(find.text('เปิดลิงก์ไม่สำเร็จ'), findsOneWidget);
  });

  testWidgets('opens the open-source licenses page', (tester) async {
    await openSettings(tester);
    await tester.ensureVisible(find.byKey(const Key('about-licenses')));
    await tester.tap(find.byKey(const Key('about-licenses')));
    await tester.pumpAndSettle();

    expect(find.byType(LicensePage), findsOneWidget);
    expect(find.textContaining('2.3.4 (56)'), findsOneWidget);
  });

  testWidgets('the licenses open when the app reports no version', (
    tester,
  ) async {
    PackageInfo.setMockInitialValues(
      appName: '',
      packageName: '',
      version: '',
      buildNumber: '',
      buildSignature: '',
    );
    await openSettings(tester);
    await tester.ensureVisible(find.byKey(const Key('about-licenses')));
    await tester.tap(find.byKey(const Key('about-licenses')));
    await tester.pumpAndSettle();

    expect(find.byType(LicensePage), findsOneWidget);
  });
}
