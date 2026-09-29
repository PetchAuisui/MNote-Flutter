import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/workspace/domain/document_repository.dart';
import 'package:mnote/features/workspace/domain/markdown_document.dart';
import 'package:mnote/features/workspace/presentation/workspace_controller.dart';

import '../../../helpers/fakes.dart';

void main() {
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
}
