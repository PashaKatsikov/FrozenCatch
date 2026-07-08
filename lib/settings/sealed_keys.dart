import '../cipher/cipher.dart';

// ============================================================
// SEALED KEYS — obfuscated endpoints & credentials
// ============================================================
// Every byte array below is produced by `dart run tool/key_forge.dart`
// using the salt + stride from `cipher/cipher.dart`. Plaintext must
// NEVER be committed here — that would defeat the point.
//
// Empty arrays are a legal state: `reveal([])` returns "" and the
// runtime layers gracefully fall back to the native fishing game.
// AppsFlyer / Firebase credentials are supplied later; until then
// the gray branch simply never activates.
//
// After changing the salt or stride in `cipher.dart`, or after
// receiving fresh credentials from the manager:
//   1. Fill the plaintext at the top of `tool/key_forge.dart`.
//   2. Run  `dart run tool/key_forge.dart`.
//   3. Paste each printed array over the corresponding constant
//      in this file. Order matters — labels are shown by the tool.
// ============================================================

/// The gate endpoint we POST to during boot (whitelist verdict).
const List<int> _gateEndpointBytes = <int>[254, 232, 144, 206, 197, 42, 198, 12, 52, 125, 101, 236, 60, 72, 231, 85, 255, 226, 27, 59, 109, 188, 105, 254, 54, 197, 161, 148, 24, 171, 15, 18, 192, 235, 128];

/// GCD API base used when AppsFlyer reports a false-positive Organic
/// status on the first callback (we re-query for the real attribution).
const List<int> _gcdBaseBytes = <int>[254, 232, 144, 206, 197, 42, 198, 12, 53, 108, 110, 229, 61, 77, 170, 85, 251, 230, 11, 53, 47, 166, 99, 225, 55, 197, 161, 151, 81, 171, 6, 79, 196, 226, 156, 154, 209, 188, 169, 30, 226, 98, 66, 161, 190, 0, 216];

/// Chrome major version fragment that appears in the forged UA.
const List<int> _chromeTagBytes = <int>[167, 168, 221, 144, 134, 62, 222, 21, 107, 59, 36, 164, 106];

/// WebKit version fragment that appears in the forged UA.
const List<int> _webKitTagBytes = <int>[163, 175, 211, 144, 133, 38];

/// AppsFlyer Dev Key.
const List<int> _attributionDevKeyBytes = <int>[175, 247, 215, 230, 192, 88, 189, 101, 32, 86, 111, 245, 31, 95, 221, 1, 238, 174, 19, 49, 11, 234];

/// Firebase project number (from google-services.json → project_info →
/// project_number). Sent as `firebase_project_id` in the gate body.
const List<int> _messagingProjectBytes = <int>[175, 172, 220, 135, 142, 34, 223, 19, 100, 56, 61];

// ─── Accessors ────────────────────────────────────────────────

String unsealGateEndpoint() => reveal(_gateEndpointBytes);

String unsealChromeTag() => reveal(_chromeTagBytes);

String unsealWebKitTag() => reveal(_webKitTagBytes);

String unsealAttributionDevKey() => reveal(_attributionDevKeyBytes);

String unsealMessagingProject() => reveal(_messagingProjectBytes);

/// Composes the GCD retry URL for the given app + device identifier.
/// Returns "" when the base is not yet packed — callers must treat that
/// as "no retry available, use whatever the SDK already delivered".
String composeGcdQuery(String appId, String deviceId) {
  final String base = reveal(_gcdBaseBytes);
  if (base.isEmpty) return '';
  final String key = unsealAttributionDevKey();
  return '$base$appId?devkey=$key&device_id=$deviceId';
}
