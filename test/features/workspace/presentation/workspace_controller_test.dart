import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/workspace/domain/document_repository.dart';
import 'package:mnote/features/workspace/domain/markdown_document.dart';
import 'package:mnote/features/workspace/presentation/workspace_controller.dart';

import '../../../helpers/fakes.dart';

void main() {
  test(
    'upgrades only untouched bundled Welcome and preserves edits and files',
    () {
      final controller = WorkspaceController(
        FakeDocumentRepository(),
        initialDocument: MarkdownDocument.example('old'),
      );
      addTearDown(controller.dispose);
      expect(controller.upgradeExample('old', 'new'), isTrue);
      expect(controller.document.content, 'new');
      expect(controller.document.isDirty, isFalse);
      controller.updateContent('my edits');
      expect(controller.upgradeExample('my edits', 'replacement'), isFalse);
      expect(controller.document.content, 'my edits');
      final fileController = WorkspaceController(
        FakeDocumentRepository(),
        initialDocument: MarkdownDocument.opened(
          name: 'Welcome.md',
          content: 'old',
          uri: Uri.file('/tmp/Welcome.md'),
        ),
      );
      addTearDown(fileController.dispose);
      expect(fileController.upgradeExample('old', 'new'), isFalse);
    },
  );
  test('opens a document and changes mode', () async {
    final repository = FakeDocumentRepository()
      ..openResult = MarkdownDocument.opened(
        name: 'guide.md',
        content: '# Guide',
        uri: Uri.file('/tmp/guide.md'),
      );
    final controller = WorkspaceController(repository);
    addTearDown(controller.dispose);

    expect(await controller.openDocument(), isTrue);
    controller.setMode(WorkspaceMode.preview);

    expect(controller.document.name, 'guide.md');
    expect(controller.mode, WorkspaceMode.preview);
    expect(controller.isBusy, isFalse);
  });

  test('reports repository errors without replacing the document', () async {
    final repository = FakeDocumentRepository()
      ..error = const DocumentReadException('อ่านไฟล์ไม่ได้');
    final controller = WorkspaceController(repository);
    addTearDown(controller.dispose);

    expect(await controller.openDocument(), isFalse);

    expect(controller.document.name, 'Untitled.md');
    expect(controller.errorMessage, 'อ่านไฟล์ไม่ได้');
    expect(controller.isBusy, isFalse);
  });

  test('saving clears the dirty state', () async {
    final repository = FakeDocumentRepository();
    final controller = WorkspaceController(repository);
    addTearDown(controller.dispose);
    controller.updateContent('# Draft');

    expect(controller.document.isDirty, isTrue);
    expect(await controller.save(), isTrue);

    expect(controller.document.isDirty, isFalse);
    expect(repository.saveCalls, 1);
  });

  test('renames the current document', () {
    final controller = WorkspaceController(FakeDocumentRepository());
    addTearDown(controller.dispose);

    controller.updateName('ideas.md');

    expect(controller.document.name, 'ideas.md');
    expect(controller.document.isDirty, isTrue);
  });
}
