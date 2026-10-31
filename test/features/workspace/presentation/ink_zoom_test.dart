import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnote/features/workspace/presentation/ink_page.dart';
import 'package:mnote/features/workspace/presentation/ink_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('pinching out returns to the fitted page on a wide viewport', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(2400, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final session = InkSession();
    addTearDown(session.dispose);
    final transform = TransformationController();
    addTearDown(transform.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InkPage(
            session: session,
            markdown: 'Hello',
            name: 'notes.md',
            transformationController: transform,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final fitted = transform.value.getMaxScaleOnAxis();

    transform.value = Matrix4.diagonal3Values(2, 2, 1);
    await tester.pump();

    final center = tester.getCenter(find.byType(InteractiveViewer));
    final a = await tester.startGesture(center + const Offset(-300, 0));
    final b = await tester.startGesture(center + const Offset(300, 0));
    await a.moveTo(center + const Offset(-20, 0));
    await b.moveTo(center + const Offset(20, 0));
    await a.up();
    await b.up();
    await tester.pumpAndSettle();

    expect(
      transform.value.getMaxScaleOnAxis(),
      lessThanOrEqualTo(fitted + 0.001),
    );
  });

  testWidgets('fit width keeps the current scroll position', (tester) async {
    tester.view
      ..physicalSize = const Size(1200, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final session = InkSession();
    addTearDown(session.dispose);
    final transform = TransformationController();
    addTearDown(transform.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InkPage(
            session: session,
            markdown: List.filled(200, 'Line of text').join('\n\n'),
            name: 'notes.md',
            transformationController: transform,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final fitted = transform.value.clone();

    // Scroll well down the page, then press fit width.
    transform.value = fitted.clone()
      ..setTranslationRaw(fitted.getTranslation().x, -2000, 0);
    await tester.pump();
    await tester.tap(find.byKey(const Key('ink-fit')));
    await tester.pumpAndSettle();

    expect(transform.value.getTranslation().y, closeTo(-2000, 0.5));
  });
}
