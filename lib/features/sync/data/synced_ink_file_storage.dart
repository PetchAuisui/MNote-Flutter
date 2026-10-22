import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mnote/features/sync/domain/cloud_ink_store.dart';
import 'package:mnote/features/sync/domain/sync_companion.dart';
import 'package:mnote/features/workspace/data/ink_file_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wraps local ink storage and mirrors each document's ink to the account.
///
/// Ink is one sketch per document, so conflicts are resolved per document:
/// a remote copy replaces the local one only if the local one has not changed
/// since the last sync; otherwise the local copy is uploaded.
class SyncedInkFileStorage implements InkFileStorage, SyncCompanion {
  SyncedInkFileStorage({
    required this.inner,
    required this.store,
    required this.uidProvider,
  });

  static const stateKey = 'mnote_ink_sync_state';
  // Firestore documents are limited to 1 MiB.
  static const _maxBytes = 900 * 1024;

  final InkFileStorage inner;
  final CloudInkStore store;
  final String? Function() uidProvider;

  StreamSubscription<List<CloudInk>>? _subscription;
  String? _uid;
  bool _ready = false;
  Future<void> _queue = Future.value();
  final Map<String, String> _remoteHashes = {};

  @override
  Future<void> start() async {
    final uid = uidProvider();
    if (uid == null || (uid == _uid && _subscription != null)) return;
    await _subscription?.cancel();
    _uid = uid;
    _ready = false;
    _remoteHashes.clear();
    _subscription = store
        .watch(uid)
        .listen(
          (remote) => _enqueue(() => _onRemote(remote)),
          onError: (Object e) => debugPrint('Ink sync listen failed: $e'),
        );
  }

  @override
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _uid = null;
    _ready = false;
  }

  @override
  Future<void> clearLocal() async {
    await _enqueue(() async {
      await inner.deleteAll();
      await _saveState({});
    });
  }

  @override
  Future<bool> save({required String name, required Uint8List bytes}) =>
      inner.save(name: name, bytes: bytes);

  @override
  Future<Uint8List?> open() => inner.open();

  @override
  Future<Uint8List?> autoLoad({required String name}) =>
      inner.autoLoad(name: name);

  @override
  Future<List<String>> listNames() => inner.listNames();

  @override
  Future<void> deleteAll() => inner.deleteAll();

  @override
  Future<bool> autoSave({
    required String name,
    required Uint8List bytes,
  }) async {
    final saved = await inner.autoSave(name: name, bytes: bytes);
    if (saved) _enqueue(() => _push(name, bytes));
    return saved;
  }

  Future<void> _enqueue(Future<void> Function() task) {
    final result = _queue.then((_) => task());
    _queue = result.catchError((Object e) {
      debugPrint('Ink sync task failed: $e');
    });
    return _queue;
  }

  Future<void> _onRemote(List<CloudInk> remote) async {
    if (_uid == null) return;
    _remoteHashes
      ..clear()
      ..addEntries(remote.map((r) => MapEntry(r.name, r.hash)));

    final state = await _loadState();
    final pulled = <String>{};
    for (final ink in remote) {
      final local = await inner.autoLoad(name: ink.name);
      final localHash = local == null ? null : _hash(local);
      if (localHash == ink.hash) {
        state[ink.name] = ink.hash;
        continue;
      }
      // Missing locally, or untouched since the last sync: take the remote.
      if (local == null || state[ink.name] == localHash) {
        try {
          final bytes = Uint8List.fromList(gzip.decode(ink.data));
          if (await inner.autoSave(name: ink.name, bytes: bytes)) {
            state[ink.name] = ink.hash;
            pulled.add(ink.name);
          }
        } catch (e) {
          debugPrint('Ink sync could not apply ${ink.name}: $e');
        }
      }
    }
    await _saveState(state);
    _ready = true;

    // Local ink the cloud lacks or has an older copy of.
    for (final name in await inner.listNames()) {
      if (pulled.contains(name)) continue;
      final bytes = await inner.autoLoad(name: name);
      if (bytes != null) await _push(name, bytes);
    }
  }

  Future<void> _push(String name, Uint8List bytes) async {
    final uid = _uid;
    if (!_ready || uid == null) return;
    final hash = _hash(bytes);
    if (_remoteHashes[name] == hash) return;

    final data = Uint8List.fromList(gzip.encode(bytes));
    if (data.length > _maxBytes) {
      debugPrint('Ink sync skipped $name: over 900 KB.');
      return;
    }
    _remoteHashes[name] = hash;
    final state = await _loadState();
    state[name] = hash;
    await _saveState(state);
    // Writes only complete once online, so never await them in the queue.
    unawaited(
      store
          .upsert(
            uid,
            CloudInk(
              name: name,
              hash: hash,
              data: data,
              updatedAt: DateTime.now(),
            ),
          )
          .catchError((Object e) => debugPrint('Ink sync upload failed: $e')),
    );
  }

  Future<Map<String, String>> _loadState() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(stateKey);
      if (raw == null) return {};
      return (jsonDecode(raw) as Map<String, dynamic>).cast<String, String>();
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveState(Map<String, String> state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(stateKey, jsonEncode(state));
    } catch (_) {}
  }

  /// Two FNV-1a variants so an accidental collision cannot hide an edit.
  @visibleForTesting
  static String hashOf(Uint8List bytes) => _hash(bytes);

  static String _hash(Uint8List bytes) {
    var a = 0x811c9dc5;
    var b = 0x01000193;
    for (final byte in bytes) {
      a = ((a ^ byte) * 0x01000193) & 0xffffffff;
      b = ((b ^ byte) * 0x811c9dc5) & 0xffffffff;
    }
    return '${bytes.length}-${a.toRadixString(16)}-${b.toRadixString(16)}';
  }
}
