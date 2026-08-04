// SPDX-License-Identifier: 0BSD
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../notifications/notification_service.dart';
import '../trace/trace_logger.dart';
import 'push_connector.dart';
import 'push_endpoint_repository.dart';

/// Where the push pipeline stands (#424): surfaced in Settings so a
/// silent field setup (no distributor installed) stops being invisible.
enum PushStatus {
  /// Platform without UnifiedPush support (iOS, desktop, web).
  unsupported,

  /// Supported, but no distributor app (ntfy, NextPush…) is installed —
  /// the app cannot receive pushes until the user installs one.
  noDistributor,

  /// Registered with a distributor; endpoint saved server-side.
  registered,
}

/// UnifiedPush pipeline (#72): distributor → endpoint rows on the server
/// → generic ping when someone must confirm a pending event. Payloads
/// carry no personal data; the client localizes the notification text.
class PushService {
  PushService({
    required PushConnector connector,
    required PushEndpointRepository repository,
    required NotificationService notifications,
    required Future<List<String>> Function() myMemberIds,
    required String pendingTitle,
    required String pendingBody,
    required String cancelledTitle,
    required String cancelledBody,
  })  : _connector = connector,
        _repository = repository,
        _notifications = notifications,
        _myMemberIds = myMemberIds,
        _pendingTitle = pendingTitle,
        _pendingBody = pendingBody,
        _cancelledTitle = cancelledTitle,
        _cancelledBody = cancelledBody;

  final PushConnector _connector;
  final PushEndpointRepository _repository;
  final NotificationService _notifications;
  final Future<List<String>> Function() _myMemberIds;
  final String _pendingTitle;
  final String _pendingBody;
  final String _cancelledTitle;
  final String _cancelledBody;

  /// Live pipeline state for the Settings status line (#424).
  final ValueNotifier<PushStatus> status =
      ValueNotifier(PushStatus.unsupported);

  String? _endpoint;

  /// Best-effort start: no distributor or no platform support simply
  /// means local notifications only.
  Future<void> start() async {
    final available = await _connector.initialize(
      onNewEndpoint: _onNewEndpoint,
      onUnregistered: _onUnregistered,
      onMessage: onMessage,
    );
    if (!available) return;
    if (!await _connector.hasDistributor()) {
      status.value = PushStatus.noDistributor;
      return;
    }
    await _connector.register();
  }

  Future<void> _onNewEndpoint(String url) async {
    _endpoint = url;
    status.value = PushStatus.registered;
    try {
      await _repository.saveEndpoint(
        memberIds: await _myMemberIds(),
        endpoint: url,
      );
    } catch (e, st) {
      debugPrint('push endpoint save failed: $e\n$st');
      TraceLogger.instance.error('push', 'push endpoint save failed',
          error: e, stackTrace: st);
    }
  }

  Future<void> _onUnregistered() async {
    final endpoint = _endpoint;
    _endpoint = null;
    status.value = PushStatus.noDistributor;
    if (endpoint == null) return;
    try {
      await _repository.removeEndpoint(endpoint);
    } catch (e, st) {
      debugPrint('push endpoint removal failed: $e\n$st');
      TraceLogger.instance.error('push', 'push endpoint removal failed',
          error: e, stackTrace: st);
    }
  }

  /// Decodes a push message and raises a local notification. Unknown or
  /// malformed payloads still ping generically — a lost notification is
  /// worse than a vague one.
  @visibleForTesting
  Future<void> onMessage(Uint8List content) async {
    var kind = 'pending_request';
    try {
      final decoded = jsonDecode(utf8.decode(content));
      if (decoded is Map<String, dynamic> && decoded['kind'] is String) {
        kind = decoded['kind'] as String;
      }
    } catch (e, st) {
      debugPrint('push payload undecodable, generic ping kept: $e\n$st');
      // Tolerated by design: the generic pending ping still fires below.
      TraceLogger.instance.warn(
          'push', 'push payload undecodable, generic ping kept',
          error: e, stackTrace: st);
    }
    switch (kind) {
      case 'reservation_cancelled':
        // #424: an admin removed a booking (overrule) — the displaced
        // member and the admins get this; text localized client-side.
        await _notifications.showNow(
            title: _cancelledTitle, body: _cancelledBody);
      default:
        // pending_request, unknown future kinds, malformed payloads:
        // the generic ping — a lost notification is worse than a vague
        // one.
        await _notifications.showNow(
            title: _pendingTitle, body: _pendingBody);
    }
  }
}
