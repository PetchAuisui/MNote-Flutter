import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/workspace/data/device_image_picker.dart';
import 'package:mnote/features/workspace/data/ink_file_storage.dart';
import 'package:mnote/features/workspace/presentation/ink_page.dart';
import 'package:mnote/features/workspace/presentation/ink_picture.dart';
import 'package:mnote/features/workspace/presentation/ink_session.dart';
import 'package:mnote/l10n/app_localizations.dart';
import 'package:scribble/scribble.dart';

class _Picker extends DeviceImagePicker {
  const _Picker();

  @override
  Future<MarkdownImageReference?> pick({Uri? documentDirectory}) async =>
      MarkdownImageReference(
        alt: 'cat',
        uri: Uri(pathSegments: ['images', 'cat-0001.png']),
      );
}

class _Storage implements InkFileStorage {
  @override
  Future<bool> autoSave({
    required String name,
    required Uint8List bytes,
  }) async => true;

  @override
  Future<Uint8List?> autoLoad({required String name}) async => null;

  @override
  Future<void> deleteAll() async {}

  @override
  Future<List<String>> listNames() async => const [];

  @override
  Future<Uint8List?> open() async => null;

  @override
  Future<bool> save({required String name, required Uint8List bytes}) async =>
      true;
}

Widget _page(InkSession session) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: InkPage(
      session: session,
      markdown: '# Notes',
      name: 'notes.md',
      fileStorage: _Storage(),
      imagePicker: const _Picker(),
    ),
  ),
);

void main() {
  test('pictures are kept on the page and survive saving', () {
    final session = InkSession();
    addTearDown(session.dispose);
    expect(session.isDirty, isFalse);
    final picture = session.addPicture(
      'images/cat.png',
      size: const Size(2000, 1000),
      center: const Offset(500, 300),
    );
    // Wide pictures start at half the page width, keeping their shape.
    expect(picture.rect.width, InkSession.pageWidth / 2);
    expect(picture.rect.height, InkSession.pageWidth / 4);
    expect(session.selectedPicture, picture.id);
    expect(session.hasContent, isTrue);
    expect(session.hasInk, isFalse);
    expect(session.isDirty, isTrue);

    session.placePicture(picture.id, const Rect.fromLTWH(-50, -50, 100, 80));
    expect(session.pictures.single.rect, const Rect.fromLTWH(0, 0, 100, 80));
    session.placePicture(
      picture.id,
      const Rect.fromLTWH(InkSession.pageWidth - 10, 0, 100, 80),
    );
    expect(session.pictures.single.rect.right, InkSession.pageWidth);

    final snapshot = session.encode();
    session.markSaved(snapshot);
    expect(session.isDirty, isFalse);
    expect(InkPicture.sourcesIn(jsonDecode(snapshot)), {'images/cat.png'});

    final reloaded = InkSession()..load(snapshot);
    addTearDown(reloaded.dispose);
    expect(reloaded.pictures.single.rect, session.pictures.single.rect);
    expect(reloaded.pictures.single.src, 'images/cat.png');
    expect(reloaded.isDirty, isFalse);

    session.removePicture(picture.id);
    expect(session.pictures, isEmpty);
    expect(session.selectedPicture, isNull);
    expect(session.isDirty, isTrue);
  });

  test('ink files with unsafe pictures are refused', () {
    final session = InkSession();
    addTearDown(session.dispose);
    final data = jsonDecode(session.encode()) as Map<String, dynamic>;
    data['pictures'] = [
      {'id': 'a', 'src': '../secret.png', 'x': 0, 'y': 0, 'w': 10, 'h': 10},
    ];
    expect(() => session.load(jsonEncode(data)), throwsFormatException);
    data['pictures'] = [
      {'id': 'a', 'src': 'images/a.png', 'x': -5, 'y': 0, 'w': 10, 'h': 10},
    ];
    expect(() => session.load(jsonEncode(data)), throwsFormatException);
    expect(InkPicture.sourcesIn({'pictures': 'nope'}), isEmpty);
  });

  testWidgets('picture tool adds, moves, resizes and deletes pictures', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1180, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = InkSession();
    addTearDown(session.dispose);
    await tester.pumpWidget(_page(session));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ink-picture-tool')));
    await tester.pumpAndSettle();
    expect(session.movingPictures, isTrue);
    expect(find.byKey(const Key('ink-color-preset-0')), findsNothing);
    expect(
      tester
          .widget<IgnorePointer>(
            find
                .ancestor(
                  of: find.byType(Scribble),
                  matching: find.byType(IgnorePointer),
                )
                .first,
          )
          .ignoring,
      isTrue,
    );

    await tester.tap(find.byKey(const Key('ink-add-picture')));
    // Looking up the picture's size reads the disk, which needs real time.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    final picture = session.pictures.single;
    expect(picture.src, 'images/cat-0001.png');
    expect(session.selectedPicture, picture.id);

    final drag = find.byKey(Key('ink-picture-drag-${picture.id}'));
    final before = session.pictures.single.rect;
    await tester.drag(drag, const Offset(60, 40));
    await tester.pumpAndSettle();
    final moved = session.pictures.single.rect;
    expect(moved.left, greaterThan(before.left));
    expect(moved.top, greaterThan(before.top));
    expect(moved.size, before.size);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('ink-picture-resize'))),
    );
    for (var i = 0; i < 4; i++) {
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();
    final resized = session.pictures.single.rect;
    expect(resized.width, greaterThan(moved.width));
    expect(
      resized.width / resized.height,
      closeTo(before.width / before.height, 0.01),
    );

    await tester.tap(find.byKey(const Key('ink-picture-delete')));
    await tester.pumpAndSettle();
    expect(session.pictures, isEmpty);

    await tester.tap(find.byKey(const Key('ink-pen')));
    await tester.pumpAndSettle();
    expect(session.movingPictures, isFalse);
    expect(tester.takeException(), isNull);
  });
}
