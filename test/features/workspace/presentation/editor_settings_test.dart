import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnote/app/mnote_app.dart';
import 'package:mnote/features/workspace/presentation/editor_settings.dart';
import 'package:mnote/features/workspace/presentation/markdown_document_canvas.dart';
import 'package:mnote/features/workspace/presentation/markdown_live_editor.dart';
import 'package:mnote/features/workspace/presentation/markdown_workspace_page.dart';
import 'package:mnote/features/workspace/presentation/workspace_controller.dart';
import 'package:mnote/screens/widgets/note_list_settings_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  tearDown(() {
    EditorSettings.instance
      ..resetLook()
      ..openMode = WorkspaceMode.split;
  });

  group('EditorSettings', () {
    test('defaults match the fixed page metrics', () {
      final s = EditorSettings();
      expect(s.fontSize, 17);
      expect(s.lineHeight, 1.55);
      expect(s.font, EditorFont.app);
      expect(s.openMode, WorkspaceMode.ink);
      expect(s.isDefaultLook, isTrue);
    });

    test('values are clamped and the open mode is only ink or split', () {
      final s = EditorSettings()
        ..fontSize = 99
        ..lineHeight = 0.1
        ..openMode = WorkspaceMode.preview;
      expect(s.fontSize, EditorSettings.maxFontSize);
      expect(s.lineHeight, EditorSettings.minLineHeight);
      expect(s.openMode, WorkspaceMode.ink);
    });

    test('choices persist across restores', () async {
      EditorSettings()
        ..fontSize = 20
        ..lineHeight = 1.8
        ..font = EditorFont.sarabun
        ..openMode = WorkspaceMode.split;
      await settle();

      final restored = EditorSettings();
      await restored.restore();
      expect(restored.fontSize, 20);
      expect(restored.lineHeight, 1.8);
      expect(restored.font, EditorFont.sarabun);
      expect(restored.openMode, WorkspaceMode.split);
    });

    test('resetLook keeps the open mode', () {
      final s = EditorSettings()
        ..fontSize = 22
        ..font = EditorFont.kanit
        ..openMode = WorkspaceMode.split
        ..resetLook();
      expect(s.isDefaultLook, isTrue);
      expect(s.openMode, WorkspaceMode.split);
    });

    test('notifies listeners only when something changes', () {
      final s = EditorSettings();
      var calls = 0;
      s.addListener(() => calls++);
      s.fontSize = 17;
      expect(calls, 0);
      s.fontSize = 18;
      expect(calls, 1);
    });

    test('the workspace default mode follows the setting', () {
      MarkdownWorkspacePage.defaultMode = WorkspaceMode.ink;
      expect(EditorSettings.instance.openMode, WorkspaceMode.ink);
      MarkdownWorkspacePage.defaultMode = WorkspaceMode.split;
      expect(EditorSettings.instance.openMode, WorkspaceMode.split);
    });
  });

  group('typing view', () {
    testWidgets('uses the chosen size and line height, live', (tester) async {
      final controller = TextEditingController(text: 'Hello');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownLiveEditor(controller: controller, onChanged: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      TextStyle? editorStyle() => tester
          .widget<TextField>(
            find.byKey(const Key('markdown-live-block-editor')),
          )
          .style;
      await tester.tap(find.text('Hello', findRichText: true));
      await tester.pumpAndSettle();
      expect(editorStyle()!.fontSize, 17);

      EditorSettings.instance
        ..fontSize = 24
        ..lineHeight = 1.9;
      await tester.pumpAndSettle();

      expect(editorStyle()!.fontSize, 24);
      expect(editorStyle()!.height, 1.9);
    });

    testWidgets('the writing view keeps the fixed page metrics', (
      tester,
    ) async {
      Future<Size> helloSize() async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MarkdownDocumentSurface(
                markdown: 'Hello',
                height: 400,
                selectable: false,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        return tester.getSize(find.text('Hello', findRichText: true));
      }

      final before = await helloSize();
      EditorSettings.instance
        ..fontSize = 24
        ..lineHeight = 1.9;
      final after = await helloSize();

      expect(after, before);
    });
  });

  group('settings section', () {
    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(600, 2400);
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

    testWidgets('chooses the mode new notes open in', (tester) async {
      await open(tester);
      await tester.tap(find.text('จด'));
      await tester.pumpAndSettle();
      expect(MarkdownWorkspacePage.defaultMode, WorkspaceMode.ink);

      await tester.tap(find.text('พิมพ์'));
      await tester.pumpAndSettle();
      expect(MarkdownWorkspacePage.defaultMode, WorkspaceMode.split);
    });

    testWidgets('font, size and line height controls update the settings', (
      tester,
    ) async {
      await open(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('editor-font-kanit')),
      );
      await tester.tap(find.byKey(const ValueKey('editor-font-kanit')));
      await tester.pumpAndSettle();
      expect(EditorSettings.instance.font, EditorFont.kanit);

      final slider = find.byKey(const Key('editor-font-size'));
      await tester.ensureVisible(slider);
      await tester.drag(slider, const Offset(400, 0));
      await tester.pumpAndSettle();
      expect(EditorSettings.instance.fontSize, EditorSettings.maxFontSize);

      final lineSlider = find.byKey(const Key('editor-line-height'));
      await tester.ensureVisible(lineSlider);
      await tester.drag(lineSlider, const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(EditorSettings.instance.lineHeight, EditorSettings.minLineHeight);
    });

    testWidgets('reset restores the defaults and is disabled when unchanged', (
      tester,
    ) async {
      await open(tester);
      final reset = find.byKey(const Key('editor-reset'));
      await tester.ensureVisible(reset);
      expect(tester.widget<TextButton>(reset).onPressed, isNull);

      EditorSettings.instance.fontSize = 22;
      await tester.pumpAndSettle();
      await tester.tap(reset);
      await tester.pumpAndSettle();

      expect(EditorSettings.instance.fontSize, 17);
    });
  });
}
