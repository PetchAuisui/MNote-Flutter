import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:mnote/features/sync/domain/network_monitor.dart';

/// [NetworkMonitor] backed by the platform's connectivity updates.
class ConnectivityNetworkMonitor implements NetworkMonitor {
  ConnectivityNetworkMonitor({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  final _changes = StreamController<void>.broadcast();
  bool _isMetered = false;

  @override
  bool get isMetered => _isMetered;

  @override
  Stream<void> get changes => _changes.stream;

  /// Reads the current connection and starts following it. Never throws: when
  /// the platform cannot tell, the connection is treated as not metered.
  Future<void> start() async {
    try {
      _update(await _connectivity.checkConnectivity());
      _connectivity.onConnectivityChanged.listen(_update);
    } catch (e) {
      debugPrint('Could not watch connectivity: $e');
    }
  }

  void _update(List<ConnectivityResult> results) {
    final metered =
        results.contains(ConnectivityResult.mobile) &&
        !results.contains(ConnectivityResult.wifi) &&
        !results.contains(ConnectivityResult.ethernet);
    if (metered == _isMetered) return;
    _isMetered = metered;
    _changes.add(null);
  }
}
