import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/app/mnote_app.dart';

import 'helpers/fakes.dart';

void main() {
  testWidgets('shows the empty Markdown workspace', (tester) async {
    await tester.pumpWidget(
      MnoteApp(documentRepository: FakeDocumentRepository()),
    );

    expect(find.text('Untitled.md'), findsOneWidget);
    expect(find.text('แก้ไข'), findsOneWidget);
    expect(find.text('แสดงผล'), findsOneWidget);
    expect(find.text('Read Markdown. Write freely.'), findsOneWidget);
    expect(find.byKey(const Key('markdown-editor')), findsOneWidget);
    expect(find.byKey(const Key('line-number-gutter')), findsOneWidget);
    expect(_lineNumberLabel('เลขบรรทัด 1'), findsOneWidget);
  });

  testWidgets('updates line numbers while editing Markdown', (tester) async {
    await tester.pumpWidget(
      MnoteApp(documentRepository: FakeDocumentRepository()),
    );

    await tester.enterText(
      find.byKey(const Key('markdown-editor')),
      '# Title\n\nParagraph',
    );
    await tester.pump();

    expect(_lineNumberLabel('เลขบรรทัด 1 ถึง 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('edits Markdown and renders a preview', (tester) async {
    await tester.pumpWidget(
      MnoteApp(documentRepository: FakeDocumentRepository()),
    );

    await tester.enterText(
      find.byKey(const Key('markdown-editor')),
      '# Hello Mnote',
    );
    await tester.tap(find.text('แสดงผล'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('markdown-preview')), findsOneWidget);
    expect(find.text('Hello Mnote'), findsOneWidget);
    expect(find.text('ยังไม่ได้บันทึก'), findsOneWidget);
  });

  testWidgets('fits the editor on a compact phone screen', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MnoteApp(documentRepository: FakeDocumentRepository()),
    );

    expect(find.byKey(const Key('markdown-editor')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Finder _lineNumberLabel(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.properties.label == label,
  );
}
