import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/workspace/presentation/mermaid/mermaid_status_views.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  group('MermaidDiagramEmptyView', () {
    testWidgets('แสดงข้อความและ Key ถูกต้อง', (tester) async {
      await tester.pumpWidget(_wrap(const MermaidDiagramEmptyView()));

      expect(find.byKey(const Key('mermaid-diagram-empty')), findsOneWidget);
      expect(find.text('ไดอะแกรมว่าง'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('MermaidDiagramFallbackView', () {
    testWidgets('แสดงข้อความ fallback และโค้ดถูกต้อง', (tester) async {
      const source = 'graph TD\n  A-->B';
      await tester.pumpWidget(
        _wrap(const MermaidDiagramFallbackView(source: source)),
      );

      expect(find.byKey(const Key('mermaid-diagram-fallback')), findsOneWidget);
      expect(find.text(source), findsOneWidget);
      expect(
        find.text('แพลตฟอร์มนี้ยังไม่รองรับการแสดงไดอะแกรม'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('MermaidDiagramErrorView', () {
    testWidgets(
      'แสดงหัวข้อ ไอคอน ข้อความ error จำกัด 3 บรรทัด และโค้ด SelectableText',
      (tester) async {
        const source = 'graph TD\n  A-->';
        const errorMessage = 'Syntax error near token -->';

        await tester.pumpWidget(
          _wrap(
            const MermaidDiagramErrorView(
              message: errorMessage,
              source: source,
            ),
          ),
        );

        expect(find.byKey(const Key('mermaid-diagram-error')), findsOneWidget);
        expect(find.text('แสดงไดอะแกรมไม่ได้'), findsOneWidget);
        expect(find.byIcon(Icons.error_outline), findsOneWidget);

        final errorTextFinder = find.text(errorMessage);
        expect(errorTextFinder, findsOneWidget);
        final textWidget = tester.widget<Text>(errorTextFinder);
        expect(textWidget.maxLines, 3);

        expect(find.byType(SelectableText), findsOneWidget);
        expect(find.text(source), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
