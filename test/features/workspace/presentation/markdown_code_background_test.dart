import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/workspace/presentation/markdown_rendered_block.dart';

/// Background colors of every text span whose text contains [needle].
Future<List<Color?>> _backgrounds(
  WidgetTester tester,
  String markdown,
  String needle,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => MarkdownRenderedBlock(
            markdown: markdown,
            theme: Theme.of(context),
          ),
        ),
      ),
    ),
  );
  final colors = <Color?>[];
  for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
    rich.text.visitChildren((span) {
      if (span is TextSpan && (span.text ?? '').contains(needle)) {
        colors.add(
          span.style?.background == null ? span.style?.backgroundColor : null,
        );
      }
      return true;
    });
  }
  return colors;
}

void main() {
  testWidgets('fenced code block text has no per-line background', (
    tester,
  ) async {
    final colors = await _backgrounds(
      tester,
      "```dart\nvoid main() {\n  print('hi');\n}\n```",
      'void main',
    );
    expect(colors, isNotEmpty);
    for (final color in colors) {
      expect(color == null || color.a == 0, isTrue);
    }
  });

  testWidgets('inline code keeps its background', (tester) async {
    final colors = await _backgrounds(tester, 'text `inline` text', 'inline');
    expect(colors, isNotEmpty);
    expect(colors.any((c) => c != null && c.a > 0), isTrue);
  });
}
