import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/sync/data/synced_document_repository.dart';
import 'package:mnote/features/sync/domain/cloud_library_store.dart';
import 'package:mnote/features/sync/domain/sync_settings.dart';
import 'package:mnote/features/workspace/data/local_document_repository.dart';
import 'package:mnote/features/workspace/domain/markdown_document.dart';
import 'package:mnote/models/note_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';

class FakeCloudStore implements CloudLibraryStore {
  final Map<String, CloudDocument> docs = {};
  final Map<String, CloudFolder> folders = {};
  final _controller = StreamController<CloudLibrarySnapshot>.broadcast();
  int docWrites = 0;

  CloudLibrarySnapshot get _snapshot => CloudLibrarySnapshot(
    documents: docs.values.toList(),
    folders: folders.values.toList(),
  );

  @override
  Stream<CloudLibrarySnapshot> watch(String uid) async* {
    yield _snapshot;
    yield* _controller.stream;
  }

  /// Simulates another device writing to the account.
  void remoteWrite({List<CloudDocument> documents = const []}) {
    for (final d in documents) {
      docs[d.id] = d;
    }
    _controller.add(_snapshot);
  }

  @override
  Future<void> upsertDocuments(
    String uid,
    List<CloudDocument> documents,
  ) async {
    docWrites += 1;
    for (final d in documents) {
      docs[d.id] = d;
    }
    // The server confirming the write is echoed back to listeners.
    _controller.add(_snapshot);
  }

  @override
  Future<void> upsertFolders(String uid, List<CloudFolder> items) async {
    for (final f in items) {
      folders[f.id] = f;
    }
  }

  @override
  Future<void> waitForPendingWrites() async {}
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late FakeDocumentStorage storage;
  late FakeCloudStore cloud;
  late String? uid;
  late SyncedDocumentRepository repo;
  late SyncSettings settings;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    settings = SyncSettings();
    storage = FakeDocumentStorage();
    cloud = FakeCloudStore();
    uid = 'user-a';
    repo = SyncedDocumentRepository(
      inner: LocalDocumentRepository(storage),
      store: cloud,
      uidProvider: () => uid,
      settings: settings,
    );
  });

  test('uploads a saved document to the cloud', () async {
    await repo.startSync();
    await settle();

    await repo.save(MarkdownDocument.untitled('hello').rename('a.md'));
    await settle();

    final remote = cloud.docs[CloudDocument.idFor('a.md')];
    expect(remote, isNotNull);
    expect(remote!.content, 'hello');
  });

  test('downloads documents created on another device', () async {
    cloud.docs[CloudDocument.idFor('b.md')] = CloudDocument(
      name: 'b.md',
      content: 'from other device',
      updatedAt: DateTime(2026, 1, 1),
      isStarred: true,
    );
    final changes = expectLater(repo.changes, emits(anything));

    await repo.startSync();
    await changes;

    final metadata = await repo.loadMetadata();
    final doc = metadata!.documents.single;
    expect(doc.name, 'b.md');
    expect(doc.content, 'from other device');
    expect(doc.isStarred, isTrue);
    expect(await repo.readDocument(doc.uri!), 'from other device');
  });

  test('newer remote edit replaces the local copy', () async {
    await repo.startSync();
    await settle();
    await repo.save(MarkdownDocument.untitled('v1').rename('a.md'));
    await settle();

    cloud.remoteWrite(
      documents: [
        CloudDocument(
          name: 'a.md',
          content: 'v2',
          updatedAt: DateTime.now().add(const Duration(minutes: 5)),
        ),
      ],
    );
    await settle();

    final doc = (await repo.loadMetadata())!.documents.single;
    expect(doc.content, 'v2');
    expect(await repo.readDocument(doc.uri!), 'v2');
  });

  test('older remote copy does not overwrite a newer local edit', () async {
    cloud.docs[CloudDocument.idFor('a.md')] = CloudDocument(
      name: 'a.md',
      content: 'old',
      updatedAt: DateTime(2020),
    );
    await repo.startSync();
    await settle();
    await repo.save(MarkdownDocument.untitled('new').rename('a.md'));
    await settle();

    expect(cloud.docs[CloudDocument.idFor('a.md')]!.content, 'new');
  });

  test('delete leaves a tombstone and removes the doc remotely', () async {
    await repo.startSync();
    await settle();
    final saved = await repo.save(
      MarkdownDocument.untitled('x').rename('a.md'),
    );
    await settle();

    await repo.delete(saved!.uri!);
    await settle();

    expect(cloud.docs[CloudDocument.idFor('a.md')]!.deleted, isTrue);
  });

  test('remote tombstone removes the local document', () async {
    await repo.startSync();
    await settle();
    await repo.save(MarkdownDocument.untitled('x').rename('a.md'));
    await settle();

    cloud.remoteWrite(
      documents: [
        CloudDocument.tombstone(
          'a.md',
          DateTime.now().add(const Duration(minutes: 1)),
        ),
      ],
    );
    await settle();

    expect((await repo.loadMetadata())!.documents, isEmpty);
  });

  test('star changes in metadata are pushed', () async {
    await repo.startSync();
    await settle();
    final saved = await repo.save(
      MarkdownDocument.untitled('x').rename('a.md'),
    );
    await settle();

    final metadata = (await repo.loadMetadata())!;
    await repo.saveMetadata(
      LibraryMetadata(
        documents: [metadata.documents.single.copyWith(isStarred: true)],
      ),
    );
    await settle();

    expect(saved, isNotNull);
    expect(cloud.docs[CloudDocument.idFor('a.md')]!.isStarred, isTrue);
  });

  test('folders sync both ways', () async {
    cloud.folders['f1'] = CloudFolder(
      id: 'f1',
      name: 'Work',
      updatedAt: DateTime(2026, 1, 1),
    );
    await repo.startSync();
    await settle();
    expect((await repo.loadMetadata())!.folders.single.name, 'Work');

    final metadata = (await repo.loadMetadata())!;
    await repo.saveMetadata(
      LibraryMetadata(
        folders: [
          ...metadata.folders,
          FolderItem(id: 'f2', name: 'Home', updatedAt: DateTime.now()),
        ],
      ),
    );
    await settle();
    expect(cloud.folders['f2']!.name, 'Home');
  });

  test('untouched bundled welcome document is not uploaded', () async {
    await repo.startSync();
    await settle();
    await repo.saveMetadata(
      LibraryMetadata(
        documents: [
          DocumentItem(
            id: 'welcome_initial_doc',
            name: 'Welcome.md',
            content: 'hi',
            updatedAt: DateTime.now(),
          ),
        ],
      ),
    );
    await settle();

    expect(cloud.docs, isEmpty);
  });

  test(
    'a different account does not inherit the previous local library',
    () async {
      await repo.startSync();
      await settle();
      await repo.save(MarkdownDocument.untitled('secret').rename('a.md'));
      await settle();
      await repo.stopSync();

      uid = 'user-b';
      cloud = FakeCloudStore();
      repo = SyncedDocumentRepository(
        inner: LocalDocumentRepository(storage),
        store: cloud,
        uidProvider: () => uid,
        settings: settings,
      );
      await repo.startSync();
      await settle();

      expect((await repo.loadMetadata())!.documents, isEmpty);
      expect(cloud.docs, isEmpty);
    },
  );

  test('stopSync(clearLocal) empties the local library', () async {
    await repo.startSync();
    await settle();
    await repo.save(MarkdownDocument.untitled('x').rename('a.md'));
    await settle();

    await repo.stopSync(clearLocal: true);

    expect((await repo.loadMetadata())!.documents, isEmpty);
    expect(cloud.docs[CloudDocument.idFor('a.md')]!.deleted, isFalse);
  });

  test('syncedNames lists documents confirmed in the cloud', () async {
    await repo.startSync();
    await settle();
    expect(repo.syncedNames.value, isEmpty);

    await repo.save(MarkdownDocument.untitled('x').rename('a.md'));
    await settle();
    expect(repo.syncedNames.value, {'a.md'});

    final saved = (await repo.loadMetadata())!.documents.single;
    await repo.saveMetadata(
      LibraryMetadata(documents: [saved.copyWith(isStarred: true)]),
    );
    // Local star change is acknowledged once the cloud echoes it back.
    await settle();
    expect(repo.syncedNames.value, {'a.md'});
  });

  test('renaming a document tombstones the old name', () async {
    await repo.startSync();
    await settle();
    await repo.save(MarkdownDocument.untitled('x').rename('a.md'));
    await settle();

    final item = (await repo.loadMetadata())!.documents.single;
    await repo.saveMetadata(
      LibraryMetadata(
        documents: [item.copyWith(name: 'b.md', updatedAt: DateTime.now())],
      ),
    );
    await settle();

    expect(cloud.docs[CloudDocument.idFor('a.md')]!.deleted, isTrue);
    expect(cloud.docs[CloudDocument.idFor('b.md')]!.deleted, isFalse);
    // The old name must not come back as a second local file.
    final names = (await repo.loadMetadata())!.documents.map((d) => d.name);
    expect(names, ['b.md']);
  });

  test('stopSync uploads the last edit before clearing local data', () async {
    await repo.startSync();
    await settle();
    await repo.save(MarkdownDocument.untitled('last edit').rename('a.md'));

    await repo.stopSync(clearLocal: true);

    expect(cloud.docs[CloudDocument.idFor('a.md')]!.content, 'last edit');
    expect((await repo.loadMetadata())!.documents, isEmpty);
  });

  test('does nothing without a signed-in user', () async {
    uid = null;
    await repo.startSync();
    await repo.save(MarkdownDocument.untitled('x').rename('a.md'));
    await settle();

    expect(cloud.docWrites, 0);
  });

  group('sync settings', () {
    Future<void> saveNote(String name, String content) =>
        repo.save(MarkdownDocument.untitled(content).rename(name));

    test('nothing syncs while the master switch is off', () async {
      settings.enabled = false;
      await repo.startSync();
      await saveNote('a.md', 'x');
      await settle();

      expect(cloud.docs, isEmpty);
    });

    test('turning sync on uploads what was written while it was off', () async {
      settings.enabled = false;
      await repo.startSync();
      await saveNote('a.md', 'x');
      await settle();

      settings.enabled = true;
      await settle();

      expect(cloud.docs.containsKey(CloudDocument.idFor('a.md')), isTrue);
    });

    test('turning sync off stops uploads and downloads', () async {
      await repo.startSync();
      await settle();
      settings.enabled = false;
      await settle();

      await saveNote('a.md', 'x');
      cloud.remoteWrite(
        documents: [
          CloudDocument(name: 'b.md', content: 'y', updatedAt: DateTime.now()),
        ],
      );
      await settle();

      expect(cloud.docs.containsKey(CloudDocument.idFor('a.md')), isFalse);
      expect((await repo.loadMetadata())!.documents.map((d) => d.name), [
        'a.md',
      ]);
    });

    test('documents above the size limit are not uploaded', () async {
      settings.maxContentBytes = 10;
      await repo.startSync();
      await settle();
      await saveNote('big.md', 'x' * 50);
      await saveNote('small.md', 'tiny');
      await settle();

      expect(cloud.docs.containsKey(CloudDocument.idFor('big.md')), isFalse);
      expect(cloud.docs.containsKey(CloudDocument.idFor('small.md')), isTrue);
    });

    test('raising the limit uploads documents that were held back', () async {
      settings.maxContentBytes = 10;
      await repo.startSync();
      await settle();
      await saveNote('big.md', 'x' * 50);
      await settle();

      settings.maxContentBytes = 1000;
      await settle();

      expect(cloud.docs.containsKey(CloudDocument.idFor('big.md')), isTrue);
    });

    test('the size limit counts UTF-8 bytes, not characters', () async {
      // 4 Thai characters are 12 bytes.
      settings.maxContentBytes = 10;
      await repo.startSync();
      await settle();
      await saveNote('thai.md', 'สวัสดี'.substring(0, 4));
      await settle();

      expect(cloud.docs.containsKey(CloudDocument.idFor('thai.md')), isFalse);
    });

    test('SyncMode.always ignores the limit', () async {
      settings.maxContentBytes = 10;
      await repo.startSync();
      await settle();
      await saveNote('big.md', 'x' * 50);
      await settle();
      expect(cloud.docs.containsKey(CloudDocument.idFor('big.md')), isFalse);

      final item = (await repo.loadMetadata())!.documents.single;
      await repo.saveMetadata(
        LibraryMetadata(documents: [item.copyWith(syncMode: SyncMode.always)]),
      );
      await settle();

      expect(cloud.docs.containsKey(CloudDocument.idFor('big.md')), isTrue);
    });

    test('SyncMode.never stops uploading later edits', () async {
      await repo.startSync();
      await settle();
      await saveNote('a.md', 'v1');
      await settle();

      final item = (await repo.loadMetadata())!.documents.single;
      await repo.saveMetadata(
        LibraryMetadata(
          documents: [
            item.copyWith(
              syncMode: SyncMode.never,
              content: 'v2 edited',
              updatedAt: DateTime.now().add(const Duration(minutes: 1)),
            ),
          ],
        ),
      );
      await settle();

      expect(cloud.docs[CloudDocument.idFor('a.md')]!.content, 'v1');
    });

    test('a never document ignores cloud edits and deletions', () async {
      await repo.startSync();
      await settle();
      await saveNote('a.md', 'mine');
      await settle();
      final item = (await repo.loadMetadata())!.documents.single;
      await repo.saveMetadata(
        LibraryMetadata(documents: [item.copyWith(syncMode: SyncMode.never)]),
      );
      await settle();

      cloud.remoteWrite(
        documents: [
          CloudDocument(
            name: 'a.md',
            content: 'from other device',
            updatedAt: DateTime.now().add(const Duration(minutes: 5)),
          ),
        ],
      );
      await settle();

      expect((await repo.loadMetadata())!.documents.single.content, 'mine');
    });

    test('sync mode survives a metadata round trip', () async {
      final metadata = LibraryMetadata(
        documents: [
          DocumentItem(
            id: 'a',
            name: 'a.md',
            content: '',
            updatedAt: DateTime(2026),
            syncMode: SyncMode.never,
          ),
        ],
      );
      final decoded = LibraryMetadata.fromJson(metadata.toJson());
      expect(decoded.documents.single.syncMode, SyncMode.never);
    });

    test('unsyncedCount counts documents the settings exclude', () async {
      await repo.startSync();
      await settle();
      await saveNote('a.md', 'x');
      await saveNote('b.md', 'y' * 50);
      await settle();
      expect(await repo.unsyncedCount(), 0);

      settings.maxContentBytes = 10;
      expect(await repo.unsyncedCount(), 1);

      settings.enabled = false;
      expect(await repo.unsyncedCount(), 2);
    });

    test('ink follows the document mode and ink switch', () async {
      await repo.startSync();
      await settle();
      await saveNote('a.md', 'x');
      await settle();

      expect(await repo.allowsInk('a.md', 100), isTrue);
      settings.syncInk = false;
      expect(await repo.allowsInk('a.md', 100), isFalse);
      settings.syncInk = true;

      final item = (await repo.loadMetadata())!.documents.single;
      await repo.saveMetadata(
        LibraryMetadata(documents: [item.copyWith(syncMode: SyncMode.never)]),
      );
      expect(await repo.allowsInk('a.md', 100), isFalse);
    });
  });
}
