import 'legal_endpoints.dart';
import 'sealed_keys.dart';

// ============================================================
// FROST IDENTITY — global constants for Frozen Catch
// ============================================================
// Central access point for every "who am I" value the runtime
// layer needs. Identity strings are plain literals; endpoints and
// credentials resolve lazily through the cipher so the plaintext
// never lands in the binary.
//
// UA suffix decision (per .cursor/rules/gray_user_agent.mdc):
// ------------------------------------------------------------
// Frozen Catch is a casual ice-fishing clicker, neither a slot
// nor an aviator/crash game. Rule §2 forbids shipping a slot-style
// `appid/appname` suffix "just in case", so this build omits it.
// If a partner backend later requires attribution routing via the
// UA, revisit `runtime/agent_mint.dart` and append the suffix
// there — the choice is documented above `_composeUserAgent()`.
// ============================================================

class FrostIdentity {
  FrostIdentity._();

  /// Android applicationId + iOS bundle id. Must exactly match:
  ///   • android/app/build.gradle.kts → applicationId + namespace
  ///   • android/app/src/main/kotlin/**/MainActivity.kt → package
  ///   • android/app/google-services.json → package_name
  static const String bundleId = 'com.frozcatch.frozencatch';

  /// Store id sent as `store_id` in the gate body. On Android this is
  /// identical to [bundleId]; iOS would prefix the numeric App Store id
  /// with the literal "id" (unused — this build is Android-only).
  static const String storeId = 'com.frozcatch.frozencatch';

  /// Display name — kept in sync with `android:label` in the manifest.
  static const String displayName = 'Frozen Catch';

  /// iOS numeric App Store id (unused on Android — kept empty).
  static const String iosStoreNumericId = '';

  /// The gate endpoint (config.php) resolved from the sealed byte array.
  static String get gateEndpoint => unsealGateEndpoint();

  /// AppsFlyer Dev Key. Empty until credentials land — the gate simply
  /// short-circuits and the app opens the native game (safe fallback).
  static String get attributionDevKey => unsealAttributionDevKey();

  /// Firebase project number sent as `firebase_project_id`.
  static String get messagingProjectId => unsealMessagingProject();

  /// Public URLs — plain literals (see `legal_endpoints.dart`).
  static const String privacyUrl = kPrivacyPolicyUrl;
  static const String supportUrl = kSupportUrl;
  static const String homeUrl = kSiteHome;

  /// Cooldown between two "Enable notifications" prompts after Skip.
  /// Per TZ: 3 calendar days. Do not lower without manager approval.
  static const int beaconPromptCooldownSeconds = 3 * 24 * 60 * 60;

  /// Delay (seconds) before re-querying GCD when the first conversion
  /// callback reports `af_status == "Organic"` for a possibly paid
  /// install. See android_gray_guide.md → Organic false-positive.
  static const int organicRecheckDelaySeconds = 5;
}
