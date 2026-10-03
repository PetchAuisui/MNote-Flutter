import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/app/mnote_app.dart';
import 'package:mnote/features/workspace/domain/document_repository.dart';
import 'package:mnote/features/workspace/presentation/markdown_workspace_page.dart';
import 'package:mnote/features/workspace/presentation/obsidian_markdown_controller.dart';

import '../../../helpers/fakes.dart';

Widget _buildApp({DocumentRepository? repository}) {
  final repo = repository ?? FakeDocumentRepository();
  return MnoteApp(
    documentRepository: repo,
    home: MarkdownWorkspacePage(repository: repo),
  );
}

void main() {
  group('ObsidianMarkdownEditingController tests', () {
    late ObsidianMarkdownEditingController controller;

    setUp(() {
      controller = ObsidianMarkdownEditingController();
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('styles H1 heading with bold, larger font, and muted hash', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              controller.text = '# Heading 1';
              final span = controller.buildTextSpan(
                context: context,
                style: const TextStyle(fontSize: 15),
                withComposing: false,
              );
              expect(span.children, isNotEmpty);
              final hashSpan = span.children![0] as TextSpan;
              expect(hashSpan.text, '# ');

              final textSpan = span.children![1] as TextSpan;
              expect(textSpan.text, 'Heading 1');
              expect(textSpan.style?.fontWeight, FontWeight.bold);
              expect(textSpan.style?.fontSize, greaterThan(15));
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('styles bold, italic, inline code, and strikethrough', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              controller.text =
                  'This is **bold**, *italic*, `code`, and ~~deleted~~';
              final span = controller.buildTextSpan(
                context: context,
                style: const TextStyle(fontSize: 15),
                withComposing: false,
              );
              final allTexts = span.children!.map((s) => (s as TextSpan).text).toList();
              expect(allTexts, contains('bold'));
              expect(allTexts, contains('italic'));
              expect(allTexts, contains('code'));
              expect(allTexts, contains('deleted'));

              // Find bold span
              final boldSpan = span.children!.firstWhere(
                (s) => (s as TextSpan).text == 'bold',
              ) as TextSpan;
              expect(boldSpan.style?.fontWeight, FontWeight.bold);

              // Find inline code span
              final codeSpan = span.children!.firstWhere(
                (s) => (s as TextSpan).text == 'code',
              ) as TextSpan;
              expect(codeSpan.style?.fontFamily, 'monospace');

              // Find strikethrough span
              final strikeSpan = span.children!.firstWhere(
                (s) => (s as TextSpan).text == 'deleted',
              ) as TextSpan;
              expect(strikeSpan.style?.decoration, TextDecoration.lineThrough);

              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('styles code blocks with monospace font and background', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              controller.text = '```dart\nfinal x = 42;\n```';
              final span = controller.buildTextSpan(
                context: context,
                style: const TextStyle(fontSize: 15),
                withComposing: false,
              );
              expect(span.children!.length, 3);
              final codeContentSpan = span.children![1] as TextSpan;
              expect(codeContentSpan.style?.fontFamily, 'monospace');
              expect(codeContentSpan.style?.backgroundColor, isNotNull);
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('styles links with underline and primary link color', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              controller.text = 'Check [Flutter](https://flutter.dev) now';
              final span = controller.buildTextSpan(
                context: context,
                style: const TextStyle(fontSize: 15),
                withComposing: false,
              );
              final linkSpan = span.children!.firstWhere(
                (s) => (s as TextSpan).text == 'Flutter',
              ) as TextSpan;
              expect(linkSpan.style?.decoration, TextDecoration.underline);
              return const SizedBox();
            },
          ),
        ),
      );
    });
  });

  group('Obsidian Split View (รวม Preview & Code)', () {
    testWidgets(
      'switching to รวมจอ displays both markdown-editor and markdown-preview side-by-side',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        // Initially in edit mode
        expect(find.byKey(const Key('markdown-editor')), findsOneWidget);
        expect(find.byKey(const Key('markdown-preview')), findsNothing);

        // Tap 'รวมจอ'
        await tester.tap(find.text('รวมจอ'));
        await tester.pumpAndSettle();

        // Both editor and preview must be visible at the same time!
        expect(find.byKey(const Key('markdown-editor')), findsOneWidget);
        expect(find.byKey(const Key('markdown-preview')), findsOneWidget);
        expect(find.textContaining('รวมจอ (Obsidian Split)'), findsOneWidget);

        // Typing in editor updates preview in real time
        await tester.enterText(
          find.byKey(const Key('markdown-editor')),
          '# Live Obsidian Update\n\nInstant preview synchronized!',
        );
        await tester.pumpAndSettle();

        expect(find.text('Live Obsidian Update', findRichText: true), findsOneWidget);
        expect(find.textContaining('Instant preview synchronized!'), findsWidgets);
      },
    );

    testWidgets(
      'รวมจอ renders vertically on compact screen',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        // On compact screen, mode buttons don't have text labels, find by tooltip
        await tester.tap(find.byTooltip('รวม Preview กับ Code (Obsidian Split)'));
        await tester.pumpAndSettle();

        // Both are present in vertical split
        expect(find.byKey(const Key('markdown-editor')), findsOneWidget);
        expect(find.byKey(const Key('markdown-preview')), findsOneWidget);
      },
    );
  });
}
