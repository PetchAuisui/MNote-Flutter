import 'package:flutter/foundation.dart';
import 'package:mnote/features/sync/domain/sync_settings.dart';
import 'package:mnote/features/workspace/domain/document_repository.dart';

/// A [DocumentRepository] that mirrors the library to the signed-in account.
abstract interface class SyncableDocumentRepository
    implements DocumentRepository {
  /// Fires after remote changes were merged into local storage.
  Stream<void> get changes;

  /// The user's sync choices. Changing them starts, stops or re-evaluates sync.
  SyncSettings get settings;

  /// How many local documents are not (and will not be) uploaded under the
  /// current settings. Signing out removes them from this device.
  Future<int> unsyncedCount();

  /// Names of documents whose current content is confirmed in the cloud.
  ValueListenable<Set<String>> get syncedNames;

  /// When everything was last confirmed in the cloud, or null if that has not
  /// happened since the app started.
  ValueListenable<DateTime?> get lastSyncedAt;

  /// Uploads pending changes now and waits for the cloud to confirm them.
  /// Returns false when sync is off or the cloud could not be reached.
  Future<bool> syncNow();

  /// Starts syncing for the current user. Safe to call repeatedly.
  Future<void> startSync();

  /// Stops syncing. With [clearLocal], the local copy is removed once all
  /// pending changes reached the cloud, so the next account starts clean.
  Future<void> stopSync({bool clearLocal = false});
}
