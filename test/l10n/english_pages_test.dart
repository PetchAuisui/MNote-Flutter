import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnote/app/mnote_app.dart';
import 'package:mnote/features/assistant/data/firebase_ai_assistant.dart';
import 'package:mnote/features/assistant/presentation/assistant_chat_controller.dart';
import 'package:mnote/features/auth/presentation/app_guide_page.dart';
import 'package:mnote/features/workspace/domain/markdown_document.dart';
import 'package:mnote/features/workspace/presentation/markdown_workspace_page.dart';
import 'package:mnote/features/workspace/presentation/mermaid/mermaid.dart';
import 'package:mnote/l10n/app_localizations_en.dart';
import 'package:mnote/l10n/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_ai_assistant.dart';
import '../helpers/fakes.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  tearDown(() => MnoteApp.languageNotifier.value = AppLanguage.system);

  test('no screen text is left hard-coded in Thai', () {
    // Thai text that may stay: the AI instructions, developer-only errors, and
    // names that are shown in their own language.
    const allowed = {
      'lib/features/assistant/data/firebase_ai_assistant.dart',
      'lib/core/theme/app_theme.dart',
      'lib/features/workspace/presentation/editor_settings.dart',
    };
    final thai = RegExp('[฀-๿]');
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path;
      if (path.startsWith('lib/l10n/') || allowed.contains(path)) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final code = line.contains('//')
            ? line.substring(0, line.indexOf('//'))
            : line;
        if (thai.hasMatch(code)) offenders.add('$path:${i + 1}');
      }
    }
    expect(offenders, isEmpty, reason: 'Move these to lib/l10n: $offenders');
  });

  testWidgets('the note page in English', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    MnoteApp.languageNotifier.value = AppLanguage.english;
    final repo = FakeDocumentRepository();
    await tester.pumpWidget(
      MnoteApp(
        home: MarkdownWorkspacePage(
          repository: repo,
          initialDocument: MarkdownDocument.example('# Hello'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Export'), findsOneWidget);
    expect(find.byTooltip('More actions'), findsOneWidget);
    expect(find.text('Write'), findsOneWidget);
    expect(find.textContaining('lines ·'), findsOneWidget);
    expect(find.textContaining('บรรทัด'), findsNothing);

    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    expect(find.text('New note'), findsOneWidget);
    expect(find.text('Open another note'), findsOneWidget);
    expect(find.text('Save as'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Export'));
    await tester.pumpAndSettle();
    expect(find.text('Export note'), findsOneWidget);
    expect(find.text('PDF document (.pdf)'), findsOneWidget);
    expect(find.text('Plain text (.txt)'), findsOneWidget);
    expect(find.text('Image (.png)'), findsOneWidget);
  });

  testWidgets('the app guide in English', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    MnoteApp.languageNotifier.value = AppLanguage.english;
    await tester.pumpWidget(
      MnoteApp(home: AppGuidePage(repository: FakeDocumentRepository())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mnote guide'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Write and format Markdown'), findsOneWidget);
    expect(find.text('Step 01 / 03'), findsOneWidget);
  });

  test('Mermaid templates use the language', () {
    final en = mermaidTemplatesFor(AppLocalizationsEn());
    expect(en.first.label, 'Flowchart');
    expect(en.first.source, contains('start([Start])'));
    expect(en[1].source, contains('participant U as User'));
    expect(mermaidTemplates.first.label, 'ผังงาน (Flowchart)');
  });

  test('assistant errors follow the language', () async {
    MnoteApp.languageNotifier.value = AppLanguage.english;
    final controller = AssistantChatController(
      FakeAiAssistant(chunks: const ['x']),
    );
    addTearDown(controller.dispose);
    await controller.send('a' * (AssistantChatController.maxInputLength + 1));
    expect(controller.errorMessage, contains('too long'));

    expect(
      aiErrorToException(Exception('offline')).message,
      contains('Could not connect to the AI assistant'),
    );
  });
}
