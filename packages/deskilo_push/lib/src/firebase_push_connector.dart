// SPDX-License-Identifier: 0BSD
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options.dart';
import 'push_connector.dart';

/// The FCM transport (#426, sole transport since #428 removed the
/// F-Droid-era UnifiedPush fallback): Android, iOS (APNs underneath),
/// web and macOS, nothing to install user-side.
///
/// Endpoints are saved as `fcm:<token>` rows — the 0084 sender routes
/// them through the send-push edge function (FCM v1 needs OAuth, which
/// pg_net cannot do). Foreground messages come through [onMessage] and
/// the app shows the LOCALIZED notification; in background/killed the
/// OS displays the function's generic English text (never personal
/// data, 0012 doctrine).
class FirebasePushConnector implements PushConnector {
  FirebasePushConnector({this.onWarn, this.tokenSource});

  final PushWarn? onWarn;

  /// Where the device token comes from. Null in the app — [register]
  /// then asks Firebase itself. A test injects one instead (#1558), so
  /// the registration path can be driven without a platform channel;
  /// nothing else about the connector is replaced.
  final Future<String?> Function()? tokenSource;

  void Function(String url)? _onNewEndpoint;

  @override
  Future<bool> initialize({
    required void Function(String url) onNewEndpoint,
    required void Function() onUnregistered,
    required void Function(Uint8List content) onMessage,
  }) async {
    final options = DeskiloFirebaseOptions.currentPlatformOrNull;
    if (options == null) return false; // stub in place — not configured
    try {
      await Firebase.initializeApp(options: options);
      _onNewEndpoint = onNewEndpoint;
      FirebaseMessaging.onMessage.listen((message) {
        onMessage(Uint8List.fromList(utf8.encode(jsonEncode(message.data))));
      });
      FirebaseMessaging.instance.onTokenRefresh.listen(publishToken);
      return true;
    } catch (e, st) {
      // Best-effort (#86 boot doctrine): a broken Firebase setup must
      // never disturb the app.
      debugPrint('Firebase init failed: $e\n$st');
      onWarn?.call('Firebase init failed', e, st);
      return false;
    }
  }

  @override
  Future<void> register() async {
    final token = await _readToken();
    if (token != null) publishToken(token);
  }

  Future<String?> _readToken() async {
    final injected = tokenSource;
    if (injected != null) return injected();
    final messaging = FirebaseMessaging.instance;
    // iOS/macOS/web ask the user; Android 13+ raises the system prompt
    // through the notifications plugin already in place.
    await messaging.requestPermission();
    return messaging.getToken();
  }

  /// The ONE place a token becomes an endpoint row — the first one and
  /// every refresh alike. The 0084 sender strips the `fcm:` prefix and
  /// hands the rest to FCM as the device token, so whatever this builds
  /// is what the device is addressed by.
  @visibleForTesting
  void publishToken(String token) => _onNewEndpoint?.call('fcm:$token');

  /// Wires the endpoint callback without touching Firebase, so a test
  /// can drive the real [register] and refresh paths (#1558). The app
  /// goes through [initialize], which wires the same field.
  @visibleForTesting
  void wireEndpointsForTest(void Function(String url) onNewEndpoint) =>
      _onNewEndpoint = onNewEndpoint;
}
