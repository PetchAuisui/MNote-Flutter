import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mnote/features/sync/domain/cloud_library_store.dart';
import 'package:mnote/features/sync/domain/network_monitor.dart';
import 'package:mnote/features/sync/domain/sync_companion.dart';
import 'package:mnote/features/sync/domain/sync_settings.dart';
import 'package:mnote/features/sync/domain/syncable_document_repository.dart';
import 'package:mnote/features/workspace/domain/document_repository.dart';
import 'package:mnote/features/workspace/domain/markdown_document.dart';
import 'package:mnote/models/note_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wraps a local [DocumentRepository] and mirrors it to the signed-in
/// account's cloud library (last write wins, per document).
///
/// Local storage stays the source the UI reads from, so the app keeps working
/// offline. Remote changes are merged into it and announced on [changes].
class SyncedDocumentRepository implements SyncableDocumentRepository {
  SyncedDocumentRepository({
    required this._inner,
    required this._store,
    required this._uidProvider,
    required this.settings,
    this.companions = const [],
    this.network,
  }) {
    settings.addListener(_onSettingsChanged);
    // The repository lives as long as the app, so this is never cancelled.
    network?.changes.listen((_) => _onSettingsChanged());
  }

  static const ownerPrefKey = 'mnote_sync_owner_uid';
  static const _welcomeId = 'welcome_initial_doc';

  final DocumentRepository _inner;
  final CloudLibraryStore _store;
  final String? Function() _uidProvider;

  @override
  final SyncSettings settings;

  /// Started and stopped together with the library (e.g. pen ink).
  final List<SyncCompanion> companions;

  /// Used to hold sync back on mobile data when the user asked for Wi-Fi only.
  final NetworkMonitor? network;

  bool get _shouldRun =>
      settings.enabled && !(settings.wifiOnly && (network?.isMetered ?? false));

  final _changes = StreamController<void>.broadcast();
  StreamSubscription<CloudLibrarySnapshot>? _subscription;
  String? _uid;
  bool _ready = false;
  Future<void> _queue = Future.value();

  final Map<String, CloudDocument> _remoteDocs = {};
  final Map<String, CloudFolder> _remoteFolders = {};
  final Set<String> _knownFolderIds = {};
  final Map<String, DateTime> _pendingDeletes = {};

  final _syncedNames = ValueNotifier<Set<String>>(const {});
  final _lastSyncedAt = ValueNotifier<DateTime?>(null);
  // Signatures the server has confirmed, by document name.
  Map<String, String> _confirmed = const {};

  @override
  ValueListenable<Set<String>> get syncedNames => _syncedNames;

  @override
  ValueListenable<DateTime?> get lastSyncedAt => _lastSyncedAt;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<void> startSync() async {
    final uid = _uidProvider();
    if (!_shouldRun) return;
    if (uid == null || (uid == _uid && _subscription != null)) return;

    await _subscription?.cancel();
    _uid = uid;
    _ready = false;
    _remoteDocs.clear();
    _remoteFolders.clear();
    _knownFolderIds.clear();
    _confirmed = const {};
    _syncedNames.value = const {};

    await _enqueue(() => _claimLocalLibrary(uid));
    if (_uid != uid) return;

    for (final companion in companions) {
      await companion.start();
    }
    _subscription = _store
        .watch(uid)
        .listen(
          (snapshot) => _enqueue(() => _onRemote(snapshot)),
          onError: (Object e) => debugPrint('Cloud sync listen failed: $e'),
        );
  }

  @override
  Future<void> stopSync({bool clearLocal = false}) async {
    // Edits saved just before sign-out may still be waiting in the queue;
    // upload them first so clearing the local copy cannot lose them.
    if (_uid != null && _ready) {
      await _enqueue(() async => _push(await _inner.loadMetadata()));
    }
    await _subscription?.cancel();
    _subscription = null;
    _uid = null;
    _ready = false;
    _confirmed = const {};
    _syncedNames.value = const {};
    for (final companion in companions) {
      await companion.stop();
    }
    if (!clearLocal) return;

    try {
      await _store.waitForPendingWrites().timeout(const Duration(seconds: 8));
    } catch (_) {
      // Unsynced changes must not be lost; the next login clears the library
      // if a different account signs in.
      return;
    }
    await _enqueue(_clearLocalLibrary);
  }

  // Start/stop transitions run one after another, so flipping the switch
  // quickly cannot leave sync off while the setting says on.
  Future<void> _lifecycle = Future.value();

  void _onSettingsChanged() {
    _lifecycle = _lifecycle
        .then<void>((_) async {
          final running = _subscription != null;
          if (!_shouldRun && running) {
            await stopSync();
          } else if (_shouldRun && !running) {
            await startSync();
          } else if (running) {
            _pushSoon();
            for (final companion in companions) {
              unawaited(companion.refresh());
            }
          }
        })
        .catchError((Object e) {
          debugPrint('Sync settings change failed: $e');
        });
  }

  @override
  Future<bool> syncNow() async {
    if (_uid == null || !_ready) return false;
    _pushSoon();
    for (final companion in companions) {
      unawaited(companion.refresh());
    }
    try {
      await _queue;
      await _store.waitForPendingWrites().timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('Sync now failed: $e');
      return false;
    }
    _lastSyncedAt.value = DateTime.now();
    return true;
  }

  @override
  Future<int> unsyncedCount() async {
    final metadata = await _inner.loadMetadata();
    return metadata?.documents
            .where((d) => !_isUntouchedWelcome(d) && !settings.allows(d))
            .length ??
        0;
  }

  /// Policy for ink, which follows the document with the same name.
  Future<bool> allowsInk(String name, int bytes) async {
    if (!settings.enabled || !settings.syncInk) return false;
    final metadata = await _inner.loadMetadata();
    final doc = metadata == null ? null : _findByName(metadata.documents, name);
    return settings.allowsInk(doc?.syncMode ?? SyncMode.auto, bytes);
  }

  // ---------------------------------------------------------------------
  // DocumentRepository: delegate, then mirror.

  @override
  Future<MarkdownDocument?> open() async {
    final doc = await _inner.open();
    if (doc != null) _pushSoon();
    return doc;
  }

  @override
  Future<MarkdownDocument?> save(MarkdownDocument document) async {
    final saved = await _inner.save(document);
    if (saved != null) _pushSoon();
    return saved;
  }

  @override
  Future<MarkdownDocument?> saveAs(MarkdownDocument document) async {
    final saved = await _inner.saveAs(document);
    if (saved != null) _pushSoon();
    return saved;
  }

  @override
  Future<List<MarkdownDocument>> listDocuments() => _inner.listDocuments();

  @override
  Future<String?> readDocument(Uri uri) => _inner.readDocument(uri);

  @override
  Future<void> delete(Uri uri) async {
    final metadata = await _inner.loadMetadata();
    final item = metadata?.documents
        .where((d) => d.uri?.toString() == uri.toString())
        .firstOrNull;
    await _inner.delete(uri);
    // A document excluded from sync never touches the cloud, deletion included.
    if (item != null && item.syncMode != SyncMode.never) {
      _pendingDeletes[item.name] = DateTime.now();
      _pushSoon();
    }
  }

  @override
  Future<LibraryMetadata?> loadMetadata() => _inner.loadMetadata();

  @override
  Future<void> saveMetadata(LibraryMetadata metadata) async {
    final before = await _inner.loadMetadata();
    await _inner.saveMetadata(metadata);
    _forgetRenamedNames(before, metadata);
    _enqueue(() async {
      await _push(metadata);
      _refreshSynced(metadata);
    });
  }

  // ---------------------------------------------------------------------
  // Internals

  Future<void> _enqueue(Future<void> Function() task) {
    final result = _queue.then((_) => task());
    _queue = result.catchError((Object e) {
      debugPrint('Cloud sync task failed: $e');
    });
    return _queue;
  }

  void _pushSoon() {
    _enqueue(() async {
      final metadata = await _inner.loadMetadata();
      await _push(metadata);
      _refreshSynced(metadata);
    });
  }

  /// Documents are keyed by name in the cloud, so a rename leaves the old
  /// name behind; without a tombstone it would be recreated on every device.
  void _forgetRenamedNames(LibraryMetadata? before, LibraryMetadata after) {
    if (before == null) return;
    final oldNames = {for (final d in before.documents) d.id: d.name};
    final currentNames = {for (final d in after.documents) d.name};
    for (final d in after.documents) {
      final old = oldNames[d.id];
      if (old == null || old == d.name || currentNames.contains(old)) continue;
      if (d.syncMode == SyncMode.never) continue;
      final remote = _remoteDocs[CloudDocument.idFor(old)];
      if (remote != null && !remote.deleted) {
        _pendingDeletes[old] = DateTime.now();
      }
    }
  }

  void _refreshSynced(LibraryMetadata? metadata) {
    if (metadata == null) return;
    final names = {
      for (final d in metadata.documents)
        if (_confirmed[d.name] == CloudDocument.fromItem(d).signature) d.name,
    };
    if (!setEquals(names, _syncedNames.value)) _syncedNames.value = names;
  }

  /// Local data from before sync existed is adopted by the first account to
  /// sign in. Data left by a different account is wiped instead of leaking.
  Future<void> _claimLocalLibrary(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final owner = prefs.getString(ownerPrefKey);
      if (owner != null && owner != uid) {
        await _clearLocalLibrary();
        _changes.add(null);
      }
      await prefs.setString(ownerPrefKey, uid);
    } catch (e) {
      debugPrint('Cloud sync owner check failed: $e');
    }
  }

  Future<void> _clearLocalLibrary() async {
    final metadata = await _inner.loadMetadata();
    for (final doc in metadata?.documents ?? const <DocumentItem>[]) {
      final uri = doc.uri;
      if (uri != null) await _inner.delete(uri);
    }
    await _inner.saveMetadata(const LibraryMetadata());
    for (final companion in companions) {
      await companion.clearLocal();
    }
    _pendingDeletes.clear();
    _changes.add(null);
  }

  Future<void> _onRemote(CloudLibrarySnapshot snapshot) async {
    if (_uid == null) return;
    _remoteDocs
      ..clear()
      ..addEntries(snapshot.documents.map((d) => MapEntry(d.id, d)));
    _remoteFolders
      ..clear()
      ..addEntries(snapshot.folders.map((f) => MapEntry(f.id, f)));

    if (!snapshot.hasPendingWrites) {
      _confirmed = {
        for (final d in snapshot.documents.where((d) => !d.deleted))
          d.name: d.signature,
      };
    }

    final changed = await _merge(snapshot);
    _ready = true;
    final metadata = await _inner.loadMetadata();
    await _push(metadata);
    _refreshSynced(metadata);
    if (!snapshot.hasPendingWrites) _lastSyncedAt.value = DateTime.now();
    if (changed) _changes.add(null);
  }

  bool _isUntouchedWelcome(DocumentItem d) =>
      d.id == _welcomeId && d.uri == null;

  DocumentItem? _findByName(List<DocumentItem> items, String name) {
    for (final d in items) {
      if (d.name == name && !_isUntouchedWelcome(d)) return d;
    }
    return null;
  }

  /// Applies remote documents/folders that are newer than the local copy.
  Future<bool> _merge(CloudLibrarySnapshot snapshot) async {
    var changed = false;
    final before = await _inner.loadMetadata() ?? const LibraryMetadata();
    final removedNames = <String>{};
    final patches = <String, CloudDocument>{};

    // File I/O goes through the inner repository so metadata stays valid.
    for (final remote in snapshot.documents) {
      final local = _findByName(before.documents, remote.name);
      // A document the user excluded from sync is left exactly as it is.
      if (local != null && local.syncMode == SyncMode.never) continue;
      if (remote.deleted) {
        if (local != null && remote.updatedAt.isAfter(local.updatedAt)) {
          final uri = local.uri;
          if (uri != null) await _inner.delete(uri);
          removedNames.add(remote.name);
          changed = true;
        }
        continue;
      }

      if (local == null) {
        await _tryWriteFile(remote, null);
        patches[remote.name] = remote;
        changed = true;
        continue;
      }

      final isNewer = remote.updatedAt.isAfter(local.updatedAt);
      final differs =
          remote.signature != CloudDocument.fromItem(local).signature;
      if (isNewer && differs) {
        if (local.uri?.scheme == 'file' && remote.content != local.content) {
          await _tryWriteFile(remote, local.uri);
        }
        patches[remote.name] = remote;
        changed = true;
      }
    }

    // The inner repository rewrote metadata while touching files; start from
    // its latest state and apply the remote values on top.
    final current = await _inner.loadMetadata() ?? const LibraryMetadata();
    final documents = <DocumentItem>[];
    for (final item in current.documents) {
      if (removedNames.contains(item.name)) continue;
      final patch = patches[item.name];
      final shadowsWelcome = patch != null && _isUntouchedWelcome(item);
      if (shadowsWelcome) continue;
      documents.add(patch == null ? item : _applyRemote(item, patch));
    }
    for (final entry in patches.entries) {
      if (!documents.any(
        (d) => d.name == entry.key && !_isUntouchedWelcome(d),
      )) {
        // File creation failed or the item has no local file yet: keep the
        // content in the library so it still shows up and can be saved later.
        documents.add(
          DocumentItem(
            id: 'cloud_${CloudDocument.idFor(entry.key)}',
            name: entry.key,
            content: entry.value.content,
            updatedAt: entry.value.updatedAt,
            folderId: entry.value.folderId,
            isStarred: entry.value.isStarred,
            isTrash: entry.value.isTrash,
          ),
        );
      }
    }

    final folders = List<FolderItem>.from(current.folders);
    for (final remote in snapshot.folders) {
      final index = folders.indexWhere((f) => f.id == remote.id);
      if (remote.deleted) {
        if (index != -1 && remote.updatedAt.isAfter(folders[index].updatedAt)) {
          folders.removeAt(index);
          changed = true;
        }
        continue;
      }
      final item = FolderItem(
        id: remote.id,
        name: remote.name,
        updatedAt: remote.updatedAt,
        isStarred: remote.isStarred,
        isTrash: remote.isTrash,
        colorValue: remote.colorValue,
      );
      if (index == -1) {
        folders.add(item);
        changed = true;
      } else if (remote.updatedAt.isAfter(folders[index].updatedAt) &&
          remote.signature != CloudFolder.fromItem(folders[index]).signature) {
        folders[index] = item;
        changed = true;
      }
    }

    _knownFolderIds
      ..clear()
      ..addAll(folders.map((f) => f.id));

    if (changed) {
      await _inner.saveMetadata(
        LibraryMetadata(folders: folders, documents: documents),
      );
    }
    return changed;
  }

  DocumentItem _applyRemote(DocumentItem item, CloudDocument remote) {
    return DocumentItem(
      id: item.id,
      name: item.name,
      content: remote.content,
      updatedAt: remote.updatedAt,
      folderId: remote.folderId,
      isStarred: remote.isStarred,
      isTrash: remote.isTrash,
      uri: item.uri,
      syncMode: item.syncMode,
    );
  }

  Future<Uri?> _tryWriteFile(CloudDocument remote, Uri? uri) async {
    try {
      final saved = await _inner.save(
        MarkdownDocument(
          name: remote.name,
          content: remote.content,
          savedName: remote.name,
          savedContent: '',
          uri: uri,
        ),
      );
      return saved?.uri;
    } catch (e) {
      debugPrint('Cloud sync could not write ${remote.name}: $e');
      return null;
    }
  }

  /// Uploads local changes (and deletions) the cloud does not have yet.
  Future<void> _push(LibraryMetadata? metadata) async {
    final uid = _uid;
    if (!_ready || uid == null || metadata == null) return;

    final now = DateTime.now();
    final documents = <CloudDocument>[];

    for (final entry in _pendingDeletes.entries) {
      documents.add(CloudDocument.tombstone(entry.key, entry.value));
    }
    for (final item in metadata.documents) {
      if (_isUntouchedWelcome(item) || _pendingDeletes.containsKey(item.name)) {
        continue;
      }
      if (!settings.allows(item)) continue;

      final candidate = CloudDocument.fromItem(item);
      final remote = _remoteDocs[candidate.id];
      if (remote != null) {
        if (remote.deleted) {
          if (!item.updatedAt.isAfter(remote.updatedAt)) continue;
        } else if (remote.signature == candidate.signature ||
            remote.updatedAt.isAfter(item.updatedAt)) {
          continue;
        }
      }
      // Star/move changes do not touch updatedAt; bump it so they win.
      final stamp = remote != null && !item.updatedAt.isAfter(remote.updatedAt)
          ? now
          : item.updatedAt;
      documents.add(
        CloudDocument(
          name: candidate.name,
          content: candidate.content,
          updatedAt: stamp,
          folderId: candidate.folderId,
          isStarred: candidate.isStarred,
          isTrash: candidate.isTrash,
        ),
      );
    }

    final folders = <CloudFolder>[];
    final localFolderIds = <String>{};
    for (final item in metadata.folders) {
      localFolderIds.add(item.id);
      final candidate = CloudFolder.fromItem(item);
      final remote = _remoteFolders[item.id];
      if (remote != null) {
        if (remote.deleted) {
          if (!item.updatedAt.isAfter(remote.updatedAt)) continue;
        } else if (remote.signature == candidate.signature ||
            remote.updatedAt.isAfter(item.updatedAt)) {
          continue;
        }
      }
      final stamp = remote != null && !item.updatedAt.isAfter(remote.updatedAt)
          ? now
          : item.updatedAt;
      folders.add(
        CloudFolder(
          id: candidate.id,
          name: candidate.name,
          updatedAt: stamp,
          isStarred: candidate.isStarred,
          isTrash: candidate.isTrash,
          colorValue: candidate.colorValue,
        ),
      );
    }
    for (final id in _knownFolderIds.difference(localFolderIds)) {
      final remote = _remoteFolders[id];
      if (remote == null || remote.deleted) continue;
      folders.add(
        CloudFolder(id: id, name: remote.name, updatedAt: now, deleted: true),
      );
    }
    _knownFolderIds
      ..clear()
      ..addAll(localFolderIds);

    // Writes only complete once online, so never await them inside the queue.
    if (documents.isNotEmpty) {
      for (final d in documents) {
        _remoteDocs[d.id] = d;
        _pendingDeletes.remove(d.name);
      }
      unawaited(
        _store
            .upsertDocuments(uid, documents)
            .catchError(
              (Object e) => debugPrint('Cloud sync upload failed: $e'),
            ),
      );
    }
    if (folders.isNotEmpty) {
      for (final f in folders) {
        _remoteFolders[f.id] = f;
      }
      unawaited(
        _store
            .upsertFolders(uid, folders)
            .catchError(
              (Object e) => debugPrint('Cloud sync upload failed: $e'),
            ),
      );
    }
  }
}
