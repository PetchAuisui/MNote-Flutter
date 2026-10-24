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

  tearDown(() => InkSettings.instance.fingerDrawing = false);

  group('InkSettings', () {
    test('a finger does not draw by default', () {
      expect(InkSettings().fingerDrawing, isFalse);
    });

    test('the choice persists across restores', () async {
      InkSettings().fingerDrawing = true;
      await settle();

      final restored = InkSettings();
      await restored.restore();
      expect(restored.fingerDrawing, isTrue);
    });

    test('notifies only on a real change', () {
      final s = InkSettings();
      var calls = 0;
      s.addListener(() => calls++);
      s.fingerDrawing = false;
      expect(calls, 0);
      s.fingerDrawing = true;
      expect(calls, 1);
    });
  });

  group('new ink sessions', () {
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

  testWidgets('the settings switch turns finger drawing on and off', (
    tester,
  ) async {
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

    final finger = find.byKey(const Key('ink-finger-drawing'));
    await tester.ensureVisible(finger);
    await tester.tap(finger);
    await tester.pumpAndSettle();
    expect(InkSettings.instance.fingerDrawing, isTrue);

    await tester.tap(finger);
    await tester.pumpAndSettle();
    expect(InkSettings.instance.fingerDrawing, isFalse);
  });
}
