/// Tells sync whether the device is on a metered (mobile data) connection.
abstract interface class NetworkMonitor {
  /// True on mobile data without Wi-Fi or Ethernet. Offline counts as not
  /// metered: there is nothing to save by waiting.
  bool get isMetered;

  /// Fires whenever [isMetered] may have changed.
  Stream<void> get changes;
}
