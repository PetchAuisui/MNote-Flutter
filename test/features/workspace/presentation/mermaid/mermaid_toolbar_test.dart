import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/app/mnote_app.dart';
import 'package:mnote/features/workspace/data/mermaid_file_source.dart';
import 'package:mnote/features/workspace/presentation/markdown_workspace_page.dart';
import 'package:mnote/features/workspace/presentation/mermaid/mermaid.dart';

import '../../../../helpers/fakes.dart';

class _FakeMermaidFileSource implements MermaidFileSource {
  _FakeMermaidFileSource(this.result);
  final PickedMermaidFile? result;

  @override
  Future<PickedMermaidFile?> pick() async => result;
}

/// เปิดหน้า workspace ที่ขนาดจอกำหนด แล้วล้าง editor เป็น [text]
///
/// หน้า workspace โหลด welcome.md เป็นเนื้อหาเริ่มต้นเอง จึงต้องแทนด้วยข้อความที่รู้ค่า
/// และรอ 600ms หลังแก้ข้อความ เพราะ Flutter รวมการแก้ที่ห่างกันไม่ถึง 500ms
/// เป็นประวัติ undo ก้อนเดียว [fileSource] ใช้แทนตัวเลือกไฟล์จริง
Future<void> _pumpWorkspace(
  WidgetTester tester, {
  required Size size,
  String text = '',
  MermaidFileSource? fileSource,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final repo = FakeDocumentRepository();
  await tester.pumpWidget(
    MnoteApp(
      documentRepository: repo,
      home: MarkdownWorkspacePage(
        repository: repo,
        mermaidFileSource: fileSource ?? _FakeMermaidFileSource(null),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final editor = find.byKey(const Key('markdown-editor'));
  await tester.tap(editor);
  await tester.pump(const Duration(milliseconds: 600));
  await tester.enterText(editor, text);
  await tester.pump(const Duration(milliseconds: 600));
}

String _editorText(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(const Key('markdown-editor')))
    .controller!
    .text;

final _flowchart = mermaidTemplates.firstWhere((t) => t.id == 'flowchart');

void main() {
  group('Mermaid Toolbar Integration Tests', () {
    testWidgets(
      'จอแท็บเล็ต 1024x768: เจอ Key toolbar-diagram กดแล้วเห็นครบ 3 แบบ และแทรกข้อความถูกต้อง',
      (tester) async {
        await _pumpWorkspace(tester, size: const Size(1024, 768));

        final diagramButton = find.byKey(const Key('toolbar-diagram'));
        expect(diagramButton, findsOneWidget);

        await tester.tap(diagramButton);
        await tester.pumpAndSettle();

        for (final template in mermaidTemplates) {
          expect(
            find.byKey(Key('toolbar-diagram-${template.id}')),
            findsOneWidget,
          );
          expect(find.text(template.label), findsOneWidget);
        }

        await tester.tap(find.text(_flowchart.label));
        await tester.pumpAndSettle();

        final expectedText = '${buildMermaidFencedBlock(_flowchart.source)}\n';
        expect(_editorText(tester), equals(expectedText));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'มีข้อความอยู่แล้ว: แทรก template ต่อท้ายพร้อมขึ้นบรรทัดใหม่อัตโนมัติ',
      (tester) async {
        await _pumpWorkspace(
          tester,
          size: const Size(1024, 768),
          text: 'first',
        );

        await tester.tap(find.byKey(const Key('toolbar-diagram')));
        await tester.pumpAndSettle();

        await tester.tap(find.text(_flowchart.label));
        await tester.pumpAndSettle();

        final expectedText =
            'first\n${buildMermaidFencedBlock(_flowchart.source)}\n';
        expect(_editorText(tester), equals(expectedText));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'undo: หลังแทรก template กด toolbar-undo ข้อความกลับเป็นค่าเดิม',
      (tester) async {
        await _pumpWorkspace(tester, size: const Size(1024, 768));

        await tester.tap(find.byKey(const Key('toolbar-diagram')));
        await tester.pumpAndSettle();

        await tester.tap(find.text(_flowchart.label));
        await tester.pumpAndSettle();

        // รอ 600ms เพื่อแยกกลุ่มประวัติ undo ระหว่างการแทรกกับคำสั่งถัดไป
        await tester.pump(const Duration(milliseconds: 600));

        final undoButton = find.byKey(const Key('toolbar-undo'));
        expect(undoButton, findsOneWidget);

        await tester.tap(undoButton);
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();

        expect(_editorText(tester), equals(''));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'จอมือถือ 320x640: ยุบลงปุ่ม ... (toolbar-more) แล้วยังแทรกได้',
      (tester) async {
        await _pumpWorkspace(tester, size: const Size(320, 640));

        final moreButton = find.byKey(const Key('toolbar-more'));
        expect(moreButton, findsOneWidget);

        await tester.tap(moreButton);
        await tester.pumpAndSettle();

        final item = find.text(_flowchart.label);
        expect(item, findsOneWidget);

        await tester.ensureVisible(item);
        await tester.pumpAndSettle();
        await tester.tap(item);
        await tester.pumpAndSettle();

        final expectedText = '${buildMermaidFencedBlock(_flowchart.source)}\n';
        expect(_editorText(tester), equals(expectedText));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'ครบวงจร: แทรก template แล้วกดแท็บแสดงผล เจอ mermaid-diagram-fallback',
      (tester) async {
        await _pumpWorkspace(tester, size: const Size(1024, 768));

        await tester.tap(find.byKey(const Key('toolbar-diagram')));
        await tester.pumpAndSettle();

        await tester.tap(find.text(_flowchart.label));
        await tester.pumpAndSettle();

        final previewTab = find.text('แสดงผล');
        await tester.tap(previewTab);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('mermaid-diagram-fallback')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('6. เมนูไดอะแกรมมี Key toolbar-diagram-import', (tester) async {
      await _pumpWorkspace(tester, size: const Size(1024, 768));

      await tester.tap(find.byKey(const Key('toolbar-diagram')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('toolbar-diagram-import')), findsOneWidget);
      expect(find.text('นำเข้าจากไฟล์ .mmd…'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '7. ไฟล์ถูกต้อง: เปิด dialog และ editor ยังคงว่าง (ไม่แทรกเอง)',
      (tester) async {
        final fakeSource = _FakeMermaidFileSource(
          PickedMermaidFile(
            name: 'flow.mmd',
            bytes: Uint8List.fromList(utf8.encode('graph TD\n  A-->B')),
          ),
        );

        await _pumpWorkspace(
          tester,
          size: const Size(1024, 768),
          fileSource: fakeSource,
        );

        await tester.tap(find.byKey(const Key('toolbar-diagram')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('toolbar-diagram-import')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('mermaid-import-dialog')), findsOneWidget);
        expect(find.text('flow.mmd'), findsOneWidget);
        expect(_editorText(tester), equals(''));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '8. ไฟล์ .txt: แจ้งเตือนข้อความเรื่องนามสกุล และไม่เปิด dialog',
      (tester) async {
        final fakeSource = _FakeMermaidFileSource(
          PickedMermaidFile(
            name: 'invalid.txt',
            bytes: Uint8List.fromList(utf8.encode('graph TD\n  A-->B')),
          ),
        );

        await _pumpWorkspace(
          tester,
          size: const Size(1024, 768),
          fileSource: fakeSource,
        );

        await tester.tap(find.byKey(const Key('toolbar-diagram')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('toolbar-diagram-import')));
        await tester.pumpAndSettle();

        expect(find.text('รองรับเฉพาะไฟล์ .mmd หรือ .mermaid'), findsOneWidget);
        expect(find.byKey(const Key('mermaid-import-dialog')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('9. ผู้ใช้กดยกเลิก: ไม่เปิด dialog และไม่มีแถบแจ้งเตือน', (
      tester,
    ) async {
      final fakeSource = _FakeMermaidFileSource(null);

      await _pumpWorkspace(
        tester,
        size: const Size(1024, 768),
        fileSource: fakeSource,
      );

      await tester.tap(find.byKey(const Key('toolbar-diagram')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('toolbar-diagram-import')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mermaid-import-dialog')), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
