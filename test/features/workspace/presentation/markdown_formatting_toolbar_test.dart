import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/workspace/presentation/markdown_formatting_toolbar.dart';

void main() {
  testWidgets('heading labels and separate list buttons apply their actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var heading = 0;
    var bullets = 0;
    var numbers = 0;
    var strikes = 0;
    void noop() {}
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarkdownFormattingToolbar(
            onUndo: noop,
            onRedo: noop,
            onHeading: (value) => heading = value,
            onBold: noop,
            onItalic: noop,
            onStrikethrough: () => strikes++,
            onList: () => bullets++,
            onOrderedList: () => numbers++,
            onIndentList: noop,
            onOutdentList: noop,
            onQuote: noop,
            onLineBreak: noop,
            onHorizontalRule: noop,
            onInlineCode: noop,
            onCodeBlock: noop,
            onLink: noop,
            onImage: noop,
            onTable: noop,
          ),
        ),
      ),
    );
    expect(find.text('หัวข้อ 1'), findsOneWidget);
    for (var level = 2; level <= 4; level++) {
      await tester.tap(find.byKey(const Key('toolbar-heading')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('หัวข้อ $level').last);
      await tester.pumpAndSettle();
      expect(heading, level);
      expect(find.text('หัวข้อ $level'), findsOneWidget);
    }
    await tester.tap(find.byKey(const Key('toolbar-strikethrough')));
    expect(strikes, 1);
    await tester.tap(find.byKey(const Key('toolbar-list')));
    expect(bullets, 1);
    expect(numbers, 0);
    await tester.tap(find.byKey(const Key('toolbar-ordered-list')));
    expect(numbers, 1);
    expect(bullets, 1);
  });
}
