import 'package:flutter/foundation.dart';
import 'package:mnote/features/workspace/domain/document_repository.dart';

/// A [DocumentRepository] that mirrors the library to the signed-in account.
abstract interface class SyncableDocumentRepository
    implements DocumentRepository {
  /// Fires after remote changes were merged into local storage.
  Stream<void> get changes;

  /// Names of documents whose current content is confirmed in the cloud.
  ValueListenable<Set<String>> get syncedNames;

  /// Starts syncing for the current user. Safe to call repeatedly.
  Future<void> startSync();

  /// Stops syncing. With [clearLocal], the local copy is removed once all
  /// pending changes reached the cloud, so the next account starts clean.
  Future<void> stopSync({bool clearLocal = false});
}
