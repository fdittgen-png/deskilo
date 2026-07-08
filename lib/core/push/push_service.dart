// SPDX-License-Identifier: MIT
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../notifications/notification_service.dart';
import 'push_connector.dart';
import 'push_endpoint_repository.dart';

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
  })  : _connector = connector,
        _repository = repository,
        _notifications = notifications,
        _myMemberIds = myMemberIds,
        _pendingTitle = pendingTitle,
        _pendingBody = pendingBody;

  final PushConnector _connector;
  final PushEndpointRepository _repository;
  final NotificationService _notifications;
  final Future<List<String>> Function() _myMemberIds;
  final String _pendingTitle;
  final String _pendingBody;

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
    if (!await _connector.hasDistributor()) return;
    await _connector.register();
  }

  Future<void> _onNewEndpoint(String url) async {
    _endpoint = url;
    try {
      await _repository.saveEndpoint(
        memberIds: await _myMemberIds(),
        endpoint: url,
      );
    } catch (e, st) {
      debugPrint('push endpoint save failed: $e\n$st');
    }
  }

  Future<void> _onUnregistered() async {
    final endpoint = _endpoint;
    _endpoint = null;
    if (endpoint == null) return;
    try {
      await _repository.removeEndpoint(endpoint);
    } catch (e, st) {
      debugPrint('push endpoint removal failed: $e\n$st');
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
    }
    if (kind != 'pending_request') return;
    await _notifications.showNow(title: _pendingTitle, body: _pendingBody);
  }
}
