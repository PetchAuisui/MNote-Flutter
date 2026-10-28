import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/sync/data/synced_image_files.dart';
import 'package:mnote/features/sync/domain/cloud_image_store.dart';
import 'package:mnote/features/sync/domain/image_sync_guard.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeImageCloud implements CloudImageStore {
  final Map<String, Uint8List> files = {};
  int requests = 0;
  bool failing = false;

  void _hit() {
    requests++;
    if (failing) throw const FileSystemException('offline');
  }

  @override
  Future<int?> sizeOf(String uid, String name) async {
    _hit();
    return files[name]?.length;
  }

  @override
  Future<void> upload(
    String uid,
    String name,
    Uint8List bytes,
    String contentType,
  ) async {
    _hit();
    files[name] = bytes;
  }

  @override
  Future<Uint8List?> download(String uid, String name, int maxBytes) async {
    _hit();
    return files[name];
  }
}

void main() {
  late Directory dir;
  late FakeImageCloud cloud;
  var clock = DateTime(2026, 10, 28, 12);

  SyncedImageFiles build({
    ImageSyncLimits limits = const ImageSyncLimits(),
    List<String> notes = const ['![a](images/a.jpg)'],
  }) {
    final files = SyncedImageFiles(
      store: cloud,
      uidProvider: () => 'u1',
      directory: () async => dir,
      guard: ImageSyncGuard(limits: limits, now: () => clock),
    )..notes = () async => notes;
    return files;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    cloud = FakeImageCloud();
    clock = DateTime(2026, 10, 28, 12);
    dir = await Directory.systemTemp.createTemp('mnote_images');
    await Directory('${dir.path}/images').create();
  });

  tearDown(() => dir.delete(recursive: true));

  test('finds pictures referenced with encoded names and parentheses', () {
    final names = SyncedImageFiles.referencedIn([
      '![x](images/IMG_0111%20(2).jpeg)\n![y](images/b.png) ![z](https://e.com/c.png)',
      '![bad](images/../secret.png) ![bad2](images/a/b.png) ![t](images/n.txt)',
    ]);
    expect(names, {'images/IMG_0111 (2).jpeg', 'images/b.png'});
  });

  test('uploads a referenced picture once', () async {
    File('${dir.path}/images/a.jpg').writeAsBytesSync([1, 2, 3]);
    final sync = build();
    await sync.start();
    await sync.libraryChanged();

    expect(cloud.files['a.jpg'], [1, 2, 3]);
    final requests = cloud.requests;
    await sync.libraryChanged();
    expect(cloud.requests, requests);
  });

  test('downloads a picture another device uploaded', () async {
    cloud.files['a.jpg'] = Uint8List.fromList([9, 9]);
    final sync = build();
    await sync.start();

    expect(File('${dir.path}/images/a.jpg').readAsBytesSync(), [9, 9]);
  });

  test('does not ask again right away for a picture the cloud lacks', () async {
    final sync = build();
    await sync.start();
    final requests = cloud.requests;
    await sync.libraryChanged();
    expect(cloud.requests, requests);

    clock = clock.add(const Duration(minutes: 11));
    await sync.libraryChanged();
    expect(cloud.requests, greaterThan(requests));
  });

  test('refuses a picture over the size ceiling', () async {
    File('${dir.path}/images/a.jpg').writeAsBytesSync(List.filled(300, 1));
    final sync = build(limits: const ImageSyncLimits(maxFileBytes: 100));
    await sync.start();
    expect(cloud.files, isEmpty);
  });

  test('never reads or uploads a file past the source ceiling', () async {
    File('${dir.path}/images/a.jpg').writeAsBytesSync(List.filled(500, 1));
    final sync = build(
      limits: const ImageSyncLimits(maxFileBytes: 100, maxSourceBytes: 200),
    );
    await sync.start();
    await sync.libraryChanged();
    expect(cloud.files, isEmpty);
    expect(cloud.requests, 1, reason: 'only the existence check, once');
  });

  test('size checks use the configured ceilings', () {
    final guard = ImageSyncGuard(
      limits: const ImageSyncLimits(maxFileBytes: 100, maxSourceBytes: 200),
    );
    expect(guard.isTooLarge(100), isFalse);
    expect(guard.isTooLarge(101), isTrue);
    expect(guard.isUnreadable(200), isFalse);
    expect(guard.isUnreadable(201), isTrue);
  });

  test('stops uploading at the daily byte ceiling', () async {
    for (final n in ['a', 'b', 'c']) {
      File('${dir.path}/images/$n.jpg').writeAsBytesSync(List.filled(40, 1));
    }
    final sync = build(
      limits: const ImageSyncLimits(maxDailyUploadBytes: 100),
      notes: ['![a](images/a.jpg) ![b](images/b.jpg) ![c](images/c.jpg)'],
    );
    await sync.start();
    expect(cloud.files.length, 2);

    clock = clock.add(const Duration(days: 1));
    await sync.libraryChanged();
    expect(cloud.files.length, 3);
  });

  test('stops at the total storage ceiling', () async {
    for (final n in ['a', 'b']) {
      File('${dir.path}/images/$n.jpg').writeAsBytesSync(List.filled(40, 1));
    }
    final sync = build(
      limits: const ImageSyncLimits(maxTotalBytes: 60),
      notes: ['![a](images/a.jpg) ![b](images/b.jpg)'],
    );
    await sync.start();
    expect(cloud.files.length, 1);
  });

  test('stops at the daily request ceiling', () async {
    final sync = build(
      limits: const ImageSyncLimits(maxDailyOperations: 2),
      notes: ['![a](images/a.jpg) ![b](images/b.jpg) ![c](images/c.jpg)'],
    );
    await sync.start();
    expect(cloud.requests, lessThanOrEqualTo(2));
  });

  test('pauses after repeated failures', () async {
    File('${dir.path}/images/a.jpg').writeAsBytesSync([1]);
    cloud.failing = true;
    final sync = build(
      limits: const ImageSyncLimits(failuresBeforePause: 2),
    );
    await sync.start();
    await sync.libraryChanged();
    final requests = cloud.requests;

    cloud.failing = false;
    await sync.libraryChanged();
    expect(cloud.requests, requests, reason: 'paused, so no request is made');

    clock = clock.add(const Duration(hours: 7));
    await sync.libraryChanged();
    expect(cloud.files['a.jpg'], [1]);
  });

  test('does nothing while signed out', () async {
    File('${dir.path}/images/a.jpg').writeAsBytesSync([1]);
    final sync = SyncedImageFiles(
      store: cloud,
      uidProvider: () => null,
      directory: () async => dir,
      guard: ImageSyncGuard(),
    )..notes = () async => ['![a](images/a.jpg)'];
    await sync.start();
    expect(cloud.requests, 0);
  });

  test('spent budget survives a restart and corrupt state fails closed', () async {
    SharedPreferences.setMockInitialValues({ImageSyncGuard.stateKey: '{'});
    final guard = ImageSyncGuard(now: () => clock);
    expect(await guard.reserveOperation(), isFalse);
  });
}
