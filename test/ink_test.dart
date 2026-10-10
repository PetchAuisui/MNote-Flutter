import 'dart:io';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/app/mnote_app.dart';
import 'package:mnote/features/workspace/presentation/markdown_live_editor.dart';
import 'package:mnote/features/workspace/domain/markdown_document.dart';
import 'package:mnote/features/workspace/data/ink_file_storage.dart';
import 'package:mnote/features/workspace/domain/document_repository.dart';
import 'package:mnote/features/workspace/presentation/ink_page.dart';
import 'package:mnote/features/workspace/presentation/ink_session.dart';
import 'package:mnote/features/workspace/presentation/markdown_document_canvas.dart';
import 'package:mnote/features/workspace/presentation/markdown_workspace_page.dart';
import 'package:mnote/features/workspace/presentation/workspace_toolbar_metrics.dart';
import 'package:scribble/scribble.dart';

import 'helpers/fakes.dart';

Widget _buildWorkspaceApp([DocumentRepository? repository]) {
  final repo = repository ?? FakeDocumentRepository();
  return MnoteApp(
    documentRepository: repo,
    home: MarkdownWorkspacePage(
      repository: repo,
      initialDocument: MarkdownDocument.example('# Hello'),
    ),
  );
}

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
    await tester.pumpWidget(_buildWorkspaceApp());
    await tester.pumpAndSettle();

    final editorCard = tester.widget<Card>(
      find.byKey(const Key('document-surface')),
    );
    expect(editorCard.color, Colors.white);
    final preview = tester.widget<MarkdownLiveEditor>(
      find.byType(MarkdownLiveEditor),
    );
    final previewSource = preview.controller.text;
    final previewStyle = tester
        .widget<MarkdownBody>(find.byType(MarkdownBody).first)
        .styleSheet!;

    await tester.tap(find.byTooltip('เขียน'));
    await tester.pumpAndSettle();
    final ink = tester.widget<MarkdownDocumentSurface>(
      find.byType(MarkdownDocumentSurface),
    );
    final inkPage = tester.widget<ColoredBox>(
      find.byKey(const Key('markdown-document-page')),
    );
    expect(inkPage.color, Colors.white);
    expect(
      tester.widget<MarkdownBody>(find.byType(MarkdownBody).first).fitContent,
      isFalse,
    );
    expect(ink.markdown, previewSource);
    final inkStyle = tester
        .widget<MarkdownBody>(find.byType(MarkdownBody).first)
        .styleSheet!;
    expect(inkStyle.p, previewStyle.p);
    expect(inkStyle.blockquoteDecoration, previewStyle.blockquoteDecoration);
    expect(inkStyle.codeblockDecoration, previewStyle.codeblockDecoration);
    expect(DocumentPageMetrics.width, 1008);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stylus draws on the transformed page and undo removes ink', (
    tester,
  ) async {
    await tester.pumpWidget(_buildWorkspaceApp());
    await tester.tap(find.byTooltip('เขียน'));
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

  testWidgets('zoom scales ink only once with the document', (tester) async {
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_buildWorkspaceApp());
    await tester.tap(find.byTooltip('เขียน'));
    await tester.pumpAndSettle();

    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    final controller = viewer.transformationController!;
    final initialScale = controller.value.getMaxScaleOnAxis();
    final center = tester.getCenter(find.byType(InteractiveViewer));
    final first = await tester.startGesture(
      center - const Offset(50, 0),
      kind: PointerDeviceKind.touch,
    );
    final second = await tester.startGesture(
      center + const Offset(50, 0),
      kind: PointerDeviceKind.touch,
    );
    await tester.pump();
    await first.moveTo(center - const Offset(150, 0));
    await second.moveTo(center + const Offset(150, 0));
    await tester.pump();

    final pen = tester.widget<Scribble>(find.byType(Scribble)).notifier;
    expect(controller.value.getMaxScaleOnAxis(), greaterThan(initialScale));
    expect(pen.value.scaleFactor, 1);

    await first.up();
    await second.up();
    expect(tester.takeException(), isNull);
  });

  testWidgets('ink toolbar switches drawing tools and pen settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_buildWorkspaceApp());
    final markdownToolbarHeight = tester
        .getSize(find.byKey(const Key('markdown-toolbar-surface')))
        .height;
    await tester.tap(find.byTooltip('เขียน'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ink-toolbar')), findsOneWidget);
    expect(
      tester.widget<IconButton>(find.byKey(const Key('ink-pen'))).isSelected,
      isTrue,
    );
    expect(
      tester.getSize(find.byKey(const Key('ink-toolbar'))).height,
      workspaceToolbarHeight,
    );
    expect(markdownToolbarHeight, workspaceToolbarHeight);
    expect(find.byKey(const Key('ink-tools-group')), findsOneWidget);
    expect(find.byKey(const Key('ink-style-group')), findsOneWidget);
    expect(find.byKey(const Key('ink-page-group')), findsOneWidget);
    expect(find.byKey(const Key('ink-management-group')), findsOneWidget);
    expect(find.byKey(const Key('ink-history-dock')), findsOneWidget);
    final historyDock = tester.widget<Material>(
      find.byKey(const Key('ink-history-dock')),
    );
    final historyContext = tester.element(
      find.byKey(const Key('ink-history-dock')),
    );
    expect(
      historyDock.color,
      Theme.of(historyContext).colorScheme.surfaceContainerHighest,
    );
    expect(historyDock.elevation, 0);
    final toolbarRect = tester.getRect(find.byKey(const Key('ink-toolbar')));
    final historyDockRect = tester.getRect(
      find.byKey(const Key('ink-history-dock')),
    );
    expect(toolbarRect.contains(historyDockRect.topLeft), isTrue);
    expect(
      toolbarRect.contains(
        historyDockRect.bottomRight - const Offset(0.1, 0.1),
      ),
      isTrue,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('ink-toolbar')),
        matching: find.byIcon(Icons.folder_open_outlined),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('ink-toolbar')),
        matching: find.byIcon(Icons.save_outlined),
      ),
      findsNothing,
    );

    final groupCenters = [
      'ink-tools-group',
      'ink-style-group',
      'ink-page-group',
      'ink-management-group',
    ].map((key) => tester.getCenter(find.byKey(Key(key))).dx).toList();
    expect(groupCenters, orderedEquals([...groupCenters]..sort()));

    await tester.tap(find.byKey(const Key('ink-eraser')));
    await tester.pump();
    var pen =
        tester.widget<Scribble>(find.byType(Scribble)).notifier
            as ScribbleNotifier;
    expect(pen.value, isA<Erasing>());
    expect(
      tester.widget<IconButton>(find.byKey(const Key('ink-eraser'))).isSelected,
      isTrue,
    );

    await tester.tap(find.byKey(const Key('ink-highlighter')));
    await tester.pump();
    expect(pen.value, isA<Drawing>());
    expect(pen.value.selectedWidth, 18);
    expect((pen.value as Drawing).selectedColor, 0x80FFD54F);

    await tester.tap(find.byKey(const Key('ink-pen')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ink-color-preset-2')));
    await tester.pumpAndSettle();
    expect((pen.value as Drawing).selectedColor, 0xFFB3261E);

    await tester.tap(find.byKey(const Key('ink-width-preset-2')));
    await tester.pumpAndSettle();
    expect(pen.value.selectedWidth, 12);

    // Tapping the selected width edits that preset.
    await tester.tap(find.byKey(const Key('ink-width-preset-2')));
    await tester.pumpAndSettle();
    tester.widget<Slider>(find.byKey(const Key('ink-width-slider'))).onChanged!(
      25,
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('ink-width-apply')));
    await tester.pumpAndSettle();
    expect(pen.value.selectedWidth, 25);

    await tester.longPress(find.byKey(const Key('ink-color-preset-2')));
    await tester.pumpAndSettle();
    tester.widget<Slider>(find.byKey(const Key('ink-color-hue'))).onChanged!(
      120,
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('ink-color-apply')));
    await tester.pumpAndSettle();
    expect((pen.value as Drawing).selectedColor, isNot(0xFFB3261E));
    expect(pen.value.selectedWidth, 25);
    final session = tester.widget<InkPage>(find.byType(InkPage)).session;
    expect(session.widthPresets[2], 25);
    expect(session.colorPresets[2], isNot(const Color(0xFFB3261E)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ink toolbar stays usable on a compact phone', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = InkSession();
    addTearDown(session.dispose);
    await tester.pumpWidget(_inkPage(session: session));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('ink-tools-group')).hitTestable(),
      findsOneWidget,
    );
    final dockRect = tester.getRect(find.byKey(const Key('ink-history-dock')));
    expect(
      find.byKey(const Key('ink-management-menu')).hitTestable(),
      findsNothing,
    );

    final toolbarScroll = find.descendant(
      of: find.byKey(const Key('ink-toolbar')),
      matching: find.byType(SingleChildScrollView),
    );
    await tester.drag(toolbarScroll, const Offset(-700, 0));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('ink-management-menu')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.getRect(find.byKey(const Key('ink-history-dock'))), dockRect);
    expect(tester.takeException(), isNull);
  });

  testWidgets('color swatches and width menu fit narrow and wide screens', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    for (final size in const [Size(320, 700), Size(1180, 820)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      final session = InkSession();
      addTearDown(session.dispose);
      await tester.pumpWidget(_inkPage(session: session));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('ink-color-preset-4')));
      expect(find.byKey(const Key('ink-color-preset-4')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('ink-width-preset-2')));
      expect(find.byKey(const Key('ink-width-preset-0')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('tapping the selected swatch or palette edits a preset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1180, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = InkSession();
    addTearDown(session.dispose);
    await tester.pumpWidget(_inkPage(session: session));
    await tester.pumpAndSettle();
    final original = session.colorPresets[0];
    await tester.tap(find.byKey(const Key('ink-color-preset-0')));
    await tester.pumpAndSettle();
    tester.widget<Slider>(find.byKey(const Key('ink-color-hue'))).onChanged!(
      200,
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('ink-color-apply')));
    await tester.pumpAndSettle();
    expect(session.colorPresets[0], isNot(original));

    await tester.tap(find.byKey(const Key('ink-color')));
    await tester.pumpAndSettle();
    tester.widget<Slider>(find.byKey(const Key('ink-color-hue'))).onChanged!(
      30,
    );
    await tester.pump();
    final before = session.colorPresets[0];
    await tester.tap(find.byKey(const Key('ink-color-apply')));
    await tester.pumpAndSettle();
    expect(session.colorPresets[0], isNot(before));
  });

  testWidgets('highlighter keeps its own colors, separate from the pen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1180, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = InkSession();
    addTearDown(session.dispose);
    await tester.pumpWidget(_inkPage(session: session));
    await tester.pumpAndSettle();
    final pen = session.pen;

    await tester.tap(find.byKey(const Key('ink-color-preset-1')));
    await tester.pumpAndSettle();
    expect((pen.value as Drawing).selectedColor, 0xFF275DAD);

    await tester.tap(find.byKey(const Key('ink-highlighter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ink-color-preset-1')));
    await tester.pumpAndSettle();
    expect(session.highlightColor, session.highlightPresets[1]);
    expect(
      (pen.value as Drawing).selectedColor,
      InkSession.highlightInk(session.highlightPresets[1]).toARGB32(),
    );

    await tester.tap(find.byKey(const Key('ink-pen')));
    await tester.pumpAndSettle();
    expect((pen.value as Drawing).selectedColor, 0xFF275DAD);
    expect(session.colorPresets[1], const Color(0xFF275DAD));
  });

  testWidgets('page stays centred however the transform is disturbed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
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
            markdown: '# Notes',
            transformationController: transform,
            showToolbar: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final centred = transform.value.getTranslation().x;
    expect(centred, closeTo((1400 - InkSession.pageWidth) / 2, 0.5));

    transform.value = Matrix4.identity();
    await tester.pump();
    expect(transform.value.getTranslation().x, closeTo(centred, 0.5));

    transform.value = Matrix4.identity()..setTranslationRaw(-120, 0, 0);
    await tester.pump();
    expect(transform.value.getTranslation().x, closeTo(centred, 0.5));
  });

  testWidgets('highlighter strokes and dots render with equal thickness', (
    tester,
  ) async {
    final session = InkSession();
    addTearDown(session.dispose);
    const color = 0x66FFD54F;
    session.pen.setSketch(
      sketch: Sketch(
        lines: [
          SketchLine(
            color: color,
            width: 18,
            points: const [Point(40, 60), Point(300, 66)],
          ),
        ],
      ),
    );
    void add(List<Point> points) => session.pen.setSketch(
      sketch: Sketch(
        lines: [
          ...session.pen.currentSketch.lines,
          SketchLine(color: color, width: 18, points: points),
        ],
      ),
    );
    add(const [Point(400, 150)]);
    add(const [
      Point(40, 200),
      Point(90, 215),
      Point(150, 190),
      Point(210, 220),
      Point(300, 205),
    ]);
    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox(
              width: 500,
              height: 300,
              child: ColoredBox(
                color: const Color(0xFFFFFFFF),
                child: Scribble(notifier: session.pen, drawPen: false),
              ),
            ),
          ),
        ),
      ),
    );
    final image = await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      return boundary.toImage();
    });
    final data = (await tester.runAsync(
      () => image!.toByteData(format: ImageByteFormat.rawRgba),
    ))!;
    int thickness(int x, int y) {
      bool inked(int py) {
        final i = (py * 500 + x) * 4;
        return data.getUint8(i + 2) < 250;
      }

      var top = y;
      while (top > 0 && inked(top - 1)) {
        top--;
      }
      var bottom = y;
      while (bottom < 299 && inked(bottom + 1)) {
        bottom++;
      }
      return bottom - top + 1;
    }

    final lineMiddle = thickness(170, 63);
    final lineNearEnd = thickness(60, 61);
    final dot = thickness(400, 150);
    final wavyMiddle = thickness(170, 200);
    expect(lineMiddle, closeTo(36, 3));
    expect(lineNearEnd, closeTo(lineMiddle, 2));
    expect(dot, closeTo(lineMiddle, 2));
    expect(wavyMiddle, closeTo(lineMiddle, 2));
  });

  test('finished highlighter strokes stay free-form', () {
    final session = InkSession();
    addTearDown(session.dispose);
    SketchLine wavy(int color) => SketchLine(
      color: color,
      width: 18,
      points: const [
        Point(10, 100),
        Point(60, 108),
        Point(110, 95),
        Point(160, 104),
        Point(210, 102),
      ],
    );
    session.pen.setSketch(sketch: Sketch(lines: [wavy(0x66FFD54F)]));
    final stroke = session.pen.currentSketch.lines.single;
    expect(stroke.points, hasLength(5));
    expect(stroke.points[2].y, 95);
    expect(stroke.points.map((p) => p.pressure).toSet().length, greaterThan(1));
  });

  testWidgets('clearing ink asks for confirmation and can be undone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_buildWorkspaceApp());
    await tester.tap(find.byTooltip('เขียน'));
    await tester.pumpAndSettle();
    final pen =
        tester.widget<Scribble>(find.byType(Scribble)).notifier
            as ScribbleNotifier;
    pen.setSketch(sketch: sketch);
    await tester.pump();

    await _chooseInkManagementAction(tester, const Key('ink-clear'));
    expect(find.text('ล้างหมึกทั้งหมด?'), findsOneWidget);
    await tester.tap(find.text('ล้างทั้งหมด'));
    await tester.pumpAndSettle();
    expect(pen.currentSketch.lines, isEmpty);

    await tester.tap(find.byKey(const Key('ink-undo')));
    await tester.pumpAndSettle();
    expect(pen.currentSketch, sketch);
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

  test('device storage writes ink atomically beside the document', () async {
    final dir = await Directory.systemTemp.createTemp('mnote-ink');
    addTearDown(() => dir.delete(recursive: true));
    final uri = Uri.file('${dir.path}/a.md');
    const storage = DeviceInkFileStorage();

    await storage.write(uri, 'one');
    await storage.write(uri, 'two');

    expect(await storage.read(uri), 'two');
    expect(File('${dir.path}/a.md.ink.json.tmp').existsSync(), isFalse);
    await File('${dir.path}/a.md.ink.json').writeAsString('bad');
    await storage.backup(uri);
    expect(File('${dir.path}/a.md.ink.json.bak').readAsStringSync(), 'bad');
  });

  testWidgets('unreadable ink is backed up and not overwritten', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final uri = Uri.file('/notes/a.md');
    final storage = FakeInkFileStorage()..files[uri] = 'not json';
    final repo = FakeDocumentRepository();
    await tester.pumpWidget(
      MnoteApp(
        documentRepository: repo,
        home: MarkdownWorkspacePage(
          repository: repo,
          inkStorage: storage,
          initialDocument: MarkdownDocument.opened(
            name: 'a.md',
            content: '# Hello',
            uri: uri,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(storage.backups, [uri]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ink is not saved over a file that could not be backed up', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final uri = Uri.file('/notes/a.md');
    final storage = FakeInkFileStorage()
      ..files[uri] = 'not json'
      ..failBackup = true;
    final repo = FakeDocumentRepository();
    await tester.pumpWidget(
      MnoteApp(
        documentRepository: repo,
        home: MarkdownWorkspacePage(
          repository: repo,
          inkStorage: storage,
          initialDocument: MarkdownDocument.opened(
            name: 'a.md',
            content: '# Hello',
            uri: uri,
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('เขียน'));
    await tester.pumpAndSettle();
    final pen =
        tester.widget<Scribble>(find.byType(Scribble)).notifier
            as ScribbleNotifier;
    pen.setSketch(sketch: sketch);
    await tester.pump(const Duration(seconds: 1));

    expect(storage.files[uri], 'not json');
  });

  testWidgets('ink autosaves next to a saved document and reloads with it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final uri = Uri.file('/notes/a.md');
    final storage = FakeInkFileStorage();
    final repo = FakeDocumentRepository();
    Widget app() => MnoteApp(
      documentRepository: repo,
      home: MarkdownWorkspacePage(
        repository: repo,
        inkStorage: storage,
        initialDocument: MarkdownDocument.opened(
          name: 'a.md',
          content: '# Hello',
          uri: uri,
        ),
      ),
    );

    await tester.pumpWidget(app());
    await tester.tap(find.byTooltip('เขียน'));
    await tester.pumpAndSettle();
    final pen =
        tester.widget<Scribble>(find.byType(Scribble)).notifier
            as ScribbleNotifier;
    pen.setSketch(sketch: sketch);
    await tester.pump(const Duration(seconds: 1));

    final saved = storage.files[uri];
    expect(jsonDecode(saved!)['format'], 'mnote-ink');

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app());
    await tester.tap(find.byTooltip('เขียน'));
    await tester.pumpAndSettle();
    expect(
      (tester.widget<Scribble>(find.byType(Scribble)).notifier
              as ScribbleNotifier)
          .currentSketch,
      sketch,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('ink menu only offers clearing', (tester) async {
    tester.view.physicalSize = const Size(1180, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = InkSession();
    addTearDown(session.dispose);
    await tester.pumpWidget(_inkPage(session: session));
    await tester.tap(find.byKey(const Key('ink-management-menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ink-clear')), findsOneWidget);
    expect(find.byKey(const Key('ink-open')), findsNothing);
    expect(find.byKey(const Key('ink-save')), findsNothing);
  });

  testWidgets('ink survives Markdown deletion, mode switch and resize', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_buildWorkspaceApp());
    await tester.tap(find.byKey(const Key('markdown-block-0')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('markdown-live-block-editor')),
      '# Hello',
    );
    await tester.tap(find.byTooltip('เขียน'));
    await tester.pumpAndSettle();
    final pen =
        tester.widget<Scribble>(find.byType(Scribble)).notifier
            as ScribbleNotifier;
    pen.setSketch(sketch: sketch);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Markdown'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('markdown-block-0')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('markdown-live-block-editor')),
      '',
    );
    await tester.tap(find.byTooltip('เขียน'));
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

Future<void> _chooseInkManagementAction(
  WidgetTester tester,
  Key actionKey,
) async {
  await tester.tap(find.byKey(const Key('ink-management-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(actionKey));
  await tester.pumpAndSettle();
}

Widget _inkPage({required InkSession session}) {
  return MaterialApp(
    home: Scaffold(
      body: InkPage(session: session, markdown: '# Notes'),
    ),
  );
}

class FakeInkFileStorage implements InkFileStorage {
  final files = <Uri, String>{};

  @override
  Future<String?> read(Uri documentUri) async => files[documentUri];

  @override
  Future<void> write(Uri documentUri, String content) async {
    files[documentUri] = content;
  }

  final backups = <Uri>[];
  bool failBackup = false;

  @override
  Future<void> backup(Uri documentUri) async {
    if (failBackup) throw const FileSystemException('backup failed');
    backups.add(documentUri);
  }
}
