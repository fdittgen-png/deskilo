// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Push registration follows the transport's availability, and each message
// kind raises its own localized notification.
import 'dart:convert';
import 'dart:typed_data';

import 'package:deskilo/core/notifications/notification_taps.dart';
import 'package:deskilo/core/push/push_connector.dart';
import 'package:deskilo/core/push/push_endpoint_repository.dart';
import 'package:deskilo/core/push/push_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_notification_service.dart';

class FakePushConnector implements PushConnector {
  FakePushConnector({this.available = true, this.allowed = true});

  final bool available;

  /// Whether the system allows notifications; [register] with `ask`
  /// flips it to [allowOnAsk] (the person's answer to the prompt).
  bool allowed;
  bool allowOnAsk = true;
  bool registered = false;
  final asks = <bool>[];
  void Function(String url)? newEndpoint;
  void Function()? unregistered;
  void Function(Uint8List content)? message;
  void Function(Map<String, String> data, String? messageId)? opened;

  @override
  Future<bool> initialize({
    required void Function(String url) onNewEndpoint,
    required void Function() onUnregistered,
    required void Function(Uint8List content) onMessage,
    void Function(Map<String, String> data, String? messageId)? onOpened,
  }) async {
    newEndpoint = onNewEndpoint;
    unregistered = onUnregistered;
    message = onMessage;
    opened = onOpened;
    return available;
  }

  @override
  Future<bool> register({bool ask = false}) async {
    asks.add(ask);
    if (ask) allowed = allowOnAsk;
    if (allowed) registered = true;
    return allowed;
  }
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
  bool allowed = true,
  NotificationTaps? taps,
}) {
  final connector = FakePushConnector(available: available, allowed: allowed);
  final repository = FakePushEndpointRepository();
  final notifications = FakeNotificationService();
  final service = PushService(
    connector: connector,
    repository: repository,
    notifications: notifications,
    myMemberIds: () async => ['member-1', 'member-9'],
    texts: PushTexts(
      title: 'DesKilo',
      bodyOf: (kind) => switch (kind) {
        'pending_request' => 'Someone needs your confirmation.',
        'reservation_cancelled' => 'A reservation was removed by an admin.',
        'member_note' => 'You have a new message.',
        _ => 'You have an update.',
      },
    ),
    taps: taps,
  );
  return (service, connector, repository, notifications);
}

void main() {
  test('start registers when the transport is available', () async {
    final (service, connector, _, _) = harness();
    await service.start();
    expect(connector.registered, isTrue);
  });

  test('unavailable transport (unconfigured Firebase) → nothing happens',
      () async {
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

  test('a reservation_cancelled message raises its own text (#424)',
      () async {
    final (service, _, _, notifications) = harness();
    await service.onMessage(
      Uint8List.fromList(utf8.encode('{"kind":"reservation_cancelled"}')),
    );

    final shown = notifications.shown.single;
    // #2559 C2 — the title is the app's name for every kind.
    expect(shown.title, 'DesKilo');
    expect(shown.body, 'A reservation was removed by an admin.');
  });

  test('unknown kinds ping generically — a NEWER server must still '
      'reach an older client (#424, was: dropped silently)', () async {
    final (service, _, _, notifications) = harness();
    await service.onMessage(
      Uint8List.fromList(utf8.encode('{"kind":"marketing"}')),
    );

    expect(notifications.shown.single.title, 'DesKilo');
  });

  test('status walks notConfigured → registered → notConfigured '
      '(#424/#428)', () async {
    final (none, _, _, _) = harness(available: false);
    await none.start();
    expect(none.status.value, PushStatus.notConfigured);

    final (full, connector, _, _) = harness();
    await full.start();
    connector.newEndpoint!('fcm:token-1');
    await Future<void>.delayed(Duration.zero);
    expect(full.status.value, PushStatus.registered);

    connector.unregistered!();
    await Future<void>.delayed(Duration.zero);
    expect(full.status.value, PushStatus.notConfigured);
  });

  group('#2559 C2', () {
    const reference = {
      'v': '1',
      'kind': 'member_note',
      'src': 'w',
      'inst': 'inst-a',
      'ws': 'ws-1',
      'ref_kind': 'note',
      'ref_id': 'note-1',
    };

    test('a foreground push shows generic text; its tap payload is the '
        'validated reference and nothing else of the payload', () async {
      final (service, _, _, notifications) = harness();
      await service.onMessage(Uint8List.fromList(utf8.encode(jsonEncode({
        ...reference,
        // A payload that carried private values (an older or a hostile
        // sender): none of them is shown or kept.
        'title': 'Alice Sentinel',
        'body': 'SENTINEL-MESSAGE-BODY',
        'amount': 'SENTINEL-AMOUNT-4242',
        'token': 'SENTINEL-TOKEN',
      }))));

      final shown = notifications.shown.single;
      expect(shown, (title: 'DesKilo', body: 'You have a new message.'));
      final payload = notifications.payloads.single!;
      expect(jsonDecode(payload), reference);
      for (final sentinel in ['Alice', 'SENTINEL']) {
        expect('${shown.title} ${shown.body} $payload',
            isNot(contains(sentinel)));
      }
    });

    test('an incomplete reference rings without a tap payload', () async {
      final (service, _, _, notifications) = harness();
      await service.onMessage(Uint8List.fromList(
          utf8.encode(jsonEncode({...reference}..remove('inst')))));
      expect(notifications.shown, hasLength(1));
      expect(notifications.payloads.single, isNull);
    });

    test('a start never prompts: not allowed is a status, nothing is '
        'registered', () async {
      final (service, connector, _, notifications) = harness(allowed: false);
      await service.start();
      expect(connector.asks, [false]);
      expect(connector.registered, isFalse);
      expect(notifications.permissionRequests, 0);
      expect(service.status.value, PushStatus.permissionNeeded);
    });

    test('the deliberate Allow prompts and registers; a denial changes '
        'nothing else and can be retried', () async {
      final (service, connector, _, notifications) = harness(allowed: false);
      await service.start();

      connector.allowOnAsk = false;
      expect(await service.allow(), isFalse);
      expect(service.status.value, PushStatus.permissionNeeded);
      expect(connector.registered, isFalse);

      connector.allowOnAsk = true;
      expect(await service.allow(), isTrue);
      expect(connector.asks, [false, true, true]);
      expect(connector.registered, isTrue);
      expect(notifications.permissionRequests, 2);
    });

    test('a tapped push goes to the tap inbox once, data only', () async {
      final taps = NotificationTaps();
      final (service, connector, _, _) = harness(taps: taps);
      await service.start();
      final received = <NotificationTap>[];
      taps.listen(received.add);

      connector.opened!(reference, 'msg-1');
      connector.opened!(reference, 'msg-1'); // the same delivery again
      expect(received, hasLength(1));
      expect(received.single.data, reference);
    });
  });
}
