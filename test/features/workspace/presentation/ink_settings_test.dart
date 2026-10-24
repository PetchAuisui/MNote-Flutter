import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnote/app/mnote_app.dart';
import 'package:mnote/features/workspace/presentation/ink_session.dart';
import 'package:mnote/features/workspace/presentation/ink_settings.dart';
import 'package:mnote/screens/widgets/note_list_settings_dialog.dart';
import 'package:scribble/scribble.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  tearDown(InkSettings.instance.reset);

  group('InkSettings', () {
    test('defaults match the current pen', () {
      final s = InkSettings();
      expect(s.penColor, InkSettings.penColors.first);
      expect(s.penWidth, 3);
      expect(s.highlightColor, InkSettings.highlightColors.first);
      expect(s.fingerDrawing, isFalse);
      expect(s.isDefault, isTrue);
    });

    test('only offered colors and widths are accepted', () {
      final s = InkSettings()
        ..penColor = const Color(0xFF123456)
        ..penWidth = 7
        ..highlightColor = const Color(0xFF654321);
      expect(s.isDefault, isTrue);

      s
        ..penColor = InkSettings.penColors[2]
        ..penWidth = 12
        ..highlightColor = InkSettings.highlightColors[3];
      expect(s.penColor, InkSettings.penColors[2]);
      expect(s.penWidth, 12);
      expect(s.highlightColor, InkSettings.highlightColors[3]);
    });

    test('choices persist across restores', () async {
      InkSettings()
        ..penColor = InkSettings.penColors[1]
        ..penWidth = 6
        ..highlightColor = InkSettings.highlightColors[2]
        ..fingerDrawing = true;
      await settle();

      final restored = InkSettings();
      await restored.restore();
      expect(restored.penColor, InkSettings.penColors[1]);
      expect(restored.penWidth, 6);
      expect(restored.highlightColor, InkSettings.highlightColors[2]);
      expect(restored.fingerDrawing, isTrue);
    });

    test('a saved value that is no longer offered falls back', () async {
      SharedPreferences.setMockInitialValues({
        InkSettings.penColorKey: 0xFF010203,
        InkSettings.penWidthKey: 99.0,
      });
      final s = InkSettings();
      await s.restore();
      expect(s.penColor, InkSettings.defaultPenColor);
      expect(s.penWidth, InkSettings.defaultPenWidth);
    });

    test('reset restores everything', () {
      final s = InkSettings()
        ..penColor = InkSettings.penColors[4]
        ..fingerDrawing = true
        ..reset();
      expect(s.isDefault, isTrue);
    });

    test('notifies only on a real change', () {
      final s = InkSettings();
      var calls = 0;
      s.addListener(() => calls++);
      s.penWidth = 3;
      expect(calls, 0);
      s.penWidth = 6;
      expect(calls, 1);
    });
  });

  group('new ink sessions', () {
    test('start with the saved pen and highlighter', () {
      InkSettings.instance
        ..penColor = InkSettings.penColors[2]
        ..penWidth = 12
        ..highlightColor = InkSettings.highlightColors[1];

      final session = InkSession();
      addTearDown(session.dispose);

      expect(
        session.pen.value.map(
          drawing: (d) => d.selectedColor,
          erasing: (_) => 0,
        ),
        InkSettings.penColors[2].toARGB32(),
      );
      expect(session.pen.value.selectedWidth, 12);
      expect(session.highlightColor, InkSettings.highlightColors[1]);
    });

    test('a finger can draw only when allowed', () {
      final off = InkSession();
      addTearDown(off.dispose);
      expect(off.pen.value.allowedPointersMode, ScribblePointerMode.penOnly);

      InkSettings.instance.fingerDrawing = true;
      final on = InkSession();
      addTearDown(on.dispose);
      expect(on.pen.value.allowedPointersMode, ScribblePointerMode.all);
    });
  });

  group('settings section', () {
    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(600, 3000);
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

    testWidgets('pen color, width, highlight and finger switch work', (
      tester,
    ) async {
      await open(tester);
      final red = InkSettings.penColors[2];
      final key = ValueKey('ink-pen-color-${red.toARGB32().toRadixString(16)}');
      await tester.ensureVisible(find.byKey(key));
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
      expect(InkSettings.instance.penColor, red);

      await tester.tap(find.byKey(const ValueKey('ink-pen-width-12')));
      await tester.pumpAndSettle();
      expect(InkSettings.instance.penWidth, 12);

      final pink = InkSettings.highlightColors[2];
      await tester.tap(
        find.byKey(
          ValueKey('ink-highlight-color-${pink.toARGB32().toRadixString(16)}'),
        ),
      );
      await tester.pumpAndSettle();
      expect(InkSettings.instance.highlightColor, pink);

      await tester.ensureVisible(find.byKey(const Key('ink-finger-drawing')));
      await tester.tap(find.byKey(const Key('ink-finger-drawing')));
      await tester.pumpAndSettle();
      expect(InkSettings.instance.fingerDrawing, isTrue);
    });

    testWidgets('reset is disabled until something changes', (tester) async {
      await open(tester);
      final reset = find.byKey(const Key('ink-reset'));
      await tester.ensureVisible(reset);
      expect(tester.widget<TextButton>(reset).onPressed, isNull);

      InkSettings.instance.penWidth = 6;
      await tester.pumpAndSettle();
      await tester.tap(reset);
      await tester.pumpAndSettle();

      expect(InkSettings.instance.isDefault, isTrue);
    });
  });
}
