import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mnote/features/sync/domain/cloud_image_store.dart';
import 'package:mnote/features/sync/domain/image_sync_guard.dart';
import 'package:mnote/features/sync/domain/sync_companion.dart';
import 'package:mnote/features/workspace/data/image_shrinker.dart';

/// Mirrors the pictures that notes reference (`![alt](images/name.jpg)`) to
/// the account: missing ones are uploaded, and ones other devices added are
/// downloaded next to the notes.
///
/// Every cloud request first passes the [ImageSyncGuard], which refuses
/// anything beyond its size, quota and request ceilings.
class SyncedImageFiles implements SyncCompanion {
  SyncedImageFiles({
    required this.store,
    required this.uidProvider,
    required this.directory,
    required this.guard,
    this.maxPerPass = 40,
  });

  final CloudImageStore store;
  final String? Function() uidProvider;

  /// The folder that holds `images/`, which is where notes keep their files.
  final Future<Directory> Function() directory;
  final ImageSyncGuard guard;

  /// Pictures handled per pass, so one pass stays short.
  final int maxPerPass;

  /// The text of every note that may reference pictures. Set by the owner of
  /// the document library.
  Future<Iterable<String>> Function()? notes;

  static final _reference = RegExp(
    r'!\[[^\]]*\]\((images/(?:[^()\s]|\([^()\s]*\))+)\)',
  );

  String? _uid;
  Future<void> _queue = Future.value();
  bool _queued = false;

  /// The decoded `images/…` paths that [markdown] points at.
  static Set<String> referencedIn(Iterable<String> markdown) {
    final names = <String>{};
    for (final text in markdown) {
      for (final match in _reference.allMatches(text)) {
        final name = _decode(match.group(1)!);
        if (name != null && _safe(name)) names.add(name);
      }
    }
    return names;
  }

  static String? _decode(String path) {
    try {
      return Uri.decodeFull(path);
    } on FormatException {
      return null;
    }
  }

  /// Only direct children of `images/` with a picture extension.
  static bool _safe(String name) {
    if (!name.startsWith('images/')) return false;
    final file = name.substring('images/'.length);
    if (file.isEmpty || file.contains('/') || file.contains(r'\')) return false;
    if (file.contains('..')) return false;
    return ImageSyncGuard.contentTypeOf(file) != null;
  }

  @override
  Future<void> start() async {
    _uid = uidProvider();
    await libraryChanged();
  }

  @override
  Future<void> stop() async {
    _uid = null;
  }

  @override
  Future<void> refresh() => libraryChanged();

  @override
  Future<void> libraryChanged() {
    if (!ImageSyncGuard.enabled || _uid == null) {
      debugPrint('Image sync: skipped (signed out or disabled)');
      return Future.value();
    }
    // Passes triggered while one is waiting merge into that one.
    if (_queued) return _queue;
    _queued = true;
    _queue = _queue
        .then((_) {
          _queued = false;
          return _pass();
        })
        .catchError((Object e) {
          debugPrint('Image sync pass failed: $e');
        });
    return _queue;
  }

  @override
  Future<void> clearLocal() async {
    await _queue;
    try {
      final images = Directory('${(await directory()).path}/images');
      if (await images.exists()) await images.delete(recursive: true);
    } on FileSystemException catch (e) {
      debugPrint('Could not clear pictures: $e');
    }
    await guard.reset();
  }

  Future<void> _pass() async {
    final uid = _uid;
    final source = notes;
    if (uid == null || source == null) {
      debugPrint('Image sync: not ready (uid=$uid, notes=${source != null})');
      return;
    }
    final base = (await directory()).path;
    final names = referencedIn(await source());
    debugPrint('Image sync: ${names.length} referenced picture(s) in $base');
    var handled = 0;
    for (final name in names) {
      if (handled >= maxPerPass || _uid != uid) return;
      final file = File('$base/$name');
      final stored = name.substring('images/'.length);
      if (await file.exists()) {
        if (await guard.isUploaded(stored)) continue;
        debugPrint('Image sync: uploading $stored');
        handled++;
        if (!await _upload(uid, stored, file)) return;
      } else {
        if (await guard.isMissingRecently(stored)) continue;
        debugPrint('Image sync: $stored is not on this device, downloading');
        handled++;
        if (!await _download(uid, stored, file)) return;
      }
    }
  }

  /// Returns false when sync should stop for now (a ceiling was reached or
  /// the request failed).
  Future<bool> _upload(String uid, String name, File file) async {
    final contentType = ImageSyncGuard.contentTypeOf(name)!;
    if (!await guard.reserveOperation()) {
      debugPrint('Image sync: guard is closed for now, skipping $name');
      return false;
    }
    try {
      debugPrint('Image sync: checking the cloud for $name');
      final existing = await store.sizeOf(uid, name);
      debugPrint('Image sync: cloud has $name = $existing');
      if (existing != null) {
        // Another device uploaded it already.
        await guard.recordUploaded(name, existing);
        return true;
      }
      final length = await file.length();
      if (guard.isUnreadable(length)) {
        debugPrint('Image sync: $name is $length bytes, too big, not synced');
        await guard.recordSkipped(name);
        return true;
      }
      var bytes = await file.readAsBytes();
      var type = contentType;
      if (guard.isTooLarge(bytes.length)) {
        // Older, full-size pictures go up as a smaller copy; the original
        // stays on this device.
        final dot = name.lastIndexOf('.');
        final shrunk = await ImageShrinker.shrink(bytes, name.substring(dot));
        if (shrunk == null || guard.isTooLarge(shrunk.bytes.length)) {
          debugPrint('Image sync: $name stays over the size limit, not synced');
          await guard.recordSkipped(name);
          return true;
        }
        bytes = shrunk.bytes;
        type =
            ImageSyncGuard.contentTypes[shrunk.extension
                .substring(1)
                .toLowerCase()] ??
            contentType;
      }
      if (!await guard.reserveUpload(name, bytes.length)) {
        debugPrint('Image sync: guard refused $name (${bytes.length} bytes)');
        return false;
      }
      await store.upload(uid, name, bytes, type);
      await guard.recordUploaded(name, bytes.length);
      debugPrint('Image sync: uploaded $name (${bytes.length} bytes)');
      return true;
    } on Object catch (e) {
      debugPrint('Image upload failed for $name: $e');
      await guard.recordFailure();
      return false;
    }
  }

  Future<bool> _download(String uid, String name, File file) async {
    if (!await guard.reserveDownload()) return false;
    try {
      final Uint8List? bytes = await store.download(
        uid,
        name,
        guard.limits.maxFileBytes,
      );
      if (bytes == null) {
        await guard.recordMissing(name);
        return true;
      }
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      await guard.recordDownloaded(bytes.length);
      return true;
    } on Object catch (e) {
      debugPrint('Image download failed for $name: $e');
      await guard.recordFailure();
      return false;
    }
  }
}
