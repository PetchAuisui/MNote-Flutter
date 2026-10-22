import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:mnote/features/sync/domain/sync_settings.dart';
import 'package:mnote/features/sync/domain/syncable_document_repository.dart';

import 'fakes.dart';

/// A document repository that claims to sync, for UI tests.
class FakeSyncableRepository extends FakeDocumentRepository
    implements SyncableDocumentRepository {
  FakeSyncableRepository({SyncSettings? settings})
    : settings = settings ?? SyncSettings();

  final synced = ValueNotifier<Set<String>>({});
  int unsynced = 0;

  @override
  final SyncSettings settings;

  @override
  ValueListenable<Set<String>> get syncedNames => synced;

  @override
  Stream<void> get changes => const Stream.empty();

  @override
  Future<void> startSync() async {}

  @override
  Future<void> stopSync({bool clearLocal = false}) async {}

  @override
  Future<int> unsyncedCount() async => unsynced;
}
