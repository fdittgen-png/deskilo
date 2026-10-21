// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2504 — the page offers its read tools only while signed in, in a
// workspace with the webMcp feature, with the device switch on; each read
// answers from the app's own providers with only the fields the contract's
// `output` lists, and "my" lists hold the person's own rows even when the
// person administers the workspace.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/app/webmcp_wiring.dart';
import 'package:deskilo/core/demo/data/reservation_repository.dart';
import 'package:deskilo/core/webmcp/webmcp_device_switch.dart';
import 'package:deskilo/core/webmcp/webmcp_registry.dart';
import 'package:deskilo/core/webmcp/webmcp_tools.g.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/events/providers/event_providers.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/providers/reservation_providers.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Registration implements WebMcpRegistration {
  _Registration(this.onUnregister);
  final void Function() onUnregister;
  @override
  void unregister() => onUnregister();
}

class _Context implements WebMcpContext {
  final Map<String, WebMcpExecute> live = {};
  @override
  bool get available => true;
  @override
  WebMcpRegistration register({
    required String name,
    required String description,
    required String inputSchemaJson,
    required Map<String, Object?> annotations,
    required WebMcpExecute execute,
  }) {
    live[name] = execute;
    return _Registration(() => live.remove(name));
  }
}

class _Switch implements WebMcpSwitchStore {
  _Switch({required this.on});
  bool on;
  @override
  Future<bool> read() async => on;
  @override
  Future<void> write({required bool on}) async => this.on = on;
}

const _ws = Workspace(
  id: 'ws-1',
  name: 'Atelier',
  countryCode: 'FR',
  currencyCode: 'EUR',
  timezone: 'Europe/Paris',
  inviteCode: 'x',
);

const _me = Member(
  id: 'member-1',
  workspaceId: 'ws-1',
  userId: 'user-1',
  isAdmin: true,
  isOwner: false,
  status: MemberStatus.active,
);

Invoice _invoice(String id, String memberId, DateTime issuedAt) => Invoice(
  id: id,
  workspaceId: 'ws-1',
  memberId: memberId,
  number: 'F-$id',
  issuedAt: issuedAt,
  period: '2026-09',
  title: 'September',
  lines: const [],
  totalCents: 4500,
  currency: 'EUR',
  memberName: 'Name of $memberId',
  memberAddress: 'Street',
  workspaceName: 'Atelier',
  workspaceAddress: 'Street',
  issuerName: 'Owner',
  signature: 's',
);

Reservation _booking(String id, String memberId, DateTime start) => Reservation(
  id: id,
  workspaceId: 'ws-1',
  memberId: memberId,
  seatId: 'seat-$id',
  startsAt: start,
  endsAt: start.add(const Duration(hours: 4)),
  status: ReservationStatus.reserved,
);

/// The contract's `output` list per operation.
Map<String, Set<String>> _outputs() {
  final contract = jsonDecode(
    File('contracts/mcp/operations.json').readAsStringSync(),
  ) as Map;
  final ops = contract['operations'] is List
      ? contract['operations'] as List
      : (contract['operations'] as Map).values.toList();
  return {
    for (final op in ops.cast<Map<Object?, Object?>>())
      op['id']! as String: {...(op['output']! as List).cast<String>()},
  };
}

/// Every key at any depth of [value].
Set<String> _keys(Object? value) => switch (value) {
  final Map<Object?, Object?> m => {
    for (final e in m.entries) ...{e.key! as String, ..._keys(e.value)},
  },
  final List<Object?> l => {for (final v in l) ..._keys(v)},
  _ => const {},
};

void main() {
  late _Context context;
  late _Switch deviceSwitch;
  late FakeReservationRepository reservations;
  late Set<WorkspaceFeature> features;

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        webMcpContextProvider.overrideWithValue(context),
        webMcpSwitchStoreProvider.overrideWithValue(deviceSwitch),
        currentAccountIdProvider.overrideWithValue('user-1'),
        currentWorkspaceProvider.overrideWith((ref) async => _ws),
        enabledFeaturesSyncProvider.overrideWith((ref) => features),
        myMemberProvider.overrideWith((ref) async => _me),
        reservationRepositoryProvider.overrideWithValue(reservations),
        invoicesProvider.overrideWith(
          (ref) async => [
            _invoice('i1', 'member-1', DateTime.utc(2026, 9, 30)),
            _invoice('i2', 'member-2', DateTime.utc(2026, 9, 30)),
            _invoice('i3', 'member-1', DateTime.utc(2026, 8, 31)),
          ],
        ),
        myPendingEventsProvider.overrideWith(
          (ref) async => [
            WorkspaceEvent(
              id: 'e1',
              workspaceId: 'ws-1',
              type: EventType.reservation,
              action: EventAction.created,
              actorMemberId: 'member-2',
              subjectMemberId: 'member-2',
              payload: const {'note': 'free text the agent must not get'},
              status: EventStatus.pending,
              createdAt: DateTime.utc(2026, 10),
            ),
          ],
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    context = _Context();
    deviceSwitch = _Switch(on: true);
    reservations = FakeReservationRepository()
      ..reservations.addAll([
        _booking('r1', 'member-1', DateTime.utc(2026, 10, 6, 7)),
        _booking('r2', 'member-2', DateTime.utc(2026, 10, 6, 7)),
        _booking('r3', 'member-1', DateTime.utc(2026, 10, 7, 7)),
      ]);
    features = {
      WorkspaceFeature.mcpAccess,
      WorkspaceFeature.webMcp,
      WorkspaceFeature.invoicing,
      WorkspaceFeature.moneyTab,
    };
  });

  Future<ProviderContainer> armed() async {
    final c = container()..listen(webMcpRegistryProvider, (_, _) {});
    await c.read(currentWorkspaceProvider.future);
    await c.read(webMcpDeviceSwitchProvider.future);
    await pumpEventQueue();
    return c;
  }

  Future<Map<String, Object?>> call(
    String tool,
    Map<String, Object?> input,
  ) async => (await context.live[tool]!(input))! as Map<String, Object?>;

  test(
    'all conditions hold: the four answered reads are offered, nothing else',
    () async {
      await armed();
      expect(context.live.keys.toSet(), {
        'deskilo_list_workspaces',
        'deskilo_list_my_reservations',
        'deskilo_list_my_invoices',
        'deskilo_list_pending_validations',
      });
    },
  );

  test(
    'the device switch off, or the feature off: nothing is offered',
    () async {
      deviceSwitch.on = false;
      await armed();
      expect(context.live, isEmpty);

      deviceSwitch.on = true;
      features = {WorkspaceFeature.mcpAccess, WorkspaceFeature.invoicing};
      context = _Context();
      await armed();
      expect(context.live, isEmpty);
    },
  );

  test('turning the switch off withdraws every tool', () async {
    final c = await armed();
    expect(context.live, isNotEmpty);
    await c.read(webMcpDeviceSwitchProvider.notifier).set(on: false);
    await pumpEventQueue();
    expect(context.live, isEmpty);
  });

  test('every read answers only fields of the contract output list', () async {
    await armed();
    final outputs = _outputs();
    final answers = {
      'list_workspaces': await call('deskilo_list_workspaces', {}),
      'list_my_reservations': await call('deskilo_list_my_reservations', {
        'workspace_id': 'ws-1',
        'from': '2026-10-01T00:00:00+02:00',
        'to': '2026-10-31T00:00:00+01:00',
      }),
      'list_my_invoices': await call('deskilo_list_my_invoices', {
        'workspace_id': 'ws-1',
      }),
      'list_pending_validations': await call(
        'deskilo_list_pending_validations',
        {'workspace_id': 'ws-1'},
      ),
    };
    for (final MapEntry(key: id, value: answer) in answers.entries) {
      expect(answer['ok'], isTrue, reason: '$id: $answer');
      final output = answer['output']! as Map<String, Object?>;
      // list_workspaces wraps its rows as the facade does.
      final keys = _keys(
        id == 'list_workspaces' ? output['workspaces'] : output,
      );
      expect(keys.difference(outputs[id]!), isEmpty, reason: id);
    }
    expect(
      jsonEncode(answers['list_pending_validations']),
      isNot(contains('free text')),
    );
  });

  test(
    '"my" lists hold the person\'s own rows, even for an administrator',
    () async {
      await armed();
      final bookings = await call('deskilo_list_my_reservations', {
        'workspace_id': 'ws-1',
        'from': '2026-10-01T00:00:00+02:00',
        'to': '2026-10-31T00:00:00+01:00',
      });
      final invoices = await call('deskilo_list_my_invoices', {
        'workspace_id': 'ws-1',
      });
      List<Object?> ids(Map<String, Object?> a, String key) => [
        for (final item in (a['output']! as Map)['items'] as List)
          (item as Map)[key],
      ];
      expect(ids(bookings, 'reservation_id'), ['r1', 'r3']);
      expect(ids(invoices, 'invoice_id'), ['i1', 'i3']);
    },
  );

  test(
    'a page and its cursor; a cursor the page did not hand out is refused',
    () async {
      await armed();
      final first = await call('deskilo_list_my_invoices', {
        'workspace_id': 'ws-1',
        'limit': 1,
      });
      final out = first['output']! as Map;
      expect((out['items'] as List).single, containsPair('invoice_id', 'i1'));
      final second = await call('deskilo_list_my_invoices', {
        'workspace_id': 'ws-1',
        'limit': 1,
        'cursor': out['next_cursor'],
      });
      final out2 = second['output']! as Map;
      expect((out2['items'] as List).single, containsPair('invoice_id', 'i3'));
      expect(out2['next_cursor'], isNull);

      final forged = await call('deskilo_list_my_invoices', {
        'workspace_id': 'ws-1',
        'cursor': 'x',
      });
      expect(forged['ok'], isFalse);
    },
  );

  test('a window longer than 31 days is refused', () async {
    await armed();
    final answer = await call('deskilo_list_my_reservations', {
      'workspace_id': 'ws-1',
      'from': '2026-10-01T00:00:00+02:00',
      'to': '2026-12-01T00:00:00+01:00',
    });
    expect(answer['ok'], isFalse);
  });

  test('only tools with a runner are generated into the page', () {
    expect({
      for (final t in webMcpTools)
        if (webMcpReadRunners.containsKey(t.id)) t.id,
    }, webMcpReadRunners.keys.toSet());
  });
}
