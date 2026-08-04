// SPDX-License-Identifier: 0BSD
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../trace/trace_logger.dart';
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
      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        onNewEndpoint('fcm:\$token');
      });
      return true;
    } catch (e, st) {
      // Best-effort (#86 boot doctrine): a broken Firebase setup must
      // never disturb the app.
      debugPrint('Firebase init failed: \$e\n\$st');
      TraceLogger.instance
          .warn('push', 'Firebase init failed', error: e, stackTrace: st);
      return false;
    }
  }

  @override
  Future<void> register() async {
    final messaging = FirebaseMessaging.instance;
    // iOS/macOS/web ask the user; Android 13+ raises the system prompt
    // through the notifications plugin already in place.
    await messaging.requestPermission();
    final token = await messaging.getToken();
    if (token != null) _onNewEndpoint?.call('fcm:\$token');
  }
}
