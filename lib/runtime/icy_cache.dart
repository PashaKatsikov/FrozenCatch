import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../contracts/launch_mode.dart';

// ============================================================
// ICY CACHE — persistence layer (prefs + secure storage)
// ============================================================
// Cleartext flags (mode, cooldowns) live in SharedPreferences; the
// content URL (which is sensitive on-device) lives in encrypted
// secure storage. Keys are neutral so a prefs dump doesn't reveal
// what the app does.
// ============================================================

class IcyCache {
  IcyCache({FlutterSecureStorage? secure})
      : _secure = secure ?? const FlutterSecureStorage();

  // Prefs keys — intentionally opaque so a `prefs.getAll()` dump
  // gives no functional hint about the gray branch.
  static const String _keyMode = 'fc_mode_v1';
  static const String _keyDestination = 'fc_dst_blob';
  static const String _keyExpiry = 'fc_exp_stamp';
  static const String _keyPromptCooldown = 'fc_beacon_wait_until';
  static const String _keyBeaconAllowed = 'fc_beacon_allowed';
  static const String _keyBeaconOsBlocked = 'fc_beacon_os_blocked';
  static const String _keyDeferredDestination = 'fc_dst_pending_blob';

  late final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  Future<void> hydrate() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Launch mode ────────────────────────────────────────────
  LaunchMode readMode() => LaunchMode.read(_prefs.getString(_keyMode));

  Future<void> commitMode(LaunchMode mode) =>
      _prefs.setString(_keyMode, mode.write());

  // ── Cached destination (secure) ────────────────────────────
  Future<String?> readDestination() => _secure.read(key: _keyDestination);

  Future<void> writeDestination(String url) =>
      _secure.write(key: _keyDestination, value: url);

  // ── Destination expiry ─────────────────────────────────────
  int? readExpiry() => _prefs.getInt(_keyExpiry);

  Future<void> writeExpiry(int unixSeconds) =>
      _prefs.setInt(_keyExpiry, unixSeconds);

  bool isDestinationStale() {
    final int? until = readExpiry();
    if (until == null) return true;
    return _epochNow() >= until;
  }

  // ── Beacon (push) permission state ─────────────────────────
  bool isBeaconAllowed() => _prefs.getBool(_keyBeaconAllowed) ?? false;

  Future<void> markBeaconAllowed(bool value) =>
      _prefs.setBool(_keyBeaconAllowed, value);

  /// True once the user denied the OS dialog once — Android will silently
  /// swallow every subsequent request, so we must stop showing the invite.
  bool isBeaconOsBlocked() => _prefs.getBool(_keyBeaconOsBlocked) ?? false;

  Future<void> markBeaconOsBlocked() =>
      _prefs.setBool(_keyBeaconOsBlocked, true);

  int? readPromptCooldown() => _prefs.getInt(_keyPromptCooldown);

  Future<void> writePromptCooldown(int unixSeconds) =>
      _prefs.setInt(_keyPromptCooldown, unixSeconds);

  /// Whether the "Enable notifications" invite should be shown before
  /// the WebView opens. False once the user granted / permanently denied
  /// the permission, or while the Skip cooldown is active.
  bool shouldShowBeaconPrompt() {
    if (isBeaconAllowed()) return false;
    if (isBeaconOsBlocked()) return false;
    final int? until = readPromptCooldown();
    if (until == null) return true;
    return _epochNow() >= until;
  }

  // ── One-shot push destination (cold-tap payload) ───────────
  Future<void> stashDeferredDestination(String? url) async {
    if (url == null) {
      await _secure.delete(key: _keyDeferredDestination);
    } else {
      await _secure.write(key: _keyDeferredDestination, value: url);
    }
  }

  Future<String?> consumeDeferredDestination() async {
    final String? url = await _secure.read(key: _keyDeferredDestination);
    if (url != null) await _secure.delete(key: _keyDeferredDestination);
    return url;
  }

  static int _epochNow() =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000;
}
