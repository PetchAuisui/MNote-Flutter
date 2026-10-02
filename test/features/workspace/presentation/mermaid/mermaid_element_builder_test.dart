import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/workspace/presentation/mermaid/mermaid_element_builder.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  group('MermaidElementBuilder', () {
    testWidgets('บล็อก mermaid มีเนื้อหา ต้องแสดง fallback view', (
      tester,
    ) async {
      const data = '```mermaid\ngraph TD\n  A-->B\n```';
      await tester.pumpWidget(
        _wrap(
          MarkdownBody(data: data, builders: {'code': MermaidElementBuilder()}),
        ),
      );

      expect(find.byKey(const Key('mermaid-diagram-fallback')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('บล็อก Mermaid ตัวพิมพ์ใหญ่ ต้องแสดง fallback view', (
      tester,
    ) async {
      const data = '```Mermaid\ngraph TD\n  A-->B\n```';
      await tester.pumpWidget(
        _wrap(
          MarkdownBody(data: data, builders: {'code': MermaidElementBuilder()}),
        ),
      );

      expect(find.byKey(const Key('mermaid-diagram-fallback')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('บล็อกภาษาอื่น (dart) ต้องไม่แสดง Mermaid view', (
      tester,
    ) async {
      const data = '```dart\nvoid main() {}\n```';
      await tester.pumpWidget(
        _wrap(
          MarkdownBody(data: data, builders: {'code': MermaidElementBuilder()}),
        ),
      );

      expect(find.byKey(const Key('mermaid-diagram-fallback')), findsNothing);
      expect(
        find.textContaining('void main() {}', findRichText: true),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('บล็อกโค้ดไม่ระบุภาษา ต้องไม่แสดง Mermaid view', (
      tester,
    ) async {
      const data = '```\nplain text code\n```';
      await tester.pumpWidget(
        _wrap(
          MarkdownBody(data: data, builders: {'code': MermaidElementBuilder()}),
        ),
      );

      expect(find.byKey(const Key('mermaid-diagram-fallback')), findsNothing);
      expect(
        find.textContaining('plain text code', findRichText: true),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('inline code ในข้อความ ต้องไม่แสดง Mermaid view', (
      tester,
    ) async {
      const data = 'นี่คือตัวแปร `x` ในข้อความ';
      await tester.pumpWidget(
        _wrap(
          MarkdownBody(data: data, builders: {'code': MermaidElementBuilder()}),
        ),
      );

      expect(find.byKey(const Key('mermaid-diagram-fallback')), findsNothing);
      expect(find.textContaining('x'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('มี mermaid 2 บล็อกในเอกสารเดียว ต้องแสดง fallback 2 อัน', (
      tester,
    ) async {
      const data =
          '```mermaid\n'
          'graph TD\n'
          '  A-->B\n'
          '```\n'
          'ข้อความคั่น\n'
          '```mermaid\n'
          'graph LR\n'
          '  C-->D\n'
          '```';
      await tester.pumpWidget(
        _wrap(
          MarkdownBody(data: data, builders: {'code': MermaidElementBuilder()}),
        ),
      );

      expect(
        find.byKey(const Key('mermaid-diagram-fallback')),
        findsNWidgets(2),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('บล็อก mermaid ว่างเปล่า ต้องแสดงสถานะว่าง', (tester) async {
      const data = '```mermaid\n\n```';
      await tester.pumpWidget(
        _wrap(
          MarkdownBody(data: data, builders: {'code': MermaidElementBuilder()}),
        ),
      );

      expect(find.byKey(const Key('mermaid-diagram-empty')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
