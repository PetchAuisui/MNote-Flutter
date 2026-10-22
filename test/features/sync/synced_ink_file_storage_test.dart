import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/sync/data/synced_ink_file_storage.dart';
import 'package:mnote/features/sync/domain/cloud_ink_store.dart';
import 'package:mnote/features/workspace/data/ink_file_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemoryInkStorage implements InkFileStorage {
  final Map<String, Uint8List> files = {};

  @override
  Future<bool> autoSave({
    required String name,
    required Uint8List bytes,
  }) async {
    files[name] = bytes;
    return true;
  }

  @override
  Future<Uint8List?> autoLoad({required String name}) async => files[name];

  @override
  Future<List<String>> listNames() async => files.keys.toList();

  @override
  Future<void> deleteAll() async => files.clear();

  @override
  Future<Uint8List?> open() async => null;

  @override
  Future<bool> save({required String name, required Uint8List bytes}) async =>
      true;
}

class FakeInkCloud implements CloudInkStore {
  final Map<String, CloudInk> inks = {};
  final _controller = StreamController<List<CloudInk>>.broadcast();

  @override
  Stream<List<CloudInk>> watch(String uid) async* {
    yield inks.values.toList();
    yield* _controller.stream;
  }

  @override
  Future<void> upsert(String uid, CloudInk ink) async {
    inks[ink.name] = ink;
    _controller.add(inks.values.toList());
  }

  void remoteWrite(String name, String content) {
    final bytes = Uint8List.fromList(utf8.encode(content));
    inks[name] = CloudInk(
      name: name,
      hash: SyncedInkFileStorage.hashOf(bytes),
      data: Uint8List.fromList(gzip.encode(bytes)),
      updatedAt: DateTime.now(),
    );
    _controller.add(inks.values.toList());
  }
}

Uint8List bytes(String s) => Uint8List.fromList(utf8.encode(s));

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late MemoryInkStorage local;
  late FakeInkCloud cloud;
  late SyncedInkFileStorage ink;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    local = MemoryInkStorage();
    cloud = FakeInkCloud();
    ink = SyncedInkFileStorage(
      inner: local,
      store: cloud,
      uidProvider: () => 'u1',
    );
  });

  test('uploads ink when it is auto-saved', () async {
    await ink.start();
    await settle();

    await ink.autoSave(name: 'a.md', bytes: bytes('strokes'));
    await settle();

    final remote = cloud.inks['a.md']!;
    expect(utf8.decode(gzip.decode(remote.data)), 'strokes');
  });

  test('uploads ink that existed before sync', () async {
    local.files['old.md'] = bytes('legacy');
    await ink.start();
    await settle();

    expect(cloud.inks.containsKey('old.md'), isTrue);
  });

  test('downloads ink drawn on another device', () async {
    cloud.remoteWrite('a.md', 'from other device');
    await ink.start();
    await settle();

    expect(
      utf8.decode((await ink.autoLoad(name: 'a.md'))!),
      'from other device',
    );
  });

  test('newer remote ink replaces unchanged local ink', () async {
    await ink.start();
    await settle();
    await ink.autoSave(name: 'a.md', bytes: bytes('v1'));
    await settle();

    cloud.remoteWrite('a.md', 'v2');
    await settle();

    expect(utf8.decode((await ink.autoLoad(name: 'a.md'))!), 'v2');
  });

  test('local edits made offline win over remote and are uploaded', () async {
    cloud.remoteWrite('a.md', 'v1');
    await ink.start();
    await settle();
    await ink.stop();

    await local.autoSave(name: 'a.md', bytes: bytes('local edit'));
    cloud.remoteWrite('a.md', 'remote edit');
    await ink.start();
    await settle();

    expect(utf8.decode((await ink.autoLoad(name: 'a.md'))!), 'local edit');
    expect(utf8.decode(gzip.decode(cloud.inks['a.md']!.data)), 'local edit');
  });

  test('clearLocal removes local ink but keeps the cloud copy', () async {
    await ink.start();
    await settle();
    await ink.autoSave(name: 'a.md', bytes: bytes('x'));
    await settle();

    await ink.clearLocal();

    expect(local.files, isEmpty);
    expect(cloud.inks.containsKey('a.md'), isTrue);
  });
}
