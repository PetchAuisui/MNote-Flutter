import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:mnote/app/mnote_app.dart';
import 'package:mnote/features/workspace/presentation/ink_session.dart';
import 'package:mnote/features/workspace/presentation/markdown_document_canvas.dart';
import 'package:scribble/scribble.dart';
import 'helpers/fakes.dart';

const sketch = Sketch(
  lines: [
    SketchLine(
      points: [Point(50, 100), Point(80, 130)],
      color: 0xff000000,
      width: 3,
    ),
  ],
);

void main() {
  testWidgets('preview and ink share the same white document page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MnoteApp(documentRepository: FakeDocumentRepository()),
    );
    await tester.pumpAndSettle();

    final editorCard = tester.widget<Card>(
      find.byKey(const Key('document-surface')),
    );
    final editorPage = tester.widget<DecoratedBox>(
      find.byKey(const Key('markdown-editor-page')),
    );
    expect(editorCard.color, Colors.white);
    expect((editorPage.decoration as BoxDecoration).color, Colors.white);

    await tester.tap(find.text('แสดงผล'));
    await tester.pumpAndSettle();
    final preview = tester.widget<MarkdownDocumentSurface>(
      find.byType(MarkdownDocumentSurface),
    );
    final previewPage = tester.widget<ColoredBox>(
      find.byKey(const Key('markdown-document-page')),
    );
    expect(previewPage.color, Colors.white);
    expect(
      tester.widget<MarkdownBody>(find.byType(MarkdownBody)).fitContent,
      isFalse,
    );

    await tester.tap(find.text('จด'));
    await tester.pumpAndSettle();
    final ink = tester.widget<MarkdownDocumentSurface>(
      find.byType(MarkdownDocumentSurface),
    );
    final inkPage = tester.widget<ColoredBox>(
      find.byKey(const Key('markdown-document-page')),
    );
    expect(inkPage.color, Colors.white);
    expect(
      tester.widget<MarkdownBody>(find.byType(MarkdownBody)).fitContent,
      isFalse,
    );
    expect(ink.markdown, preview.markdown);
    expect(ink.height, preview.height);
    expect(DocumentPageMetrics.width, 1000);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stylus draws on the transformed page and undo removes ink', (
    tester,
  ) async {
    await tester.pumpWidget(
      MnoteApp(documentRepository: FakeDocumentRepository()),
    );
    await tester.tap(find.text('จด'));
    await tester.pumpAndSettle();
    final canvas = find.byType(Scribble);
    final start = tester.getTopLeft(canvas) + const Offset(80, 80);
    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.stylus,
    );
    await gesture.moveBy(const Offset(30, 20));
    await gesture.up();
    await tester.pumpAndSettle();
    final pen = tester.widget<Scribble>(canvas).notifier as ScribbleNotifier;
    expect(pen.currentSketch.lines, hasLength(1));
    await tester.tap(find.byTooltip('ย้อนกลับหมึก'));
    await tester.pumpAndSettle();
    expect(pen.currentSketch.lines, isEmpty);
    expect(tester.takeException(), isNull);
  });
  test('ink round trip retains coordinates and nonshrinking page', () {
    final session = InkSession();
    final restored = InkSession();
    addTearDown(session.dispose);
    addTearDown(restored.dispose);
    session.pen.setSketch(sketch: sketch);
    session.grow(3100);
    session.grow(1400);
    expect(session.isDirty, isTrue);
    final snapshot = session.encode();
    restored.load(snapshot);
    expect(restored.pen.currentSketch, sketch);
    expect(restored.height, 3100);
    expect(restored.isDirty, isFalse);
    session.markSaved(snapshot);
    session.pen.clear();
    expect(session.isDirty, isTrue);
    session.pen.undo();
    expect(session.pen.currentSketch, sketch);
    expect(session.isDirty, isFalse);
    session.pen.redo();
    expect(session.pen.currentSketch.lines, isEmpty);
  });

  test('invalid import leaves current ink intact', () {
    final session = InkSession();
    addTearDown(session.dispose);
    session.pen.setSketch(sketch: sketch);
    expect(() => session.load('{"version":2}'), throwsFormatException);
    expect(session.pen.currentSketch, sketch);
  });

  testWidgets('ink survives Markdown deletion, mode switch and resize', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MnoteApp(documentRepository: FakeDocumentRepository()),
    );
    await tester.enterText(find.byKey(const Key('markdown-editor')), '# Hello');
    await tester.tap(find.text('จด'));
    await tester.pumpAndSettle();
    final pen =
        tester.widget<Scribble>(find.byType(Scribble)).notifier
            as ScribbleNotifier;
    pen.setSketch(sketch: sketch);
    await tester.pumpAndSettle();
    await tester.tap(find.text('แก้ไข'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('markdown-editor')), '');
    await tester.tap(find.text('จด'));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(500, 900);
    await tester.pumpAndSettle();
    expect(
      (tester.widget<Scribble>(find.byType(Scribble)).notifier
              as ScribbleNotifier)
          .currentSketch,
      sketch,
    );
    expect(tester.takeException(), isNull);
  });
}
