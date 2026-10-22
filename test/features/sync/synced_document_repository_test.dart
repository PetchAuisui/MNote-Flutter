import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/sync/data/synced_document_repository.dart';
import 'package:mnote/features/sync/domain/cloud_library_store.dart';
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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storage = FakeDocumentStorage();
    cloud = FakeCloudStore();
    uid = 'user-a';
    repo = SyncedDocumentRepository(
      inner: LocalDocumentRepository(storage),
      store: cloud,
      uidProvider: () => uid,
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

  test('does nothing without a signed-in user', () async {
    uid = null;
    await repo.startSync();
    await repo.save(MarkdownDocument.untitled('x').rename('a.md'));
    await settle();

    expect(cloud.docWrites, 0);
  });
}
