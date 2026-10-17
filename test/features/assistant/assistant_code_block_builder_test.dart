import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/assistant/presentation/assistant_code_block_builder.dart';
import 'package:mnote/features/workspace/presentation/mermaid/mermaid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String? clipboardContent;

  setUp(() {
    clipboardContent = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            final arguments = methodCall.arguments as Map?;
            clipboardContent = arguments?['text'] as String?;
            return null;
          }
          if (methodCall.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': clipboardContent};
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Widget buildTestWidget({required String data, bool isStreaming = false}) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MarkdownBody(
            // เหมือน _MessageBubble: เปลี่ยน key ตาม isStreaming
            key: ValueKey(isStreaming),
            data: data,
            builders: {
              'code': AssistantCodeBlockBuilder(isStreaming: isStreaming),
            },
          ),
        ),
      ),
    );
  }

  group('AssistantCodeBlockBuilder & AssistantMermaidCard Tests', () {
    // 1. เริ่มต้นเป็นภาพ: เจอ assistant-mermaid-card และ mermaid-diagram-fallback และไม่เจอ assistant-mermaid-code
    testWidgets(
      '1. initially displays diagram fallback view and not raw code container',
      (tester) async {
        final data = buildMermaidFencedBlock('flowchart TD\nA-->B');
        await tester.pumpWidget(buildTestWidget(data: data));

        expect(find.byKey(const Key('assistant-mermaid-card')), findsOneWidget);
        expect(
          find.byKey(const Key('mermaid-diagram-fallback')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('assistant-mermaid-code')), findsNothing);
      },
    );

    // 2. กดโค้ด: tap assistant-mermaid-show-code แล้ว pumpAndSettle → เจอ assistant-mermaid-code ที่มีข้อความ A-->B และไม่เจอ mermaid-diagram-fallback
    testWidgets(
      '2. switching to code view displays code block and hides diagram',
      (tester) async {
        final data = buildMermaidFencedBlock('flowchart TD\nA-->B');
        await tester.pumpWidget(buildTestWidget(data: data));

        await tester.tap(find.byKey(const Key('assistant-mermaid-show-code')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('assistant-mermaid-code')), findsOneWidget);
        expect(find.textContaining('A-->B'), findsOneWidget);
        expect(find.byKey(const Key('mermaid-diagram-fallback')), findsNothing);
      },
    );

    // 3. กดกลับเป็นภาพ: tap assistant-mermaid-show-diagram → กลับมาเจอ mermaid-diagram-fallback
    testWidgets(
      '3. switching back to diagram view restores diagram fallback view',
      (tester) async {
        final data = buildMermaidFencedBlock('flowchart TD\nA-->B');
        await tester.pumpWidget(buildTestWidget(data: data));

        // สลับไปโค้ด
        await tester.tap(find.byKey(const Key('assistant-mermaid-show-code')));
        await tester.pumpAndSettle();

        // สลับกลับมาเป็นภาพ
        await tester.tap(
          find.byKey(const Key('assistant-mermaid-show-diagram')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('mermaid-diagram-fallback')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('assistant-mermaid-code')), findsNothing);
      },
    );

    // 4. คัดลอก: tap assistant-mermaid-copy แล้ว pump() → ตรวจ clipboard และไอคอนที่เปลี่ยน แล้วรอ timer คืนค่าเดิม
    testWidgets(
      '4. copy button copies fenced code to clipboard and updates icon state for 2 seconds',
      (tester) async {
        const source = 'flowchart TD\nA-->B';
        final data = buildMermaidFencedBlock(source);
        await tester.pumpWidget(buildTestWidget(data: data));

        // ไอคอนเริ่มต้นเป็น content_copy
        expect(find.byIcon(Icons.content_copy_rounded), findsOneWidget);
        expect(find.byIcon(Icons.check_rounded), findsNothing);

        await tester.tap(find.byKey(const Key('assistant-mermaid-copy')));
        await tester.pump();

        // ตรวจสอบว่าคัดลอกติด fence ```mermaid
        expect(clipboardContent, startsWith('```mermaid'));
        expect(clipboardContent, contains('A-->B'));
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);

        // รอครบ 2 วินาทีให้ Timer ทำงาน
        await tester.pump(const Duration(seconds: 2));

        // ไอคอนกลับมาเป็นตัวเดิม
        expect(find.byIcon(Icons.content_copy_rounded), findsOneWidget);
        expect(find.byIcon(Icons.check_rounded), findsNothing);
      },
    );

    // 5. บล็อกภาษาอื่นแสดงเป็นการ์ดโค้ด พร้อมชื่อภาษา
    testWidgets(
      '5. non-mermaid fenced block shows code card with language label',
      (tester) async {
        const data = '```dart\nvoid main() {}\n```';
        await tester.pumpWidget(buildTestWidget(data: data));

        expect(find.byKey(const Key('assistant-mermaid-card')), findsNothing);
        expect(find.byKey(const Key('assistant-code-card')), findsOneWidget);
        expect(
          tester
              .widget<Text>(find.byKey(const Key('assistant-code-language')))
              .data,
          'dart',
        );
        expect(find.textContaining('void main() {}'), findsOneWidget);
      },
    );

    // 6. ระหว่างสตรีมแสดงเป็นโค้ด พอจบสตรีมสลับเป็นภาพอัตโนมัติ
    testWidgets(
      '6. displays code while streaming and switches to diagram when streaming ends',
      (tester) async {
        final data = buildMermaidFencedBlock('flowchart TD\nA-->B');
        await tester.pumpWidget(buildTestWidget(data: data, isStreaming: true));

        expect(find.byKey(const Key('assistant-mermaid-code')), findsOneWidget);
        expect(find.byKey(const Key('mermaid-diagram-fallback')), findsNothing);

        await tester.pumpWidget(
          buildTestWidget(data: data, isStreaming: false),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('mermaid-diagram-fallback')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('assistant-mermaid-code')), findsNothing);
      },
    );
    // 7. คัดลอกจากการ์ดโค้ดได้โค้ดล้วน ไม่มีรั้ว ```
    testWidgets('7. code card copy button copies plain code without fences', (
      tester,
    ) async {
      const data = '```dart\nvoid main() {}\n```';
      await tester.pumpWidget(buildTestWidget(data: data));

      await tester.tap(find.byKey(const Key('assistant-code-copy')));
      await tester.pump();

      expect(clipboardContent, 'void main() {}');
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });

    // 8. บล็อกที่ไม่ระบุภาษาขึ้นป้ายว่า "โค้ด"
    testWidgets('8. fenced block without language shows default label', (
      tester,
    ) async {
      const data = '```\nhello\n```';
      await tester.pumpWidget(buildTestWidget(data: data));

      expect(find.byKey(const Key('assistant-code-card')), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('assistant-code-language')))
            .data,
        'โค้ด',
      );
    });

    // 9. โค้ดในบรรทัดไม่กลายเป็นการ์ด
    testWidgets('9. inline code is not wrapped in a code card', (tester) async {
      const data = 'ใช้ `print()` เพื่อแสดงผล';
      await tester.pumpWidget(buildTestWidget(data: data));

      expect(find.byKey(const Key('assistant-code-card')), findsNothing);
      expect(
        find.textContaining('print()', findRichText: true),
        findsOneWidget,
      );
    });
  });
}
