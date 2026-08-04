// SPDX-License-Identifier: 0BSD
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../trace/trace_logger.dart';
import 'firebase_options.dart';
import 'push_connector.dart';

/// FCM transport (#426, primary since F-Droid was dropped): Android,
/// iOS (APNs underneath), web and macOS, no distributor app needed.
///
/// Endpoints are saved as `fcm:<token>` rows — the 0083 sender routes
/// them through the send-push edge function (FCM v1 needs OAuth, which
/// pg_net cannot do). Foreground messages come through [onMessage] and
/// the app shows the LOCALIZED notification; in background/killed the
/// OS displays the function's generic English text (never personal
/// data, 0012 doctrine) — the trade-off is documented in push-setup.
class FirebasePushConnector implements PushConnector {
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
      FirebaseMessaging.onMessage.listen((message) {
        onMessage(Uint8List.fromList(utf8.encode(jsonEncode(message.data))));
      });
      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        onNewEndpoint('fcm:$token');
      });
      return true;
    } catch (e, st) {
      // Best-effort (#86 boot doctrine): a broken Firebase setup must
      // never disturb the app — the caller falls back to UnifiedPush.
      debugPrint('Firebase init failed: $e\n$st');
      TraceLogger.instance
          .warn('push', 'Firebase init failed', error: e, stackTrace: st);
      return false;
    }
  }

  @override
  Future<bool> hasDistributor() async => true; // FCM needs none

  @override
  Future<void> register() async {
    final messaging = FirebaseMessaging.instance;
    // iOS/macOS/web ask the user; Android 13+ raises the system prompt
    // through the notifications plugin already in place.
    await messaging.requestPermission();
    final token = await messaging.getToken();
    if (token != null) _pendingEndpoint?.call('fcm:$token');
  }

  /// register() runs after initialize(), which captured the callback.
  void Function(String url)? _pendingEndpoint;
}

/// Tries each transport in order; the first whose [initialize] succeeds
/// owns the pipeline (#426): Firebase when configured, UnifiedPush
/// otherwise — the seam the rest of the app sees stays one connector.
class FallbackPushConnector implements PushConnector {
  FallbackPushConnector(this._candidates);

  final List<PushConnector> _candidates;
  PushConnector? _active;

  @override
  Future<bool> initialize({
    required void Function(String url) onNewEndpoint,
    required void Function() onUnregistered,
    required void Function(Uint8List content) onMessage,
  }) async {
    for (final candidate in _candidates) {
      if (await candidate.initialize(
        onNewEndpoint: onNewEndpoint,
        onUnregistered: onUnregistered,
        onMessage: onMessage,
      )) {
        if (candidate is FirebasePushConnector) {
          candidate._pendingEndpoint = onNewEndpoint;
        }
        _active = candidate;
        return true;
      }
    }
    return false;
  }

  @override
  Future<bool> hasDistributor() => _active?.hasDistributor() ?? Future.value(false);

  @override
  Future<void> register() => _active?.register() ?? Future.value();
}
