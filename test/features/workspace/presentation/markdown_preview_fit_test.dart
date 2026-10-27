import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/workspace/presentation/markdown_document_canvas.dart';

void main() {
  for (final width in [320.0, 1400.0]) {
    testWidgets('preview fits and centers page at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MarkdownPreviewCanvas(markdown: '# Preview', height: 2400),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      final transform = viewer.transformationController!.value;
      final scale = transform.entry(0, 0);
      final left = transform.entry(0, 3);
      final right = left + DocumentPageMetrics.width * scale;
      expect(left, greaterThanOrEqualTo(0));
      expect(right, lessThanOrEqualTo(width));
      expect((left + right) / 2, closeTo(width / 2, 0.01));
      expect(scale, lessThanOrEqualTo(1));
    });
  }

  testWidgets('pinching out returns to the fitted, centred page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MarkdownPreviewCanvas(markdown: '# Preview', height: 2400),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final transform = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;
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

    final scale = transform.value.getMaxScaleOnAxis();
    final left = transform.value.getTranslation().x;
    expect(scale, lessThanOrEqualTo(fitted + 0.001));
    expect(left + DocumentPageMetrics.width * scale / 2, closeTo(1200, 0.5));
  });
}
