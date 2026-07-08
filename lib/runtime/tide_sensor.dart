import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

// ============================================================
// TIDE SENSOR — connectivity probe with DNS validation
// ============================================================
// Every "am I online?" check goes through here. The adapter state
// alone is not enough (captive portals, throttled VPN tunnels all
// report "wifi" while nothing routes); we finish the check with a
// real DNS lookup so degraded networks are treated as offline.
//
// VPN, Ethernet, Bluetooth and "other" adapter types are considered
// valid transports — see gray_part_pitfalls.md §3 for the reasoning
// (VPN was previously mis-classified as offline while it was being
// brought up, causing a No-Wi-Fi flash).
//
// The DNS timeout is generous (7 seconds) because a genuinely dead
// network fails instantly with a SocketException — the extra headroom
// only kicks in on slow tunnels.
// ============================================================

class TideSensor {
  TideSensor({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  static const Set<ConnectivityResult> _validAdapters = <ConnectivityResult>{
    ConnectivityResult.wifi,
    ConnectivityResult.mobile,
    ConnectivityResult.ethernet,
    ConnectivityResult.vpn,
    ConnectivityResult.bluetooth,
    ConnectivityResult.other,
  };

  static const List<String> _probeHosts = <String>[
    'cloudflare.com',
    'one.one.one.one',
  ];

  Future<bool> hasSignal() async {
    final List<ConnectivityResult> states =
        await _connectivity.checkConnectivity();
    final bool anyValid =
        states.any((ConnectivityResult r) => _validAdapters.contains(r));
    if (!anyValid) return false;

    for (final String host in _probeHosts) {
      try {
        final List<InternetAddress> addrs = await InternetAddress.lookup(host)
            .timeout(const Duration(seconds: 7));
        if (addrs.isNotEmpty && addrs.first.rawAddress.isNotEmpty) return true;
      } catch (_) {
        continue;
      }
    }
    return false;
  }

  /// Stream of raw adapter transitions. Consumers must debounce this
  /// (≥ 700 ms) to absorb VPN-flicker noise — the No-Wi-Fi screen
  /// should not appear on a healthy tunnel handshake.
  Stream<List<ConnectivityResult>> get transitions =>
      _connectivity.onConnectivityChanged;
}
