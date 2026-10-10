import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/app/mnote_app.dart';
import 'package:mnote/core/theme/app_theme.dart';
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
    home: MarkdownWorkspacePage(repository: repo),
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
    final previewStyle = tester
        .widget<MarkdownBody>(find.byType(MarkdownBody))
        .styleSheet!;
    final colors = AppTheme.light.colorScheme;
    expect(
      (previewStyle.blockquoteDecoration as BoxDecoration).color,
      colors.primaryContainer,
    );
    expect(
      (previewStyle.codeblockDecoration as BoxDecoration).color,
      colors.surfaceContainerLow,
    );
    expect(
      ((previewStyle.horizontalRuleDecoration as BoxDecoration).border
              as Border)
          .top
          .color,
      colors.outlineVariant,
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
    await tester.pumpWidget(_buildWorkspaceApp());
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

  testWidgets('zoom scales ink only once with the document', (tester) async {
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_buildWorkspaceApp());
    await tester.tap(find.text('จด'));
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
    await tester.tap(find.text('จด'));
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
    expect((pen.value as Drawing).selectedColor, 0x66FFD54F);

    await tester.tap(find.byKey(const Key('ink-color')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('แดง'));
    await tester.pumpAndSettle();
    expect((pen.value as Drawing).selectedColor, 0xFFB3261E);

    await tester.tap(find.byKey(const Key('ink-width')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เส้นหนา'));
    await tester.pumpAndSettle();
    expect(pen.value.selectedWidth, 12);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ink toolbar stays usable on a compact phone', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = InkSession();
    addTearDown(session.dispose);
    await tester.pumpWidget(
      _inkPage(session: session, storage: FakeInkFileStorage()),
    );
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

  testWidgets('clearing ink asks for confirmation and can be undone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_buildWorkspaceApp());
    await tester.tap(find.text('จด'));
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

  testWidgets(
    'saves ink through storage and only marks successful saves clean',
    (tester) async {
      final session = InkSession();
      final storage = FakeInkFileStorage();
      addTearDown(session.dispose);
      session.pen.setSketch(sketch: sketch);

      await tester.pumpWidget(_inkPage(session: session, storage: storage));
      await _chooseInkManagementAction(tester, const Key('ink-save'));

      expect(storage.savedName, 'notes.md.ink.json');
      expect(
        jsonDecode(utf8.decode(storage.savedBytes!))['format'],
        'mnote-ink',
      );
      expect(session.isDirty, isFalse);

      session.pen.clear();
      storage.saveResult = false;
      await tester.pump();
      await _chooseInkManagementAction(tester, const Key('ink-save'));

      expect(session.isDirty, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('opens ink through storage and restores a clean session', (
    tester,
  ) async {
    final source = InkSession()..pen.setSketch(sketch: sketch);
    final target = InkSession();
    final storage = FakeInkFileStorage(
      openBytes: Uint8List.fromList(utf8.encode(source.encode())),
    );
    addTearDown(source.dispose);
    addTearDown(target.dispose);

    await tester.pumpWidget(_inkPage(session: target, storage: storage));
    await _chooseInkManagementAction(tester, const Key('ink-open'));

    expect(storage.openCalls, 1);
    expect(target.pen.currentSketch, sketch);
    expect(target.isDirty, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('autosaves ink on stroke and marks session clean', (
    tester,
  ) async {
    final session = InkSession();
    final storage = FakeInkFileStorage();
    addTearDown(session.dispose);

    await tester.pumpWidget(_inkPage(session: session, storage: storage));
    session.pen.setSketch(sketch: sketch);
    await tester.pump(const Duration(milliseconds: 700));

    expect(storage.savedBytes, isNotNull);
    expect(session.isDirty, isFalse);
  });

  testWidgets('ink survives Markdown deletion, mode switch and resize', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_buildWorkspaceApp());
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

  testWidgets('dispose does not mark session saved if autoSave returns false', (
    tester,
  ) async {
    final session = InkSession();
    session.pen.setSketch(sketch: sketch);
    expect(session.isDirty, isTrue);

    final storage = FakeInkFileStorage();
    storage.saveResult = false;

    await tester.pumpWidget(_inkPage(session: session, storage: storage));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    await tester.pumpAndSettle();

    expect(session.isDirty, isTrue);
  });

  testWidgets('dispose marks session saved when autoSave succeeds', (
    tester,
  ) async {
    final session = InkSession();
    session.pen.setSketch(sketch: sketch);
    expect(session.isDirty, isTrue);

    final storage = FakeInkFileStorage();
    storage.saveResult = true;

    await tester.pumpWidget(_inkPage(session: session, storage: storage));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    await tester.pumpAndSettle();

    expect(session.isDirty, isFalse);
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

Widget _inkPage({
  required InkSession session,
  required InkFileStorage storage,
}) {
  return MaterialApp(
    home: Scaffold(
      body: InkPage(
        session: session,
        markdown: '# Notes',
        name: 'notes.md',
        fileStorage: storage,
      ),
    ),
  );
}

class FakeInkFileStorage implements InkFileStorage {
  FakeInkFileStorage({this.openBytes});

  Uint8List? openBytes;
  Uint8List? savedBytes;
  String? savedName;
  bool saveResult = true;
  int openCalls = 0;

  @override
  Future<Uint8List?> open() async {
    openCalls += 1;
    return openBytes;
  }

  @override
  Future<bool> save({required String name, required Uint8List bytes}) async {
    savedName = name;
    savedBytes = bytes;
    return saveResult;
  }

  @override
  Future<bool> autoSave({required String name, required Uint8List bytes}) async {
    savedName = name;
    savedBytes = bytes;
    return saveResult;
  }

  @override
  Future<Uint8List?> autoLoad({required String name}) async => openBytes;
}
