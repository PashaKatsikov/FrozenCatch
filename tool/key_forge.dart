// ignore_for_file: avoid_print
// ============================================================
// KEY FORGE — packs plaintext secrets into obfuscated byte arrays
// ============================================================
// Mirrors lib/cipher/cipher.dart exactly. Run with:
//
//   dart run tool/key_forge.dart
//
// Then paste each printed array over the matching constant in
// lib/settings/sealed_keys.dart.
//
// ⚠️ ALWAYS run via `dart run`, never a PowerShell foreach loop —
// PowerShell overflows integers at 32 bits on Windows and produces
// off-by-one bytes that silently decode to garbage.
//
// ⚠️ Keep [salt] + [stride] IN SYNC with cipher.dart. Changing
// either here without touching cipher.dart (or vice-versa) will
// produce arrays that decode to nonsense at runtime.
// ============================================================

const String salt = 'nRt3-2gLc*Frost-Lk';
const int stride = 34;

List<int> _spinKeystream() {
  int hash = 0x811C9DC5;
  for (final int c in salt.codeUnits) {
    hash = (hash ^ c) & 0xFFFFFFFF;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  int state = hash == 0 ? 0x6C078965 : hash;
  final List<int> key = List<int>.filled(stride, 0);
  for (int i = 0; i < stride; i++) {
    state ^= (state << 13) & 0xFFFFFFFF;
    state ^= state >> 17;
    state ^= (state << 5) & 0xFFFFFFFF;
    state &= 0xFFFFFFFF;
    key[i] = (state >> 8) & 0xFF;
  }
  return key;
}

final List<int> _keystream = _spinKeystream();

List<int> _pack(String plain) {
  final List<int> src = plain.codeUnits;
  final List<int> out = List<int>.filled(src.length, 0);
  for (int i = 0; i < src.length; i++) {
    out[i] =
        (src[i] ^ _keystream[i % stride] ^ ((i * 3) & 0xFF)) & 0xFF;
  }
  return out;
}

void _emit(String label, String plaintext) {
  if (plaintext.isEmpty) {
    print('// $label — (empty, fill in later)');
    print('const <int>[];\n');
    return;
  }
  final List<int> bytes = _pack(plaintext);
  print('// $label  <=  "$plaintext"');
  print('const <int>[${bytes.join(', ')}],\n');
}

void main() {
  // ── Plaintext values for THIS project ────────────────────────
  // Fill AppsFlyer + Firebase once the manager delivers them.
  const String gateEndpoint = 'https://frozencattch.com/config.php';
  const String gcdBase =
      'https://gcdsdk.appsflyer.com/install_data/v4.0/';
  const String chromeTag = '149.0.7694.23';
  const String webKitTag = '537.36';
  const String attributionDevKey = '9k3XvHTFrYecFyY5e8kbH5';
  const String messagingProject = '90898260677';

  print('=== Frozen Catch key_forge ===\n');
  _emit('_gateEndpointBytes', gateEndpoint);
  _emit('_gcdBaseBytes', gcdBase);
  _emit('_chromeTagBytes', chromeTag);
  _emit('_webKitTagBytes', webKitTag);
  _emit('_attributionDevKeyBytes', attributionDevKey);
  _emit('_messagingProjectBytes', messagingProject);
}
