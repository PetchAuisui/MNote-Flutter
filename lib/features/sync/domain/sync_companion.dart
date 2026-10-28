/// Extra data that syncs together with the document library (e.g. pen ink).
abstract interface class SyncCompanion {
  Future<void> start();

  Future<void> stop();

  /// Re-evaluates what to upload after the sync settings changed.
  Future<void> refresh();

  /// The notes changed locally or from the cloud.
  Future<void> libraryChanged();

  /// Removes the local copy of the synced data.
  Future<void> clearLocal();
}
