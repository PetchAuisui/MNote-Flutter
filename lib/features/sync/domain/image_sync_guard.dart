import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hard ceilings for picture sync. Firebase Storage bills past its free
/// tier, so every cloud call must be approved here first, and anything over
/// a ceiling is skipped instead of attempted.
class ImageSyncLimits {
  const ImageSyncLimits({
    this.maxFileBytes = 1536 * 1024,
    this.maxTotalBytes = 200 * 1024 * 1024,
    this.maxDailyUploadBytes = 30 * 1024 * 1024,
    this.maxDailyDownloadBytes = 60 * 1024 * 1024,
    this.maxDailyOperations = 300,
    this.failuresBeforePause = 3,
    this.pause = const Duration(hours: 6),
    this.missingRetry = const Duration(minutes: 10),
  });

  /// Matches the size limit in `storage.rules`.
  final int maxFileBytes;

  /// Everything this device has uploaded, far below the 5 GB free tier.
  final int maxTotalBytes;
  final int maxDailyUploadBytes;
  final int maxDailyDownloadBytes;

  /// Every Storage request counts, including lookups and failed ones.
  final int maxDailyOperations;

  /// Consecutive failures that stop all picture sync for [pause].
  final int failuresBeforePause;
  final Duration pause;

  /// How long a picture the cloud lacks is left alone before asking again.
  final Duration missingRetry;
}

/// Keeps picture sync inside [ImageSyncLimits], remembered across launches.
class ImageSyncGuard {
  ImageSyncGuard({this.limits = const ImageSyncLimits(), DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static const stateKey = 'mnote_image_sync_guard';

  /// Turns picture sync off entirely if it ever needs to be stopped quickly.
  static const enabled = true;

  /// Accepted picture types, by lower-case file extension.
  static const contentTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'webp': 'image/webp',
  };

  final ImageSyncLimits limits;
  final DateTime Function() _now;

  String _day = '';
  int _operations = 0;
  int _uploadedToday = 0;
  int _downloadedToday = 0;
  int _failures = 0;
  DateTime? _pausedUntil;
  Map<String, int> _uploaded = {};
  Map<String, DateTime> _missing = {};
  bool _loaded = false;

  /// Bytes this device has uploaded in total.
  int get totalUploaded => _uploaded.values.fold(0, (sum, size) => sum + size);

  /// The content type for [name], or null when it is not an accepted picture.
  static String? contentTypeOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0) return null;
    return contentTypes[name.substring(dot + 1).toLowerCase()];
  }

  Future<bool> isUploaded(String name) async {
    await _load();
    return _uploaded.containsKey(name);
  }

  Future<bool> isMissingRecently(String name) async {
    await _load();
    final since = _missing[name];
    return since != null && _now().difference(since) < limits.missingRetry;
  }

  /// Approves one cheap request such as a lookup. Counts against the daily
  /// operations ceiling whether or not it later succeeds.
  Future<bool> reserveOperation() async {
    await _load();
    if (!_open) return false;
    _operations++;
    await _save();
    return true;
  }

  /// Approves uploading [bytes] under [name] and counts it right away, so a
  /// crash or a failed upload cannot be retried past the ceiling.
  Future<bool> reserveUpload(String name, int bytes) async {
    await _load();
    if (!_open || bytes > limits.maxFileBytes) return false;
    if (_uploadedToday + bytes > limits.maxDailyUploadBytes) return false;
    final replaced = _uploaded[name] ?? 0;
    if (totalUploaded - replaced + bytes > limits.maxTotalBytes) return false;
    _operations++;
    _uploadedToday += bytes;
    await _save();
    return true;
  }

  /// Approves a download of at most [limits.maxFileBytes].
  Future<bool> reserveDownload() async {
    await _load();
    if (!_open) return false;
    if (_downloadedToday + limits.maxFileBytes > limits.maxDailyDownloadBytes) {
      return false;
    }
    _operations++;
    await _save();
    return true;
  }

  Future<void> recordUploaded(String name, int bytes) async {
    await _load();
    _uploaded[name] = bytes;
    _missing.remove(name);
    _failures = 0;
    await _save();
  }

  Future<void> recordDownloaded(int bytes) async {
    await _load();
    _downloadedToday += bytes;
    _failures = 0;
    await _save();
  }

  Future<void> recordMissing(String name) async {
    await _load();
    _missing[name] = _now();
    await _save();
  }

  /// Counts a failed request; repeated failures pause picture sync.
  Future<void> recordFailure() async {
    await _load();
    if (++_failures >= limits.failuresBeforePause) {
      _pausedUntil = _now().add(limits.pause);
      _failures = 0;
    }
    await _save();
  }

  Future<void> reset() async {
    _uploaded = {};
    _missing = {};
    _failures = 0;
    _pausedUntil = null;
    _loaded = true;
    await _save();
  }

  bool get _open {
    final until = _pausedUntil;
    if (until != null && _now().isBefore(until)) return false;
    return _operations < limits.maxDailyOperations;
  }

  String get _today {
    final n = _now();
    return '${n.year}-${n.month}-${n.day}';
  }

  void _rollDay() {
    if (_day == _today) return;
    _day = _today;
    _operations = 0;
    _uploadedToday = 0;
    _downloadedToday = 0;
  }

  Future<void> _load() async {
    if (_loaded) {
      _rollDay();
      return;
    }
    _loaded = true;
    try {
      final raw = (await SharedPreferences.getInstance()).getString(stateKey);
      if (raw != null) {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        _day = json['day'] as String? ?? '';
        _operations = json['operations'] as int? ?? 0;
        _uploadedToday = json['uploadedToday'] as int? ?? 0;
        _downloadedToday = json['downloadedToday'] as int? ?? 0;
        _failures = json['failures'] as int? ?? 0;
        final until = json['pausedUntil'] as int?;
        _pausedUntil = until == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(until);
        _uploaded = (json['uploaded'] as Map<String, dynamic>? ?? {})
            .cast<String, int>();
        _missing = {
          for (final e
              in (json['missing'] as Map<String, dynamic>? ?? {}).entries)
            e.key: DateTime.fromMillisecondsSinceEpoch(e.value as int),
        };
      }
    } catch (e) {
      // Unreadable state must fail closed: assume today's budget is spent.
      debugPrint('Image sync guard could not load its state: $e');
      _day = _today;
      _operations = limits.maxDailyOperations;
    }
    _rollDay();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        stateKey,
        jsonEncode({
          'day': _day,
          'operations': _operations,
          'uploadedToday': _uploadedToday,
          'downloadedToday': _downloadedToday,
          'failures': _failures,
          'pausedUntil': _pausedUntil?.millisecondsSinceEpoch,
          'uploaded': _uploaded,
          'missing': {
            for (final e in _missing.entries)
              e.key: e.value.millisecondsSinceEpoch,
          },
        }),
      );
    } catch (e) {
      debugPrint('Image sync guard could not save its state: $e');
    }
  }
}
