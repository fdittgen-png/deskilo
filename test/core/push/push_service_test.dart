// SPDX-License-Identifier: MIT
import 'dart:convert';
import 'dart:typed_data';

import 'package:deskilo/core/push/push_connector.dart';
import 'package:deskilo/core/push/push_endpoint_repository.dart';
import 'package:deskilo/core/push/push_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_notification_service.dart';

class FakePushConnector implements PushConnector {
  FakePushConnector({this.available = true, this.distributor = true});

  final bool available;
  final bool distributor;
  bool registered = false;
  void Function(String url)? newEndpoint;
  void Function()? unregistered;
  void Function(Uint8List content)? message;

  @override
  Future<bool> initialize({
    required void Function(String url) onNewEndpoint,
    required void Function() onUnregistered,
    required void Function(Uint8List content) onMessage,
  }) async {
    newEndpoint = onNewEndpoint;
    unregistered = onUnregistered;
    message = onMessage;
    return available;
  }

  @override
  Future<bool> hasDistributor() async => distributor;

  @override
  Future<void> register() async => registered = true;
}

class FakePushEndpointRepository implements PushEndpointRepository {
  final saved = <({List<String> memberIds, String endpoint})>[];
  final removed = <String>[];

  @override
  Future<void> saveEndpoint({
    required List<String> memberIds,
    required String endpoint,
  }) async {
    saved.add((memberIds: memberIds, endpoint: endpoint));
  }

  @override
  Future<void> removeEndpoint(String endpoint) async {
    removed.add(endpoint);
  }
}

(PushService, FakePushConnector, FakePushEndpointRepository,
    FakeNotificationService) harness({
  bool available = true,
  bool distributor = true,
}) {
  final connector =
      FakePushConnector(available: available, distributor: distributor);
  final repository = FakePushEndpointRepository();
  final notifications = FakeNotificationService();
  final service = PushService(
    connector: connector,
    repository: repository,
    notifications: notifications,
    myMemberIds: () async => ['member-1', 'member-9'],
    pendingTitle: 'DesKilo',
    pendingBody: 'Someone needs your confirmation.',
  );
  return (service, connector, repository, notifications);
}

void main() {
  test('start registers when a distributor exists', () async {
    final (service, connector, _, _) = harness();
    await service.start();
    expect(connector.registered, isTrue);
  });

  test('no distributor → no registration, no crash', () async {
    final (service, connector, _, _) = harness(distributor: false);
    await service.start();
    expect(connector.registered, isFalse);
  });

  test('unsupported platform → nothing happens', () async {
    final (service, connector, _, _) = harness(available: false);
    await service.start();
    expect(connector.registered, isFalse);
  });

  test('a new endpoint is saved for every membership', () async {
    final (service, connector, repository, _) = harness();
    await service.start();

    connector.newEndpoint!('https://push.example.org/abc');
    await Future<void>.delayed(Duration.zero);

    final call = repository.saved.single;
    expect(call.memberIds, ['member-1', 'member-9']);
    expect(call.endpoint, 'https://push.example.org/abc');
  });

  test('unregistering removes the endpoint server-side', () async {
    final (service, connector, repository, _) = harness();
    await service.start();
    connector.newEndpoint!('https://push.example.org/abc');
    await Future<void>.delayed(Duration.zero);

    connector.unregistered!();
    await Future<void>.delayed(Duration.zero);

    expect(repository.removed, ['https://push.example.org/abc']);
  });

  test('a pending_request message raises the localized notification',
      () async {
    final (service, _, _, notifications) = harness();
    await service.onMessage(
      Uint8List.fromList(utf8.encode('{"kind":"pending_request"}')),
    );

    final shown = notifications.shown.single;
    expect(shown.title, 'DesKilo');
    expect(shown.body, 'Someone needs your confirmation.');
  });

  test('malformed payloads still ping generically', () async {
    final (service, _, _, notifications) = harness();
    await service.onMessage(Uint8List.fromList([0xff, 0x00, 0x01]));

    expect(notifications.shown, hasLength(1));
  });

  test('unknown kinds are dropped silently', () async {
    final (service, _, _, notifications) = harness();
    await service.onMessage(
      Uint8List.fromList(utf8.encode('{"kind":"marketing"}')),
    );

    expect(notifications.shown, isEmpty);
  });
}
