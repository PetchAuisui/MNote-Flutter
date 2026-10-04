import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/workspace/presentation/mermaid/mermaid.dart';

void main() {
  group('Mermaid Import Dialog Tests', () {
    String? copied;

    setUp(() {
      copied = null;
    });

    void setupClipboardMock(WidgetTester tester) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
    }

    Widget buildTestWidget({required String fileName, required String source}) {
      return MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showMermaidImportDialog(
                context,
                fileName: fileName,
                source: source,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
    }

    testWidgets(
      'จอแท็บเล็ต 1024x768: แสดง dialog, ชื่อไฟล์, และ preview fallback',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          buildTestWidget(fileName: 'flow.mmd', source: 'graph TD\n  A-->B'),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('mermaid-import-dialog')), findsOneWidget);
        expect(find.text('flow.mmd'), findsOneWidget);
        expect(
          find.byKey(const Key('mermaid-diagram-fallback')),
          findsOneWidget,
        );
      },
    );

    testWidgets('กดดูโค้ดแล้วแสดง SelectableText', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const sourceCode = 'graph TD\n  A-->B';
      await tester.pumpWidget(
        buildTestWidget(fileName: 'flow.mmd', source: sourceCode),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mermaid-import-code-toggle')));
      await tester.pumpAndSettle();

      final codeInToggle = find.descendant(
        of: find.byKey(const Key('mermaid-import-code-toggle')),
        matching: find.widgetWithText(SelectableText, sourceCode),
      );
      expect(codeInToggle, findsOneWidget);
    });

    testWidgets(
      'กดคัดลอก: ส่งข้อความครอบรั้วเข้า Clipboard, ปิดหน้าต่าง และแสดง SnackBar',
      (tester) async {
        setupClipboardMock(tester);

        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const sourceCode = 'graph TD\n  A-->B';
        await tester.pumpWidget(
          buildTestWidget(fileName: 'flow.mmd', source: sourceCode),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('mermaid-import-copy')));
        await tester.pumpAndSettle();

        expect(copied, equals(buildMermaidFencedBlock(sourceCode)));
        expect(find.byKey(const Key('mermaid-import-dialog')), findsNothing);
        expect(find.text('คัดลอกแล้ว วางในโน้ตได้เลย'), findsOneWidget);
      },
    );

    testWidgets('กดยกเลิก: หน้าต่างปิด และไม่มีการคัดลอกข้อมูล', (
      tester,
    ) async {
      setupClipboardMock(tester);

      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestWidget(fileName: 'flow.mmd', source: 'graph TD\n  A-->B'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mermaid-import-cancel')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mermaid-import-dialog')), findsNothing);
      expect(copied, isNull);
    });

    testWidgets(
      'จอมือถือ 320x640: แสดงแบบ fullscreen dialog มี AppBar และคัดลอกได้',
      (tester) async {
        setupClipboardMock(tester);

        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const sourceCode = 'graph TD\n  A-->B';
        await tester.pumpWidget(
          buildTestWidget(fileName: 'flow.mmd', source: sourceCode),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.byType(AppBar), findsOneWidget);

        await tester.tap(find.byKey(const Key('mermaid-import-copy')));
        await tester.pumpAndSettle();

        expect(copied, equals(buildMermaidFencedBlock(sourceCode)));
        expect(find.byKey(const Key('mermaid-import-dialog')), findsNothing);
      },
    );
  });
}
