/// Extra data that syncs together with the document library (e.g. pen ink).
abstract interface class SyncCompanion {
  Future<void> start();

  Future<void> stop();

  /// Removes the local copy of the synced data.
  Future<void> clearLocal();
}
