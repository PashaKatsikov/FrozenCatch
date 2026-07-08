/// Decoded response from the gate (config.php) endpoint.
///
/// Wire format on the backend is `{ok, url, expires, message}`; keys are
/// renamed here for readability but the actual JSON mapping happens
/// verbatim inside [GateVerdict.parse] so the backend contract is
/// preserved.
class GateVerdict {
  const GateVerdict({
    required this.approved,
    this.destination,
    this.diagnostic,
    this.expiresAt,
  });

  /// Corresponds to backend `ok`. When true and [destination] is set,
  /// the router opens the WebView; anything else routes to the game.
  final bool approved;

  /// Corresponds to backend `url` — the content URL to load verbatim.
  final String? destination;

  /// Backend `message`. Diagnostic only (e.g. "no data", "organic").
  final String? diagnostic;

  /// Backend `expires` — unix-seconds after which [destination] must be
  /// refreshed on the next launch.
  final int? expiresAt;

  bool get hasDestination =>
      destination != null && destination!.isNotEmpty;

  factory GateVerdict.parse(Map<String, dynamic> map) {
    return GateVerdict(
      approved: map['ok'] as bool? ?? false,
      destination: map['url'] as String?,
      diagnostic: map['message'] as String?,
      expiresAt: map['expires'] as int?,
    );
  }

  factory GateVerdict.fault(String reason) =>
      GateVerdict(approved: false, diagnostic: reason);
}
