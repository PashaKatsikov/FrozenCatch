import 'package:clarity_flutter/clarity_flutter.dart';

import '../settings/insight_env.dart';

// ============================================================
// INSIGHT — crash-safe Microsoft Clarity facade (Frozen Catch)
// ============================================================
// Every public method is guarded: a Clarity SDK failure must NEVER
// propagate into the gray flow. Use Insight.* everywhere — never
// call the Clarity SDK directly.
//
// Screen naming convention (keep stable — dashboard slices by these):
//   loading         ArcticRouter loading screen
//   push_invite     BeaconPromptStage
//   web             ContentStage (WebView)
//   offline         NoSignalStage
//
// Tags go in Clarity's "custom tags" store; high-cardinality values
// (URLs, hosts, labels, error text) MUST be tags, never event names.
// ============================================================

class Insight {
  const Insight._();

  static ClarityConfig get config => ClarityConfig(
        projectId: kClarityProjectId,
        logLevel: LogLevel.None,
      );

  /// Groups the session by AppsFlyer id and attaches attribution tags.
  /// Silently ignored if [aid] is null or empty.
  static void identify(String? aid, {Map<String, String> tags = const {}}) {
    if (aid != null && aid.isNotEmpty) {
      _guard(() => Clarity.setCustomUserId(_clip(aid, 255)));
      tag('aid', aid);
    }
    tags.forEach(tag);
  }

  /// Marks the current native screen: sets the label and emits a
  /// `screen_<name>` event so the "events" funnel is populated.
  static void screen(String name) {
    screenName(name);
    event('screen_$name');
  }

  /// Sets the current screen label and mirrors it into the persistent
  /// `last_screen` tag. Clarity keeps the LAST tag value per session,
  /// so filtering by `last_screen` immediately shows the drop-off point.
  static void screenName(String name) => _guard(() {
        Clarity.setCurrentScreenName(_clip(name, 255));
        Clarity.setCustomTag('last_screen', _clip(name, 255));
      });

  /// Emits a custom event (max 254 chars, hard-clipped).
  static void event(String name) =>
      _guard(() => Clarity.sendCustomEvent(_clip(name, 254)));

  /// Attaches a key/value tag to the current session.
  /// Silently ignored when [value] is empty.
  static void tag(String key, String value) {
    if (value.isEmpty) return;
    _guard(() => Clarity.setCustomTag(key, _clip(value, 255)));
  }

  // ── Internal helpers ────────────────────────────────────────

  static String _clip(String v, int max) =>
      v.length <= max ? v : v.substring(0, max);

  static void _guard(void Function() body) {
    try {
      body();
    } catch (_) {}
  }
}
