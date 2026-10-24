import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnote/features/workspace/presentation/editor_settings.dart';
import 'package:mnote/features/workspace/presentation/ink_page.dart';
import 'package:mnote/features/workspace/presentation/ink_session.dart';
import 'package:mnote/features/workspace/presentation/markdown_document_style.dart';
import 'package:scribble/scribble.dart';
import 'package:shared_preferences/shared_preferences.dart';

const stroke = Sketch(
  lines: [
    SketchLine(
      points: [Point(50, 100), Point(80, 130)],
      color: 0xff000000,
      width: 3,
    ),
  ],
);

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  tearDown(EditorSettings.instance.resetLook);

  group('InkSession layout', () {
    late InkSession session;
    setUp(() => session = InkSession());
    tearDown(() => session.dispose());

    const big = DocumentTextOptions(bodySize: 24, lineHeight: 1.9);

    test('a page without ink follows the editor settings', () {
      expect(session.layoutFor(big), big);
    });

    test('the first stroke locks the layout it was drawn with', () {
      EditorSettings.instance
        ..fontSize = 22
        ..lineHeight = 1.8;
      session.pen.setSketch(sketch: stroke);

      EditorSettings.instance
        ..fontSize = 14
        ..font = EditorFont.kanit;

      final layout = session.layoutFor(EditorSettings.instance.textOptions);
      expect(layout.bodySize, 22);
      expect(layout.lineHeight, 1.8);
      expect(layout.fontFamily, isNull);
    });

    test('clearing the ink makes the page follow the settings again', () {
      session.pen.setSketch(sketch: stroke);
      session.pen.setSketch(sketch: const Sketch(lines: []));

      expect(session.layoutFor(big), big);
    });

    test('the locked layout is saved and restored', () {
      EditorSettings.instance
        ..fontSize = 22
        ..font = EditorFont.sarabun;
      session.pen.setSketch(sketch: stroke);
      final saved = session.encode();
      expect(jsonDecode(saved)['layout'], {
        'size': 22.0,
        'lineHeight': 1.55,
        'font': 'Sarabun',
      });

      EditorSettings.instance.resetLook();
      final other = InkSession()..load(saved);
      addTearDown(other.dispose);
      final layout = other.layoutFor(big);
      expect(layout.bodySize, 22);
      expect(layout.fontFamily, 'Sarabun');
    });

    test('ink saved before layouts existed keeps the default layout', () {
      session.pen.setSketch(sketch: stroke);
      final data = jsonDecode(session.encode()) as Map<String, dynamic>
        ..remove('layout');

      final old = InkSession()..load(jsonEncode(data));
      addTearDown(old.dispose);

      expect(old.layoutFor(big), const DocumentTextOptions());
    });

    test('an invalid saved layout falls back to safe values', () {
      session.pen.setSketch(sketch: stroke);
      final data = jsonDecode(session.encode()) as Map<String, dynamic>;
      data['layout'] = {'size': 9999, 'lineHeight': 'x', 'font': 'Comic'};

      final other = InkSession()..load(jsonEncode(data));
      addTearDown(other.dispose);

      expect(other.layoutFor(big), const DocumentTextOptions());
    });

    test('an empty page saves no layout', () {
      expect(jsonDecode(session.encode()).containsKey('layout'), isFalse);
    });
  });

  group('writing view', () {
    Future<Size> textSize(WidgetTester tester, InkSession session) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InkPage(
              session: session,
              markdown: 'Hello',
              name: 'notes.md',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester.getSize(find.text('Hello', findRichText: true));
    }

    testWidgets('follows the editor settings while the page has no ink', (
      tester,
    ) async {
      final session = InkSession();
      addTearDown(session.dispose);
      final before = await textSize(tester, session);

      EditorSettings.instance.fontSize = 26;
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.text('Hello', findRichText: true)).height,
        greaterThan(before.height),
      );
    });

    testWidgets('keeps the layout of a page that already has ink', (
      tester,
    ) async {
      final session = InkSession();
      addTearDown(session.dispose);
      session.pen.setSketch(sketch: stroke);
      final before = await textSize(tester, session);

      EditorSettings.instance
        ..fontSize = 26
        ..lineHeight = 2;
      await tester.pumpAndSettle();

      expect(tester.getSize(find.text('Hello', findRichText: true)), before);
    });
  });
}
