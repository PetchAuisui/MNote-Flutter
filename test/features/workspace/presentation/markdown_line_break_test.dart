import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/workspace/presentation/markdown_rendered_block.dart';

void main() {
  for (final tag in ['<br>', '<br/>', '<br />', '<BR>']) {
    testWidgets('$tag renders as a line break and preserves literal code', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => MarkdownRenderedBlock(
                markdown: 'First${tag}Second and `$tag`',
                theme: Theme.of(context),
              ),
            ),
          ),
        ),
      );
      final text = tester
          .widgetList<RichText>(find.byType(RichText))
          .map((widget) => widget.text.toPlainText())
          .join();
      expect(text, contains('First\nSecond'));
      expect(text, contains(tag));
    });
  }
}
