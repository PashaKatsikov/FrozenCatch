import 'dart:typed_data';

// ============================================================
// CIPHER — keystream string obfuscator (Frozen Catch build)
// ============================================================
// Wraps every sensitive string (config endpoint, AppsFlyer key,
// Firebase project number, forged UA fragments) inside a
// project-unique keystream so the plaintext never ends up as a
// literal in the compiled APK.
//
// Scheme (deliberately not the same math as any prior project):
//   1. `_saltPhrase` seeds an FNV-1a 32-bit hash.
//   2. That hash primes an xorshift32 PRNG which produces a
//      `_keyStride`-byte keystream (we take the middle byte of
//      each 32-bit state so the pattern differs from projects
//      that took the high or low byte).
//   3. Every encoded byte = plain ^ key[i % stride] ^ ((i * 3) & 0xFF).
//      Multiplying the position index by 3 shifts the positional
//      mask cycle so identical inputs encode differently vs. the
//      template's `(i & 0xFF)` mask.
//
// The transform is symmetric — the packer in tool/key_forge.dart
// applies the exact same routine to produce the byte arrays that
// live in `settings/sealed_keys.dart`.
//
// ─────────────────────────────────────────────────────────────
// [FINGERPRINT] Per-project mandatory change
// ─────────────────────────────────────────────────────────────
// Both `_saltPhrase` and `_keyStride` are fresh for THIS project.
// If you ever fork this shell into another Play Console listing:
//   • pick a new 10-20 char ASCII salt (no dictionary words tied
//     to the theme — random opaque token wins);
//   • bump `_keyStride` to a different value in 20-56;
//   • re-run `dart run tool/key_forge.dart` and paste the six
//     fresh byte arrays into `sealed_keys.dart`.
// Leaving stale bytes with a new salt yields garbage strings.
// ============================================================

const String _saltPhrase = 'nRt3-2gLc*Frost-Lk';
const int _keyStride = 34;

Uint8List _spinKeystream() {
  int hash = 0x811C9DC5;
  for (final int c in _saltPhrase.codeUnits) {
    hash = (hash ^ c) & 0xFFFFFFFF;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  int state = hash == 0 ? 0x6C078965 : hash;
  final Uint8List key = Uint8List(_keyStride);
  for (int i = 0; i < _keyStride; i++) {
    state ^= (state << 13) & 0xFFFFFFFF;
    state ^= state >> 17;
    state ^= (state << 5) & 0xFFFFFFFF;
    state &= 0xFFFFFFFF;
    key[i] = (state >> 8) & 0xFF;
  }
  return key;
}

final Uint8List _keystream = _spinKeystream();

/// Decodes a keystream-obfuscated byte list back to its original UTF-8 string.
/// An empty input yields "" (the fallback path used while the manager has not
/// supplied credentials — the gate call will fail and the app opens the game).
String reveal(List<int> packed) {
  if (packed.isEmpty) return '';
  final Uint8List out = Uint8List(packed.length);
  for (int i = 0; i < packed.length; i++) {
    out[i] = (packed[i] ^ _keystream[i % _keyStride] ^ ((i * 3) & 0xFF)) & 0xFF;
  }
  return String.fromCharCodes(out);
}
