// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../notifications/notification_service.dart';
import '../notifications/notification_taps.dart';
import '../trace/trace_logger.dart';
import 'notification_reference.dart';
import 'push_connector.dart';
import 'push_endpoint_repository.dart';

/// Where the push pipeline stands (#424): surfaced in Settings so a
/// dead setup stops being invisible.
enum PushStatus {
  /// Firebase is unconfigured (the committed stub) or the platform has
  /// no push support — the owner completes docs/guides/push-setup.md.
  notConfigured,

  /// FCM registered; endpoint saved server-side.
  registered,

  /// #2559 C2 — the transport works but this device does not allow
  /// notifications (never asked, or denied). Settings offers the
  /// deliberate "Allow" action; everything stays available in the app.
  permissionNeeded,
}

/// #2559 C2 — the visible text of a notification: the app's name and a
/// generic line per kind, in the device's language. Never a name, an
/// amount or a message's words.
class PushTexts {
  const PushTexts({required this.title, required this.bodyOf});

  final String title;
  final String Function(String kind) bodyOf;
}

/// Push pipeline (#72, FCM-only since #428): endpoint rows on the server
/// → generic ping when someone must confirm a pending event. Payloads
/// carry no personal data; the client localizes the notification text.
/// #2559 C2 — a payload's qualified reference rides on the local
/// notification as its tap payload, and a tapped push goes to [_taps].
class PushService {
  PushService({
    required this._connector,
    required this._repository,
    required this._notifications,
    required this._myMemberIds,
    required this._texts,
    this._taps,
  });

  final PushConnector _connector;
  final PushEndpointRepository _repository;
  final NotificationService _notifications;
  final Future<List<String>> Function() _myMemberIds;
  final PushTexts _texts;
  final NotificationTaps? _taps;
  bool _available = false;

  /// Live pipeline state for the Settings status line (#424).
  final ValueNotifier<PushStatus> status =
      ValueNotifier(PushStatus.notConfigured);

  String? _endpoint;

  /// Best-effort start: no distributor or no platform support simply
  /// means local notifications only.
  Future<void> start() async {
    final available = await _connector.initialize(
      onNewEndpoint: _onNewEndpoint,
      onUnregistered: _onUnregistered,
      onMessage: onMessage,
      onOpened: onOpened,
    );
    if (!available) return; // notConfigured stays — Settings names it
    _available = true;
    // #2559 C2 — a start never prompts: not allowed yet is a status.
    if (!await _connector.register()) {
      status.value = PushStatus.permissionNeeded;
    }
  }

  /// #2559 C2 — the person deliberately asked for notifications: the
  /// system prompt appears now, and an allowed device registers. A denial
  /// leaves the status (and the app) as it was; the action can be retried.
  Future<bool> allow() async {
    await _notifications.requestPermission();
    if (!_available) return false;
    final allowed = await _connector.register(ask: true);
    if (!allowed) status.value = PushStatus.permissionNeeded;
    return allowed;
  }

  /// A tapped push: its data goes to the tap inbox, which resolves it
  /// against the signed-in account before anything opens.
  @visibleForTesting
  void onOpened(Map<String, String> data, String? messageId) {
    _taps?.add(NotificationTap(
      id: 'push:${messageId ?? jsonEncode(data)}',
      data: data,
    ));
  }

  Future<void> _onNewEndpoint(String url) async {
    _endpoint = url;
    status.value = PushStatus.registered;
    try {
      await _repository.saveEndpoint(
        memberIds: await _myMemberIds(),
        endpoint: url,
      );
    } on Object catch (e, st) {
      debugPrint('push endpoint save failed: $e\n$st');
      TraceLogger.instance.error('push', 'push endpoint save failed',
          error: e, stackTrace: st);
    }
  }

  /// #1914 — the person turned push off on this device: the server
  /// forgets this device's endpoint, so nothing more is sent to it.
  Future<void> optOut() => _onUnregistered();

  Future<void> _onUnregistered() async {
    final endpoint = _endpoint;
    _endpoint = null;
    status.value = PushStatus.notConfigured;
    if (endpoint == null) return;
    try {
      await _repository.removeEndpoint(endpoint);
    } on Object catch (e, st) {
      debugPrint('push endpoint removal failed: $e\n$st');
      TraceLogger.instance.error('push', 'push endpoint removal failed',
          error: e, stackTrace: st);
    }
  }

  /// Decodes a push message and raises a local notification. Unknown or
  /// malformed payloads still ping generically — a lost notification is
  /// worse than a vague one. #2559 C2 — the text is generic per kind and
  /// the validated reference (nothing else of the payload) is the tap
  /// payload.
  @visibleForTesting
  Future<void> onMessage(Uint8List content) async {
    var kind = 'pending_request';
    NotificationReference? reference;
    try {
      final decoded = jsonDecode(utf8.decode(content));
      if (decoded is Map<String, dynamic>) {
        if (decoded['kind'] is String) kind = decoded['kind'] as String;
        reference = NotificationReference.parse(decoded);
      }
    } on Object catch (e, st) {
      debugPrint('push payload undecodable, generic ping kept: $e\n$st');
      // Tolerated by design: the generic ping still fires below.
      TraceLogger.instance.warn(
          'push', 'push payload undecodable, generic ping kept',
          error: e, stackTrace: st);
    }
    await _notifications.showNow(
      title: _texts.title,
      body: _texts.bodyOf(kind),
      payload: reference == null ? null : jsonEncode(reference.toData()),
    );
  }
}
