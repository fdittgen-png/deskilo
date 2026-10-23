// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2559 C2 — the notifications the person tapped, from both doors: a push
// the system displayed (the transport's opened callback) and a local
// notification the app displayed (its payload). A tap that launched the
// app arrives before anything listens, so taps wait here until the app's
// router takes them; each tap is handed on once.
import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../trace/trace_logger.dart';

part 'notification_taps.g.dart';

/// One tapped notification: its opaque data, never its text. [id] tells
/// two deliveries of the same tap apart from two taps.
class NotificationTap {
  const NotificationTap({required this.id, required this.data});

  final String id;
  final Map<String, String> data;

  /// A local notification's payload: the reference's JSON object, or null
  /// when there is none (a reminder) or it is not a flat string map.
  static Map<String, String>? decodePayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, Object?>) return null;
      return {
        for (final e in decoded.entries)
          if (e.value is String) e.key: e.value as String,
      };
    } on FormatException catch (e, st) {
      TraceLogger.instance.warn('notifications', 'tap payload undecodable',
          error: e, stackTrace: st);
      return null;
    }
  }
}

/// The inbox of taps. Taps before the first listener are kept (bounded);
/// a tap id already handed on is dropped, so a resume or a second delivery
/// of the launch tap never opens the record twice.
class NotificationTaps {
  static const _maxWaiting = 8;
  static const _maxRemembered = 64;

  final _waiting = <NotificationTap>[];
  final _seen = <String>[];
  void Function(NotificationTap tap)? _listener;

  void add(NotificationTap tap) {
    if (_seen.contains(tap.id)) return;
    _seen.add(tap.id);
    if (_seen.length > _maxRemembered) _seen.removeAt(0);
    final listener = _listener;
    if (listener != null) return listener(tap);
    _waiting.add(tap);
    if (_waiting.length > _maxWaiting) _waiting.removeAt(0);
  }

  /// Takes every tap from now on, after the ones that waited.
  void listen(void Function(NotificationTap tap) onTap) {
    _listener = onTap;
    final waiting = List.of(_waiting);
    _waiting.clear();
    waiting.forEach(onTap);
  }

  void cancel() => _listener = null;
}

/// The app's one inbox. main() hands the same instance to the local
/// notification service before the app starts.
@Riverpod(keepAlive: true)
NotificationTaps notificationTaps(Ref ref) => NotificationTaps();
