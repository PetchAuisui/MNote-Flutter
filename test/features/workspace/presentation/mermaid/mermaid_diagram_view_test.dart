import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/workspace/presentation/mermaid/mermaid_diagram_view.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  group('MermaidDiagramView', () {
    testWidgets('source ว่าง ต้องแสดงสถานะไดอะแกรมว่าง', (tester) async {
      await tester.pumpWidget(_wrap(const MermaidDiagramView(source: '')));

      expect(find.byKey(const Key('mermaid-diagram-empty')), findsOneWidget);
      expect(find.text('ไดอะแกรมว่าง'), findsOneWidget);
      expect(find.byKey(const Key('mermaid-diagram-webview')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('source มีแต่ช่องว่าง ต้องแสดงสถานะไดอะแกรมว่าง', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const MermaidDiagramView(source: '  \n  ')),
      );

      expect(find.byKey(const Key('mermaid-diagram-empty')), findsOneWidget);
      expect(find.text('ไดอะแกรมว่าง'), findsOneWidget);
      expect(find.byKey(const Key('mermaid-diagram-webview')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'บังคับไม่รองรับ (webViewSupported: false) ต้องแสดงสถานะ fallback',
      (tester) async {
        const source = 'graph TD\n  A-->B';
        await tester.pumpWidget(
          _wrap(
            const MermaidDiagramView(source: source, webViewSupported: false),
          ),
        );

        expect(
          find.byKey(const Key('mermaid-diagram-fallback')),
          findsOneWidget,
        );
        expect(find.text(source), findsOneWidget);
        expect(
          find.text('แพลตฟอร์มนี้ยังไม่รองรับการแสดงไดอะแกรม'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'เลือก fallback เองเมื่อไม่มี WebView (กัน test อื่นในโปรเจกต์พัง)',
      (tester) async {
        const source = 'graph TD\n  A-->B';
        await tester.pumpWidget(
          _wrap(const MermaidDiagramView(source: source)),
        );

        expect(
          find.byKey(const Key('mermaid-diagram-fallback')),
          findsOneWidget,
        );
        expect(find.text(source), findsOneWidget);
        expect(
          find.text('แพลตฟอร์มนี้ยังไม่รองรับการแสดงไดอะแกรม'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'เปลี่ยนจากว่างเป็นมีเนื้อหา ต้องสลับจากสถานะว่างเป็น fallback ได้ถูกต้อง',
      (tester) async {
        await tester.pumpWidget(_wrap(const MermaidDiagramView(source: '')));
        expect(find.byKey(const Key('mermaid-diagram-empty')), findsOneWidget);

        const source = 'graph TD\n  A-->B';
        await tester.pumpWidget(
          _wrap(const MermaidDiagramView(source: source)),
        );

        expect(find.byKey(const Key('mermaid-diagram-empty')), findsNothing);
        expect(
          find.byKey(const Key('mermaid-diagram-fallback')),
          findsOneWidget,
        );
        expect(find.text(source), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('เปลี่ยนจากมีเนื้อหากลับเป็นว่าง ต้องสลับกลับมาเป็นสถานะว่าง', (
      tester,
    ) async {
      const source = 'graph TD\n  A-->B';
      await tester.pumpWidget(_wrap(const MermaidDiagramView(source: source)));
      expect(find.byKey(const Key('mermaid-diagram-fallback')), findsOneWidget);

      await tester.pumpWidget(_wrap(const MermaidDiagramView(source: '')));

      expect(find.byKey(const Key('mermaid-diagram-fallback')), findsNothing);
      expect(find.byKey(const Key('mermaid-diagram-empty')), findsOneWidget);
      expect(find.text('ไดอะแกรมว่าง'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'ข้อความโค้ดใน fallback ต้องเป็น SelectableText ที่เลือกคัดลอกได้',
      (tester) async {
        const source = 'graph TD\n  A-->B';
        await tester.pumpWidget(
          _wrap(
            const MermaidDiagramView(source: source, webViewSupported: false),
          ),
        );

        expect(find.byType(SelectableText), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
