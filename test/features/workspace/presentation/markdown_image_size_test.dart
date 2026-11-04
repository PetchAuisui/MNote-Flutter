import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mnote/l10n/l10n.dart';
import 'package:mnote/features/workspace/presentation/export_sheet.dart';
import 'package:mnote/features/workspace/presentation/markdown_image_size.dart';
import 'package:mnote/features/workspace/presentation/markdown_live_editor.dart';
import 'package:mnote/features/workspace/presentation/markdown_rendered_block.dart';

/// A 1×1 PNG, so pictures need no file lookup.
const _png =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

void main() {
  _keepsScrollWhenOpened();
  group('alt text size', () {
    test('splits the size off the label', () {
      expect(splitImageAlt('cat'), ('cat', null));
      expect(splitImageAlt('cat|300'), ('cat', const MarkdownImageSize(300)));
      expect(splitImageAlt('my cat | 300x200'), (
        'my cat',
        const MarkdownImageSize(300, 200),
      ));
      expect(splitImageAlt(r'cat\|300'), ('cat', const MarkdownImageSize(300)));
      expect(splitImageAlt('|120'), ('', const MarkdownImageSize(120)));
      // Not a size: left as plain alt text.
      expect(splitImageAlt('a|b'), ('a|b', null));
      expect(splitImageAlt('cat|0'), ('cat|0', null));
      expect(splitImageAlt('cat|300x0'), ('cat|300x0', null));
    });

    test('joins a size back after the label', () {
      expect(joinImageAlt('cat', null), 'cat');
      expect(joinImageAlt('cat', const MarkdownImageSize(300)), 'cat|300');
      expect(
        joinImageAlt('cat', const MarkdownImageSize(300, 200)),
        'cat|300x200',
      );
    });

    test('rewrites a lone picture block and nothing else', () {
      final link = MarkdownImageLink.parse(
        '![cat|300](images/cat(1).png "Cat")\n\n',
      )!;
      expect(link.alt, 'cat');
      expect(link.size, const MarkdownImageSize(300));
      expect(link.src, 'images/cat(1).png');
      expect(
        link.withSize(const MarkdownImageSize(120, 80)),
        '![cat|120x80](images/cat(1).png "Cat")\n\n',
      );
      expect(link.withSize(null), '![cat](images/cat(1).png "Cat")\n\n');
      expect(MarkdownImageLink.parse('See ![cat](a.png)'), isNull);
      expect(MarkdownImageLink.parse('![a](a.png) ![b](b.png)'), isNull);
    });

    test('plain text export drops the size', () {
      expect(stripMarkdown('![cat|300x200](a.png)'), 'cat');
    });
  });

  group('rendering', () {
    Future<void> pumpBlock(
      WidgetTester tester,
      String markdown, {
      double width = 600,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: Builder(
                  builder: (context) => MarkdownRenderedBlock(
                    markdown: markdown,
                    theme: Theme.of(context),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('uses the width and height from the alt text', (tester) async {
      await pumpBlock(tester, '![cat|120x80]($_png)');
      final image = tester.widget<MarkdownImage>(find.byType(MarkdownImage));
      expect(image.alt, 'cat');
      expect(tester.getSize(find.byType(MarkdownImage)), const Size(120, 80));
      expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.fill);
    });

    testWidgets('a width alone keeps the proportions', (tester) async {
      await pumpBlock(tester, '![cat|150]($_png)');
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.width, 150);
      expect(image.height, isNull);
      expect(find.byType(AspectRatio), findsNothing);
    });

    testWidgets('shrinks to a narrower column, keeping its shape', (
      tester,
    ) async {
      await pumpBlock(tester, '![cat|600x400]($_png)', width: 300);
      expect(tester.getSize(find.byType(MarkdownImage)), const Size(300, 200));
    });

    testWidgets('a picture without a size is drawn as before', (tester) async {
      await pumpBlock(tester, '![cat]($_png)');
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.width, isNull);
      expect(image.height, isNull);
      expect(image.fit, isNull);
      expect(find.byType(AspectRatio), findsNothing);
      expect(
        tester.widget<MarkdownImage>(find.byType(MarkdownImage)).alt,
        'cat',
      );
    });

    testWidgets('still honours the older #WIDTHxHEIGHT suffix', (tester) async {
      await pumpBlock(tester, '![cat]($_png#90x60)');
      expect(tester.getSize(find.byType(MarkdownImage)), const Size(90, 60));
    });
  });

  group('resizing in the live editor', () {
    Future<TextEditingController> pumpEditor(
      WidgetTester tester,
      String markdown,
    ) async {
      final controller = TextEditingController(text: markdown);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: MarkdownLiveEditor(controller: controller, onChanged: (_) {}),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('markdown-block-0')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('markdown-image-resize-handle')),
        findsOneWidget,
      );
      return controller;
    }

    Finder handle() => find.byKey(const Key('markdown-image-resize-handle'));

    testWidgets('dragging the corner sets width and height', (tester) async {
      final controller = await pumpEditor(tester, '![cat|120x80]($_png)');
      await tester.drag(handle(), const Offset(40, 20));
      await tester.pumpAndSettle();
      expect(controller.text, '![cat|160x100]($_png)');
      expect(tester.getSize(find.byType(MarkdownImage)), const Size(160, 100));
    });

    testWidgets('with the ratio locked dragging sets the width only', (
      tester,
    ) async {
      final controller = await pumpEditor(tester, '![cat|120]($_png)');
      await tester.drag(handle(), const Offset(30, 50));
      await tester.pumpAndSettle();
      expect(controller.text, '![cat|150]($_png)');
    });

    testWidgets('lock toggles between a width and a width and height', (
      tester,
    ) async {
      final controller = await pumpEditor(tester, '![cat|120x80]($_png)');
      final lock = find.byKey(const Key('markdown-image-lock-ratio'));
      await tester.tap(lock);
      await tester.pumpAndSettle();
      expect(controller.text, '![cat|120]($_png)');
    });

    testWidgets('reset returns the picture to its own size', (tester) async {
      final controller = await pumpEditor(tester, '![cat|120x80]($_png)');
      await tester.tap(find.byKey(const Key('markdown-image-reset-size')));
      await tester.pumpAndSettle();
      expect(controller.text, '![cat]($_png)');
      expect(find.text('Original size'), findsOneWidget);
    });

    testWidgets('the size dialog sets width and height', (tester) async {
      final controller = await pumpEditor(tester, '![cat|120x80]($_png)');
      await tester.tap(find.byKey(const Key('markdown-image-size')));
      await tester.pumpAndSettle();
      expect(find.text('Picture size'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('markdown-image-size-width')),
        '240',
      );
      await tester.enterText(
        find.byKey(const Key('markdown-image-size-height')),
        '100',
      );
      await tester.tap(find.byKey(const Key('markdown-image-size-apply')));
      await tester.pumpAndSettle();
      expect(controller.text, '![cat|240x100]($_png)');
      // The block stays open for more changes.
      expect(handle(), findsOneWidget);
    });

    testWidgets('the size dialog keeps the proportions when locked', (
      tester,
    ) async {
      final controller = await pumpEditor(tester, '![cat|120x80]($_png)');
      await tester.tap(find.byKey(const Key('markdown-image-size')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('markdown-image-size-lock')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('markdown-image-size-width')),
        '300',
      );
      await tester.pump();
      final height = tester.widget<TextField>(
        find.byKey(const Key('markdown-image-size-height')),
      );
      expect(height.controller!.text, '200');
      await tester.tap(find.byKey(const Key('markdown-image-size-apply')));
      await tester.pumpAndSettle();
      expect(controller.text, '![cat|300]($_png)');
    });

    testWidgets('the size dialog can reset or be cancelled', (tester) async {
      final controller = await pumpEditor(tester, '![cat|120x80]($_png)');
      await tester.tap(find.byKey(const Key('markdown-image-size')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(controller.text, '![cat|120x80]($_png)');
      await tester.tap(find.byKey(const Key('markdown-image-size')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('markdown-image-size-reset')));
      await tester.pumpAndSettle();
      expect(controller.text, '![cat]($_png)');
    });

    testWidgets('switches to the Markdown and back', (tester) async {
      final controller = await pumpEditor(tester, '![cat|120]($_png)');
      await tester.tap(find.byKey(const Key('markdown-image-edit-markdown')));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.byKey(const Key('markdown-live-block-editor')),
      );
      expect(field.controller!.text, controller.text);
      await tester.tap(find.byKey(const Key('markdown-image-edit-picture')));
      await tester.pumpAndSettle();
      expect(handle(), findsOneWidget);
    });

    testWidgets('typing a picture link keeps the text field', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MarkdownLiveEditor(controller: controller, onChanged: (_) {}),
          ),
        ),
      );
      final field = find.byKey(const Key('markdown-live-block-editor'));
      await tester.enterText(field, '![cat]($_png)');
      await tester.pumpAndSettle();
      expect(field, findsOneWidget);
      expect(handle(), findsNothing);
    });
  });
}

void _keepsScrollWhenOpened() {
  testWidgets('opening a tall picture keeps the page where it is', (
    tester,
  ) async {
    final directory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('mnote-image'),
    ))!;
    addTearDown(() => directory.deleteSync(recursive: true));
    await tester.runAsync(() async {
      final picture = img.Image(width: 400, height: 1200);
      await File(
        '${directory.path}/tall.png',
      ).writeAsBytes(img.encodePng(picture));
    });
    final before = List.filled(30, 'Paragraph').join('\n\n');
    final controller = TextEditingController(
      text: '$before\n\n![tall](tall.png)\n\nAfter',
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: MarkdownLiveEditor(
            controller: controller,
            onChanged: (_) {},
            imageDirectory: directory.uri.toString(),
          ),
        ),
      ),
    );
    // Let the picture be found and decoded.
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    final picture = find.byType(MarkdownImage);
    expect(tester.getSize(picture).height, greaterThan(500));
    await tester.scrollUntilVisible(picture, 300);
    await tester.drag(
      find.byKey(const Key('markdown-live-preview')),
      const Offset(0, -400),
    );
    await tester.pump();
    final scroll = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    final offset = scroll.pixels;
    await tester.tapAt(tester.getCenter(picture));
    await tester.pump();
    expect(
      find.byKey(const Key('markdown-image-resize-handle')),
      findsOneWidget,
    );
    expect(scroll.pixels, closeTo(offset, 1));
    expect(tester.getSize(picture).height, greaterThan(500));
  });
}
