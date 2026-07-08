import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'agent_mint.dart';
import 'icy_cache.dart';

// ============================================================
// BEACON HUB — Firebase Messaging + local notification display
// ============================================================
// Cold-start push taps (app was killed) stash the URL so the router
// opens it on the next boot. Warm taps (background / foreground)
// deliver the URL live via [onLiveDestination] without persisting
// it — that's the one-time contract for push URLs.
//
// The Android channel id declared here must EXACTLY match the value
// of `com.google.firebase.messaging.default_notification_channel_id`
// in AndroidManifest.xml — Firebase silently drops notifications
// otherwise.
//
// The small icon points at `res/drawable/ic_notification.xml` — a
// flame vector, per gray_part_pitfalls.md §15. It must be different
// from the launcher icon.
// ============================================================

const String kBeaconChannelId = 'frost_catch_updates';
const String kBeaconChannelName = 'Catch alerts';
const String _smallIconRef = '@drawable/ic_notification';

@pragma('vm:entry-point')
Future<void> _backgroundReceiver(RemoteMessage _) async {
  // Background renderings are handled by the OS; the tap is processed on
  // resume (warm) or boot (cold) — no work needed in this isolate.
}

class BeaconHub {
  BeaconHub(this._cache);

  final IcyCache _cache;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  FirebaseMessaging? _fm;
  String? _token;
  bool _warmed = false;

  /// Called for warm push taps (background/foreground). The router wires
  /// this to `WebViewController.loadRequest` so the URL loads without a
  /// full pipeline replay.
  void Function(String url)? onLiveDestination;

  /// Fired when the FCM token rotates. The router re-POSTs the gate body
  /// with the fresh token so the backend can target this device.
  void Function(String token)? onTokenSwap;

  String? get token => _token;

  Future<void> warm() async {
    if (_warmed) return;
    try {
      // main() initialises the default app; only initialise here if it
      // somehow did not, to avoid the [duplicate-app] throw that would
      // leave messaging silently un-initialised.
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _fm = FirebaseMessaging.instance;
      FirebaseMessaging.onBackgroundMessage(_backgroundReceiver);

      await _configureLocal();

      _token = await _fm!.getToken();
      _fm!.onTokenRefresh.listen((String t) {
        _token = t;
        onTokenSwap?.call(t);
      });

      FirebaseMessaging.onMessage.listen(_handleForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleWarmTap);

      final RemoteMessage? initial = await _fm!.getInitialMessage();
      if (initial != null) _handleColdTap(initial);

      _warmed = true;
    } catch (_) {
      // Firebase not wired yet — beacons stay dormant, the app still runs.
    }
  }

  Future<void> _configureLocal() async {
    const AndroidInitializationSettings android =
        AndroidInitializationSettings(_smallIconRef);
    const DarwinInitializationSettings ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _local.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (NotificationResponse r) {
        final String? raw = r.payload;
        if (raw == null || raw.isEmpty) return;
        try {
          final Map<String, dynamic> data =
              jsonDecode(raw) as Map<String, dynamic>;
          final String? url = data['url'] as String?;
          if (url != null && url.isNotEmpty) {
            onLiveDestination?.call(_toHttps(url));
          }
        } catch (_) {}
      },
    );

    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? impl =
          _local.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await impl?.createNotificationChannel(
        const AndroidNotificationChannel(
          kBeaconChannelId,
          kBeaconChannelName,
          description: 'Updates and events from Frozen Catch',
          importance: Importance.high,
        ),
      );
    }
  }

  /// Requests the Android 13+ system permission dialog. Records an
  /// "OS-blocked" flag on denial so the invite screen never loops.
  Future<bool> requestPermission() async {
    if (_fm == null) return false;
    final NotificationSettings s = await _fm!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final bool granted = s.authorizationStatus == AuthorizationStatus.authorized ||
        s.authorizationStatus == AuthorizationStatus.provisional;

    await _cache.markBeaconAllowed(granted);
    if (s.authorizationStatus == AuthorizationStatus.denied) {
      await _cache.markBeaconOsBlocked();
    }
    return granted;
  }

  void _handleForeground(RemoteMessage message) async {
    final RemoteNotification? n = message.notification;
    if (n == null || !Platform.isAndroid) return;

    AndroidNotificationDetails? details;
    final String? imageUrl = n.android?.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      final Uint8List? bytes = await _grabImageBytes(imageUrl);
      if (bytes != null) {
        details = AndroidNotificationDetails(
          kBeaconChannelId,
          kBeaconChannelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: _smallIconRef,
          styleInformation: BigPictureStyleInformation(
            ByteArrayAndroidBitmap(bytes),
            largeIcon:
                const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          ),
        );
      }
    }

    details ??= const AndroidNotificationDetails(
      kBeaconChannelId,
      kBeaconChannelName,
      importance: Importance.high,
      priority: Priority.high,
      icon: _smallIconRef,
    );

    await _local.show(
      n.hashCode,
      n.title,
      n.body,
      NotificationDetails(android: details),
      payload:
          message.data.isNotEmpty ? jsonEncode(message.data) : null,
    );
  }

  void _handleColdTap(RemoteMessage message) {
    final String? url = message.data['url'] as String?;
    if (url != null && url.isNotEmpty) {
      _cache.stashDeferredDestination(_toHttps(url));
    }
  }

  void _handleWarmTap(RemoteMessage message) {
    final String? url = message.data['url'] as String?;
    if (url != null && url.isNotEmpty) {
      onLiveDestination?.call(_toHttps(url));
    }
  }

  /// Push servers sometimes issue http:// URLs even though our policy is
  /// HTTPS-only. Silently upgrade the scheme so Android's network security
  /// config does not block the request with ERR_CLEARTEXT_NOT_PERMITTED.
  static String _toHttps(String url) {
    return url.startsWith('http://') ? 'https://${url.substring(7)}' : url;
  }

  Future<Uint8List?> _grabImageBytes(String url) async {
    try {
      final res = await frostHttp
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) return res.bodyBytes;
    } catch (_) {}
    return null;
  }
}
