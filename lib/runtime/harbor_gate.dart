import 'dart:convert';

import '../contracts/gate_verdict.dart';
import '../settings/identity.dart';
import 'agent_mint.dart';
import 'icy_cache.dart';

// ============================================================
// HARBOR GATE — posts the attribution body, reads the verdict
// ============================================================
// Sends the merged attribution body to the gate endpoint. When the
// backend approves, the destination URL + expiry are cached so a
// subsequent launch on a broken network can fall back to it. Every
// failure (missing endpoint, non-200, decode error, timeout) yields
// a "fault" verdict which routes the user to the native game.
//
// The 15-second timeout is the contract limit — do not tighten it
// (occasional cold cache round-trips can push the response past
// 8-10 seconds on slow markets).
// ============================================================

class HarborGate {
  HarborGate(this._cache);

  final IcyCache _cache;

  static const Duration _timeout = Duration(seconds: 15);

  Future<GateVerdict> query(Map<String, dynamic> body) async {
    final String endpoint = FrostIdentity.gateEndpoint;
    if (endpoint.isEmpty) {
      return GateVerdict.fault('endpoint-unset');
    }

    try {
      final response = await frostHttp
          .post(
            Uri.parse(endpoint),
            headers: const <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        return GateVerdict.fault('status-${response.statusCode}');
      }

      final Map<String, dynamic> raw =
          jsonDecode(response.body) as Map<String, dynamic>;
      final GateVerdict verdict = GateVerdict.parse(raw);

      if (verdict.approved && verdict.hasDestination) {
        await _cache.writeDestination(verdict.destination!);
        if (verdict.expiresAt != null) {
          await _cache.writeExpiry(verdict.expiresAt!);
        }
      }
      return verdict;
    } catch (e) {
      return GateVerdict.fault(e.toString());
    }
  }

  Future<String?> lastKnownDestination() => _cache.readDestination();
}
