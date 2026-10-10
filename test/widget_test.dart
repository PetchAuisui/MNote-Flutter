import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/models/note_item.dart';
import 'package:mnote/app/mnote_app.dart';
import 'package:mnote/features/workspace/data/device_image_picker.dart';
import 'package:mnote/features/workspace/domain/document_repository.dart';
import 'package:mnote/features/workspace/domain/markdown_document.dart';
import 'package:mnote/features/workspace/presentation/markdown_live_editor.dart';
import 'package:mnote/features/workspace/presentation/markdown_workspace_page.dart';
import 'package:mnote/features/workspace/presentation/mermaid/mermaid_diagram_view.dart';
import 'package:mnote/features/workspace/presentation/workspace_toolbar_metrics.dart';
import 'package:mnote/screens/note_list_screen.dart';
import 'helpers/fakes.dart';

Widget _buildWorkspaceApp({
  DocumentRepository? repository,
  bool welcome = false,
}) {
  final repo = repository ?? FakeDocumentRepository();
  return MnoteApp(
    documentRepository: repo,
    home: MarkdownWorkspacePage(
      repository: repo,
      initialDocument: welcome
          ? null
          : MarkdownDocument.opened(
              name: 'Untitled.md',
              content: '',
              uri: Uri.file('/tmp/Untitled.md'),
            ),
    ),
  );
}

TextEditingController _source(WidgetTester tester) => tester
    .widget<MarkdownLiveEditor>(find.byType(MarkdownLiveEditor))
    .controller;
final _editor = find.byKey(const Key('markdown-live-block-editor'));
Future<void> _action(WidgetTester tester, String key) async {
  final button = find.byKey(Key(key));
  if (button.evaluate().isEmpty) {
    await tester.tap(find.byKey(const Key('toolbar-more')));
    await tester.pumpAndSettle();
  }
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('loads and renders bundled Welcome showcase', (tester) async {
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_buildWorkspaceApp(welcome: true));
    await tester.pumpAndSettle();
    if (_editor.evaluate().isNotEmpty) {
      await tester.tapAt(tester.getTopLeft(_editor) + const Offset(20, 20));
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
    }
    expect(find.text('Welcome.md'), findsOneWidget);
    expect(find.byKey(const Key('markdown-live-preview')), findsOneWidget);
    expect(find.byType(MermaidDiagramView), findsOneWidget);
    expect(find.byType(Table), findsOneWidget);
    expect(find.text('หัวข้อระดับ H4', findRichText: true), findsOneWidget);
    expect(
      tester.getCenter(find.byKey(const Key('workspace-mode-switcher'))).dx,
      closeTo(512, 0.5),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('workspace returns to full height after keyboard closes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1194, 834);
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(bottom: 20);
    tester.view.padding = const FakeViewPadding(bottom: 20);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_buildWorkspaceApp());
    await tester.pumpAndSettle();
    final surface = find.byKey(const Key('document-surface'));
    final initialBottom = tester.getBottomLeft(surface).dy;
    expect(initialBottom, closeTo(834 - 20 - 8, 0.1));
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    tester.view.padding = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(surface).dy, lessThanOrEqualTo(834 - 320));
    tester.view.viewInsets = FakeViewPadding.zero;
    tester.view.padding = const FakeViewPadding(bottom: 20);
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(surface).dy, closeTo(initialBottom, 0.1));
    await tester.tap(find.byTooltip('เขียน'));
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(surface).dy, closeTo(initialBottom, 0.1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty workspace exposes editor and disables undo', (
    tester,
  ) async {
    await tester.pumpWidget(_buildWorkspaceApp());
    expect(find.text('Untitled.md'), findsOneWidget);
    expect(_editor, findsOneWidget);
    expect(find.byTooltip('Markdown'), findsOneWidget);
    expect(find.byTooltip('เขียน'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('toolbar-undo')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('toolbar-redo')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('undoes and redoes editor changes', (tester) async {
    await tester.pumpWidget(_buildWorkspaceApp());
    await tester.enterText(_editor, 'Draft');
    await tester.pumpAndSettle();
    await _action(tester, 'toolbar-undo');
    expect(_source(tester).text, isEmpty);
    await _action(tester, 'toolbar-redo');
    expect(_source(tester).text, 'Draft');
  });

  testWidgets('undoes formatting while preserving selected text', (
    tester,
  ) async {
    await tester.pumpWidget(_buildWorkspaceApp());
    await tester.enterText(_editor, 'word');
    tester.widget<TextField>(_editor).controller!.selection =
        const TextSelection(baseOffset: 0, extentOffset: 4);
    await _action(tester, 'toolbar-bold');
    expect(_source(tester).text, '**word**');
    await _action(tester, 'toolbar-undo');
    expect(_source(tester).text, 'word');
  });

  for (var level = 1; level <= 4; level++) {
    testWidgets('applies heading level $level through labeled dropdown', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1024, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_buildWorkspaceApp());
      await tester.enterText(_editor, 'Project title');
      await tester.tap(find.byKey(const Key('toolbar-heading')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('หัวข้อ $level').last);
      await tester.pumpAndSettle();
      expect(_source(tester).text, '${'#' * level} Project title');
      expect(find.text('หัวข้อ $level'), findsOneWidget);
    });
  }

  for (final ordered in [false, true]) {
    testWidgets(
      'formats selected lines as ${ordered ? 'ordered' : 'bulleted'} list',
      (tester) async {
        await tester.pumpWidget(_buildWorkspaceApp());
        await tester.enterText(_editor, 'first\nsecond\nthird');
        tester.widget<TextField>(_editor).controller!.selection =
            const TextSelection(baseOffset: 0, extentOffset: 18);
        await _action(
          tester,
          ordered ? 'toolbar-ordered-list' : 'toolbar-list',
        );
        expect(
          _source(tester).text,
          ordered
              ? '1. first\n2. second\n3. third'
              : '- first\n- second\n- third',
        );
      },
    );
  }

  testWidgets('indents and outdents selected list item', (tester) async {
    await tester.pumpWidget(_buildWorkspaceApp());
    await tester.enterText(_editor, '- parent\n- child');
    tester.widget<TextField>(_editor).controller!.selection =
        const TextSelection(baseOffset: 9, extentOffset: 16);
    await _action(tester, 'toolbar-indent-list');
    expect(_source(tester).text, '- parent\n  - child');
    await _action(tester, 'toolbar-outdent-list');
    expect(_source(tester).text, '- parent\n- child');
  });

  testWidgets('inserts BR and HR Markdown tokens', (tester) async {
    await tester.pumpWidget(_buildWorkspaceApp());
    await tester.enterText(_editor, 'first');
    await _action(tester, 'toolbar-line-break');
    await _action(tester, 'toolbar-horizontal-rule');
    expect(_source(tester).text, 'first<br>\n---\n');
  });

  testWidgets('updates document line statistics', (tester) async {
    await tester.pumpWidget(_buildWorkspaceApp());
    await tester.enterText(_editor, '# Title\n\nParagraph');
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const Key('document-statistics'))).data,
      contains('3 บรรทัด'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('renames a document from app bar', (tester) async {
    await tester.pumpWidget(_buildWorkspaceApp());
    await tester.tap(find.byKey(const Key('document-title')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('document-title-field')),
      'Project notes',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('Project notes.md'), findsOneWidget);
    expect(find.text('ยังไม่ได้บันทึก'), findsOneWidget);
    expect(find.byKey(const Key('document-title-field')), findsNothing);
  });

  testWidgets('renders Markdown when editor loses focus', (tester) async {
    await tester.pumpWidget(_buildWorkspaceApp());
    await tester.enterText(_editor, '# Hello Mnote');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    // autosave หน่วง 600ms หลังพิมพ์
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Hello Mnote', findRichText: true), findsOneWidget);
    expect(find.text('บันทึกแล้ว'), findsOneWidget);
  });

  for (final width in [320.0, 1024.0, 1400.0]) {
    testWidgets('toolbar actions remain accessible at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_buildWorkspaceApp());
      await tester.pumpAndSettle();
      expect(
        tester
            .getSize(find.byKey(const Key('markdown-formatting-toolbar')))
            .height,
        workspaceToolbarControlSize,
      );
      await _action(tester, 'toolbar-bold');
      expect(_source(tester).text, '**ข้อความตัวหนา**');
      await _action(tester, 'toolbar-table');
      expect(find.byKey(const Key('table-columns')), findsOneWidget);
      await tester.tap(find.text('ยกเลิก'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('navigates from notes list to new document and back', (
    tester,
  ) async {
    final repo = FakeDocumentRepository();
    await tester.pumpWidget(MnoteApp(documentRepository: repo));
    await tester.pumpAndSettle();
    expect(find.byType(NoteListScreen), findsOneWidget);
    await tester.tap(find.text('ใหม่'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เอกสาร Markdown ใหม่ (.md)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('สร้างไฟล์'));
    await tester.pumpAndSettle();
    expect(find.byType(MarkdownWorkspacePage), findsOneWidget);
    expect(find.byType(MarkdownLiveEditor), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(NoteListScreen), findsOneWidget);
  });

  testWidgets(
    'toolbar image button inserts image and more actions menu supports import file',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = FakeDocumentRepository();
      final imagePicker = FakeDeviceImagePicker(
        MarkdownImageReference(alt: 'photo', uri: Uri.parse('photo.png')),
      );
      await tester.pumpWidget(
        MnoteApp(
          documentRepository: repo,
          home: MarkdownWorkspacePage(
            repository: repo,
            imagePicker: imagePicker,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify redundant toolbar-add-button does not exist
      expect(find.byKey(const Key('toolbar-add-button')), findsNothing);

      // Tap toolbar image button directly
      final imageButton = find.byKey(const Key('toolbar-image'));
      expect(imageButton, findsOneWidget);
      await tester.tap(imageButton);
      await tester.pumpAndSettle();

      expect(imagePicker.pickCount, 1);
      expect(find.textContaining('![photo](photo.png)'), findsOneWidget);

      // Tap more actions menu and select import file
      await tester.tap(find.byTooltip('คำสั่งเพิ่มเติม'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('toolbar-add-file')), findsOneWidget);
      expect(find.text('แทรกเนื้อหาจากไฟล์'), findsOneWidget);
      await tester.tap(find.byKey(const Key('toolbar-add-file')));
      await tester.pumpAndSettle();

      expect(repo.openCalls, 1);
    },
  );

  testWidgets(
    'moving document to trash only trashes the matching document by uri',
    (tester) async {
      final repo = FakeDocumentRepository();
      final uri1 = Uri.file('/tmp/folder1/note.md');
      final uri2 = Uri.file('/tmp/folder2/note.md');

      repo.storedMetadata = LibraryMetadata(
        documents: [
          DocumentItem(
            id: uri1.toString(),
            name: 'note.md',
            content: 'content 1',
            updatedAt: DateTime.now(),
            uri: uri1,
            isTrash: false,
          ),
          DocumentItem(
            id: uri2.toString(),
            name: 'note.md',
            content: 'content 2',
            updatedAt: DateTime.now(),
            uri: uri2,
            isTrash: false,
          ),
        ],
      );

      final currentDoc = MarkdownDocument.opened(
        name: 'note.md',
        content: 'content 1',
        uri: uri1,
      );

      await tester.pumpWidget(
        MnoteApp(
          documentRepository: repo,
          home: MarkdownWorkspacePage(
            repository: repo,
            initialDocument: currentDoc,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('คำสั่งเพิ่มเติม'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ย้ายไปถังขยะ'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'ย้ายไปถังขยะ'));
      await tester.pumpAndSettle();

      final docs = repo.storedMetadata!.documents;
      final doc1 = docs.firstWhere((d) => d.uri == uri1);
      final doc2 = docs.firstWhere((d) => d.uri == uri2);

      expect(doc1.isTrash, isTrue);
      expect(doc2.isTrash, isFalse);
    },
  );

  testWidgets('showing snackbar and not popping when moving to trash fails', (
    tester,
  ) async {
    final repo = FakeDocumentRepository();
    final uri = Uri.file('/tmp/folder1/note.md');
    repo.storedMetadata = LibraryMetadata(
      documents: [
        DocumentItem(
          id: uri.toString(),
          name: 'note.md',
          content: 'content',
          updatedAt: DateTime.now(),
          uri: uri,
          isTrash: false,
        ),
      ],
    );
    repo.metadataError = Exception('Storage failure');

    final currentDoc = MarkdownDocument.opened(
      name: 'note.md',
      content: 'content',
      uri: uri,
    );

    await tester.pumpWidget(
      MnoteApp(
        documentRepository: repo,
        home: MarkdownWorkspacePage(
          repository: repo,
          initialDocument: currentDoc,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('คำสั่งเพิ่มเติม'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ย้ายไปถังขยะ'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'ย้ายไปถังขยะ'));
    await tester.pumpAndSettle();

    expect(find.text('ไม่สามารถย้ายเอกสารไปยังถังขยะได้'), findsOneWidget);
    expect(find.byType(MarkdownWorkspacePage), findsOneWidget);
  });
}
