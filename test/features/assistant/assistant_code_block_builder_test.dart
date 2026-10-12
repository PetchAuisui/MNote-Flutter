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

  Widget buildTestWidget({required String data}) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MarkdownBody(
            data: data,
            builders: {'code': AssistantCodeBlockBuilder()},
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

    // 5. บล็อกภาษาอื่นไม่ถูกแตะ: data: '```dart\nvoid main() {}\n```' → ไม่เจอ assistant-mermaid-card และเจอข้อความ void main() {}
    testWidgets(
      '5. non-mermaid code blocks fallback to default markdown rendering',
      (tester) async {
        const data = '```dart\nvoid main() {}\n```';
        await tester.pumpWidget(buildTestWidget(data: data));

        expect(find.byKey(const Key('assistant-mermaid-card')), findsNothing);
        expect(find.textContaining('void main() {}'), findsOneWidget);
      },
    );
  });
}
