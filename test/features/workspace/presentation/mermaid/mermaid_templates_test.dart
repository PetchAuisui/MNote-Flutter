import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/workspace/presentation/mermaid/mermaid.dart';

void main() {
  group('Mermaid Templates Unit Tests', () {
    test('มี template 3 ตัว และ id ไม่ซ้ำกัน', () {
      expect(mermaidTemplates.length, 3);
      final ids = mermaidTemplates.map((t) => t.id).toSet();
      expect(ids.length, 3);
    });

    test('ทุกตัว label ไม่ว่าง และไม่มีช่องว่างหรือบรรทัดว่างเกินหัวท้าย', () {
      for (final template in mermaidTemplates) {
        expect(template.label.trim().isNotEmpty, isTrue);
        expect(
          normalizeMermaidSource(template.source),
          equals(template.source),
        );
      }
    });

    test('บรรทัดแรกของแต่ละตัวขึ้นต้นตรงตามชนิดของไดอะแกรม', () {
      final flowchart = mermaidTemplates.firstWhere((t) => t.id == 'flowchart');
      final sequence = mermaidTemplates.firstWhere((t) => t.id == 'sequence');
      final classDiagram = mermaidTemplates.firstWhere((t) => t.id == 'class');

      expect(
        flowchart.source.split('\n').first.trim(),
        startsWith('flowchart'),
      );
      expect(
        sequence.source.split('\n').first.trim(),
        startsWith('sequenceDiagram'),
      );
      expect(
        classDiagram.source.split('\n').first.trim(),
        startsWith('classDiagram'),
      );
    });

    test(
      'buildMermaidFencedBlock ทำงานถูกต้องกับข้อความทั่วไปและ backticks ซ้อน',
      () {
        expect(
          buildMermaidFencedBlock('graph TD'),
          equals('```mermaid\ngraph TD\n```'),
        );

        final withThreeTicks = 'graph TD\nnode["text with ``` inside"]';
        expect(
          buildMermaidFencedBlock(withThreeTicks),
          equals('````mermaid\n$withThreeTicks\n````'),
        );

        final withFourTicks = 'graph TD\nnode["text with ```` inside"]';
        expect(
          buildMermaidFencedBlock(withFourTicks),
          equals('`````mermaid\n$withFourTicks\n`````'),
        );
      },
    );
  });

  group('Mermaid Templates Widget Tests', () {
    testWidgets(
      'ทุก template ถูกแปลงเป็นบล็อกไดอะแกรมและแสดง fallback key ได้ถูกต้อง',
      (tester) async {
        for (final template in mermaidTemplates) {
          final markdownData = buildMermaidFencedBlock(template.source);

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: MarkdownBody(
                  data: markdownData,
                  builders: {'code': MermaidElementBuilder()},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(const Key('mermaid-diagram-fallback')),
            findsOneWidget,
            reason:
                'Template id ${template.id} ควร render Mermaid fallback key ได้ 1 ตัว',
          );
        }
      },
    );
  });
}
