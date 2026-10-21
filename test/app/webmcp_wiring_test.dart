// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2504 — the page offers its read tools only while signed in, in a
// workspace with the webMcp feature, with the device switch on; each read
// answers from the app's own providers with only the fields the contract's
// `output` lists, and "my" lists hold the person's own rows even when the
// person administers the workspace.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/app/webmcp_confirmations.dart';
import 'package:deskilo/app/webmcp_reads.dart';
import 'package:deskilo/app/webmcp_wiring.dart';
import 'package:deskilo/core/demo/data/event_repository.dart';
import 'package:deskilo/core/demo/data/reservation_repository.dart';
import 'package:deskilo/core/webmcp/webmcp_device_switch.dart';
import 'package:deskilo/core/webmcp/webmcp_registry.dart';
import 'package:deskilo/core/webmcp/webmcp_tools.g.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/events/providers/event_providers.dart';
import 'package:deskilo/features/money/domain/command_receipt.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_action_commands.dart';
import 'package:deskilo/features/money/domain/invoice_commands.dart';
import 'package:deskilo/features/money/domain/invoice_queries.dart';
import 'package:deskilo/features/money/domain/member_account_queries.dart';
import 'package:deskilo/features/money/domain/statement.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/reservations/domain/place_feedback.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/providers/place_feedback_providers.dart';
import 'package:deskilo/features/reservations/providers/reservation_providers.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
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

class _Feedback implements PlaceFeedbackRepository {
  int favoriteWrites = 0;

  @override
  Future<PlaceFeedback> setFavorite(
    String workspaceId,
    PlaceKind kind,
    String id, {
    required bool on,
  }) async {
    favoriteWrites++;
    return PlaceFeedback(favorite: on, count: 1, average: 4);
  }

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Invoices implements InvoiceCommands {
  final voided = <String>[];

  final issued = <InvoiceIssueCommand>[];

  @override
  Future<void> voidInvoice(String invoiceId) async => voided.add(invoiceId);

  @override
  Future<String> issueInvoiceWithReceipt(InvoiceIssueCommand command) async {
    issued.add(command);
    return 'i9';
  }

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Unused implements InvoiceQueries, InvoiceActionCommands {
  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Switch implements WebMcpSwitchStore {
  _Switch({required this.on});
  bool on;
  @override
  Future<bool> read() async => on;
  @override
  Future<void> write({required bool on}) async => this.on = on;
}

const _september = Statement(
  period: '2026-09',
  subscriptionPct: 100,
  feeCents: 30000,
  includedHalfDays: 40,
  openDays: 22,
  usedHalfDays: 12,
  extraHalfDays: 0,
  overageCents: 0,
  creditsCents: 0,
  balanceCents: -30000,
);

class _Accounts implements MemberAccountQueries {
  @override
  Future<Statement> fetchStatement(String memberId, String period) async =>
      _september;

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

final _pending = WorkspaceEvent(
  id: 'e1',
  workspaceId: 'ws-1',
  type: EventType.reservation,
  action: EventAction.created,
  actorMemberId: 'member-2',
  subjectMemberId: 'member-2',
  payload: const {'note': 'free text the agent must not get'},
  status: EventStatus.pending,
  createdAt: DateTime.utc(2026, 10),
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
  late _Feedback feedback;
  late FakeEventRepository events;
  late _Invoices invoiceCommands;
  var permissions = <WorkspacePermission>{};

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
        myFavoritePlacesProvider.overrideWith(
          (ref) async => const [
            FavoritePlace(
              kind: PlaceKind.seat,
              id: 'seat-1',
              label: 'Window',
              feedback: PlaceFeedback(
                favorite: true,
                average: 4.5,
                count: 2,
                mine: 5,
              ),
            ),
          ],
        ),
        myStatementProvider('2026-09').overrideWith((ref) async => _september),
        myPendingEventsProvider.overrideWith((ref) async => [_pending]),
        myPermissionsProvider.overrideWith((ref) => permissions),
        memberAccountQueriesProvider.overrideWithValue(_Accounts()),
        placeFeedbackRepositoryProvider.overrideWithValue(feedback),
        eventRepositoryProvider.overrideWithValue(events),
        invoiceCommandsProvider.overrideWithValue(invoiceCommands),
        invoiceQueriesProvider.overrideWithValue(_Unused()),
        invoiceActionCommandsProvider.overrideWithValue(_Unused()),
        workspaceMembersProvider.overrideWith((ref) async => const [_me]),
        eventTrailProvider('e1')
            .overrideWith((ref) async => EventTrail(event: _pending)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    permissions = {
      WorkspacePermission.viewFinances,
      WorkspacePermission.issueInvoices,
    };
    feedback = _Feedback();
    events = FakeEventRepository()..events.add(_pending);
    invoiceCommands = _Invoices();
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
      WorkspaceFeature.placeFeedback,
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
    'all conditions hold: the answered reads are offered, nothing else',
    () async {
      await armed();
      expect(context.live.keys.toSet(), {
        'deskilo_list_workspaces',
        'deskilo_list_my_reservations',
        'deskilo_list_my_invoices',
        'deskilo_list_pending_validations',
        'deskilo_list_my_favorites',
        'deskilo_get_my_statement',
        'deskilo_get_validation',
        'deskilo_get_member_statement',
        'deskilo_get_capabilities',
        'deskilo_set_favorite',
        'deskilo_rate_place',
        'deskilo_check_in',
        'deskilo_check_out',
        'deskilo_cancel_reservation',
        'deskilo_create_reservation',
        'deskilo_request_reservation_deletion',
        'deskilo_respond_to_validation',
        'deskilo_request_invoice_void',
        'deskilo_request_refund',
        'deskilo_request_member_status_change',
        'deskilo_request_subscription_change',
        'deskilo_update_reservation',
        'deskilo_request_invoice_issue',
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
      'list_my_favorites': await call('deskilo_list_my_favorites', {
        'workspace_id': 'ws-1',
      }),
      'get_validation': await call('deskilo_get_validation', {
        'workspace_id': 'ws-1',
        'event_id': 'e1',
      }),
      'get_capabilities': await call('deskilo_get_capabilities', {
        'workspace_id': 'ws-1',
      }),
      'get_member_statement': await call('deskilo_get_member_statement', {
        'workspace_id': 'ws-1',
        'member_id': 'member-2',
        'period': '2026-09',
      }),
      'get_my_statement': await call('deskilo_get_my_statement', {
        'workspace_id': 'ws-1',
        'period': '2026-09',
      }),
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

  test("another member's statement needs viewFinances", () async {
    permissions = {};
    await armed();
    final answer = await call('deskilo_get_member_statement', {
      'workspace_id': 'ws-1',
      'member_id': 'member-2',
      'period': '2026-09',
    });
    expect(answer['ok'], isFalse);
  });

  test(
    'a write runs once per request_id; other arguments under it are refused',
    () async {
      final c = await armed();
      final first = await call('deskilo_set_favorite', {
        'request_id': 'req-1',
        'workspace_id': 'ws-1',
        'kind': 'seat',
        'resource_id': 'seat-1',
        'favorite': true,
      });
      expect(first['ok'], isTrue, reason: '$first');
      final again = await call('deskilo_set_favorite', {
        'request_id': 'req-1',
        'workspace_id': 'ws-1',
        'kind': 'seat',
        'resource_id': 'seat-1',
        'favorite': true,
      });
      expect(again['output'], first['output']);
      expect(feedback.favoriteWrites, 1);
      final changed = await call('deskilo_set_favorite', {
        'request_id': 'req-1',
        'workspace_id': 'ws-1',
        'kind': 'seat',
        'resource_id': 'seat-1',
        'favorite': false,
      });
      expect(changed['ok'], isFalse);
      final missing = await call('deskilo_set_favorite', {
        'workspace_id': 'ws-1',
        'kind': 'seat',
        'resource_id': 'seat-1',
        'favorite': true,
      });
      expect(missing['ok'], isFalse);
      expect(feedback.favoriteWrites, 1);
      expect(c.read(webMcpActivityProvider), 'set_favorite');
      final outputs = _outputs();
      expect(
        _keys(first['output']).difference(outputs['set_favorite']!),
        isEmpty,
      );
    },
  );

  test("a booking write acts on the person's own booking only, on its current state", () async {
    await armed();
    final mine = await call('deskilo_cancel_reservation', {
      'request_id': 'req-2',
      'workspace_id': 'ws-1',
      'reservation_id': 'r1',
    });
    expect(mine['ok'], isTrue, reason: '$mine');
    final view = mine['output']! as Map<String, Object?>;
    expect(view['status'], 'cancelled');
    expect(_keys(view).difference(_outputs()['cancel_reservation']!), isEmpty);

    final theirs = await call('deskilo_cancel_reservation', {
      'request_id': 'req-3',
      'workspace_id': 'ws-1',
      'reservation_id': 'r2',
    });
    expect((theirs['error']! as Map)['code'], 'not_found');
    expect(
      reservations.reservations.singleWhere((r) => r.id == 'r2').status,
      ReservationStatus.reserved,
    );

    final stale = await call('deskilo_cancel_reservation', {
      'request_id': 'req-4',
      'workspace_id': 'ws-1',
      'reservation_id': 'r3',
      'expected_state': 'not-the-state',
    });
    expect((stale['error']! as Map)['code'], 'conflict');
    expect(
      reservations.reservations.singleWhere((r) => r.id == 'r3').status,
      ReservationStatus.reserved,
    );
  });

  test('a booking is made once per request_id, on the named place', () async {
    await armed();
    final input = {
      'request_id': '6f1c6c1e-3b8a-4c55-9d4e-2f8b2a7c9e01',
      'workspace_id': 'ws-1',
      'seat_id': 'seat-9',
      'starts_at': '2027-01-05T09:00:00+01:00',
      'ends_at': '2027-01-05T12:00:00+01:00',
    };
    final before = reservations.reservations.length;
    final made = await call('deskilo_create_reservation', input);
    expect(made['ok'], isTrue, reason: '$made');
    expect((made['output']! as Map)['seat_id'], 'seat-9');
    expect(
      _keys(made['output']).difference(_outputs()['create_reservation']!),
      isEmpty,
    );
    await call('deskilo_create_reservation', input);
    expect(reservations.reservations.length, before + 1);

    final two = await call('deskilo_create_reservation', {
      ...input,
      'request_id': '6f1c6c1e-3b8a-4c55-9d4e-2f8b2a7c9e02',
      'desk_id': 'desk-1',
    });
    expect((two['error']! as Map)['code'], 'validation_error');
  });

  test('a deletion request on an own booking is pending, never done', () async {
    await armed();
    final asked = await call('deskilo_request_reservation_deletion', {
      'request_id': 'req-del-1',
      'workspace_id': 'ws-1',
      'reservation_id': 'r3',
      'reason': 'travelling',
    });
    expect(asked['ok'], isTrue, reason: '$asked');
    expect(asked['status'], 'pending_validation');
    final out = asked['output']! as Map<String, Object?>;
    expect(out['event_id'], isNotNull);
    expect(
      _keys(out).difference(_outputs()['request_reservation_deletion']!),
      isEmpty,
    );
    final theirs = await call('deskilo_request_reservation_deletion', {
      'request_id': 'req-del-2',
      'workspace_id': 'ws-1',
      'reservation_id': 'r2',
    });
    expect((theirs['error']! as Map)['code'], 'not_found');
  });

  test(
    'an answer to a validation waits for the person; Confirm lets it run once',
    () async {
      final c = await armed();
      final input = {
        'request_id': 'req-val-1',
        'workspace_id': 'ws-1',
        'event_id': 'e1',
        'accept': true,
      };
      final asked = await call('deskilo_respond_to_validation', input);
      expect(asked['status'], 'requires_confirmation');
      final request = c.read(webMcpConfirmationsProvider);
      expect(request?.operation, 'respond_to_validation');
      expect(
        (await call('deskilo_respond_to_validation', input))['status'],
        'requires_confirmation',
      );
      expect(events.events.single.status, EventStatus.pending);

      c
          .read(webMcpConfirmationsProvider.notifier)
          .decide(request!.key, accept: true);
      final done = await call('deskilo_respond_to_validation', input);
      expect(done['ok'], isTrue, reason: '$done');
      expect(done['status'], 'completed');
      expect(
        _keys(done['output']).difference(_outputs()['respond_to_validation']!),
        isEmpty,
      );
    },
  );

  test('a declined request is refused and nothing runs', () async {
    final c = await armed();
    final input = {
      'request_id': 'req-val-2',
      'workspace_id': 'ws-1',
      'event_id': 'e1',
      'accept': false,
    };
    await call('deskilo_respond_to_validation', input);
    final request = c.read(webMcpConfirmationsProvider)!;
    c
        .read(webMcpConfirmationsProvider.notifier)
        .decide(request.key, accept: false);
    final answer = await call('deskilo_respond_to_validation', input);
    expect((answer['error']! as Map)['code'], 'declined');
    expect(answer['status'], 'denied');
    expect(events.events.single.status, EventStatus.pending);
  });

  test('voiding an invoice needs the right first, then the person', () async {
    permissions = {};
    final c = await armed();
    final input = {
      'request_id': 'req-void-1',
      'workspace_id': 'ws-1',
      'invoice_id': 'i2',
    };
    final refused = await call('deskilo_request_invoice_void', input);
    expect((refused['error']! as Map)['code'], 'forbidden');
    expect(refused['status'], 'denied');
    expect(c.read(webMcpConfirmationsProvider), isNull);
    expect(invoiceCommands.voided, isEmpty);
  });

  test('a confirmed void runs the invoice screen call once', () async {
    final c = await armed();
    final input = {
      'request_id': 'req-void-2',
      'workspace_id': 'ws-1',
      'invoice_id': 'i2',
    };
    expect(
      (await call('deskilo_request_invoice_void', input))['status'],
      'requires_confirmation',
    );
    expect(invoiceCommands.voided, isEmpty);
    final request = c.read(webMcpConfirmationsProvider)!;
    c
        .read(webMcpConfirmationsProvider.notifier)
        .decide(request.key, accept: true);
    final done = await call('deskilo_request_invoice_void', input);
    expect(done['ok'], isTrue, reason: '$done');
    await call('deskilo_request_invoice_void', input);
    expect(invoiceCommands.voided, ['i2']);
    expect(
      _keys(done['output']).difference(_outputs()['request_invoice_void']!),
      isEmpty,
    );
  });

  test('a booking moves to a day and period, only when it is own', () async {
    await armed();
    final moved = await call('deskilo_update_reservation', {
      'request_id': 'req-move-1',
      'workspace_id': 'ws-1',
      'reservation_id': 'r1',
      'date': '2026-10-08',
      'period': 'morning',
    });
    expect(moved['ok'], isTrue, reason: '$moved');
    expect(
      _keys(moved['output']).difference(_outputs()['update_reservation']!),
      isEmpty,
    );
    final r1 = reservations.reservations.singleWhere((r) => r.id == 'r1');
    expect(r1.startsAt.toLocal().day, 8);

    final theirs = await call('deskilo_update_reservation', {
      'request_id': 'req-move-2',
      'workspace_id': 'ws-1',
      'reservation_id': 'r2',
      'date': '2026-10-08',
      'period': 'morning',
    });
    expect((theirs['error']! as Map)['code'], 'not_found');
  });

  test('an invoice is issued once, under the request_id, after Confirm', () async {
    final c = await armed();
    final input = {
      'request_id': '6f1c6c1e-3b8a-4c55-9d4e-2f8b2a7c9e09',
      'workspace_id': 'ws-1',
      'member_id': 'member-1',
      'period': '2026-09',
      'kind': 'full',
    };
    final asked = await call('deskilo_request_invoice_issue', input);
    expect(asked['status'], 'requires_confirmation');
    expect(invoiceCommands.issued, isEmpty);
    c
        .read(webMcpConfirmationsProvider.notifier)
        .decide(c.read(webMcpConfirmationsProvider)!.key, accept: true);
    final done = await call('deskilo_request_invoice_issue', input);
    expect(done['ok'], isTrue, reason: '$done');
    expect(done['status'], 'pending_validation');
    await call('deskilo_request_invoice_issue', input);
    expect(invoiceCommands.issued.single.requestId, input['request_id']);
    expect(
      _keys(done['output']).difference(_outputs()['request_invoice_issue']!),
      isEmpty,
    );

    final bad = await call('deskilo_request_invoice_issue', {
      ...input,
      'request_id': '6f1c6c1e-3b8a-4c55-9d4e-2f8b2a7c9e10',
      'period': '2026-13',
    });
    expect((bad['error']! as Map)['code'], 'validation_error');
  });

  test('a window longer than 31 days is refused', () async {
    await armed();
    final answer = await call('deskilo_list_my_reservations', {
      'workspace_id': 'ws-1',
      'from': '2026-10-01T00:00:00+02:00',
      'to': '2026-12-01T00:00:00+01:00',
    });
    expect(answer['ok'], isFalse);
  });

  test('every refusal and status the page answers is a contract status', () {
    final statuses = {
      ...((jsonDecode(
                File('contracts/mcp/operations.json').readAsStringSync(),
              )
              as Map)['statuses']!
          as List)
          .cast<String>(),
    };
    final used = {
      for (final file in Directory('lib/app').listSync().whereType<File>())
        if (file.path.contains('webmcp'))
          for (final m in RegExp(
            r"'status': '([a-z_]+)'|=> '([a-z_]+)'",
          ).allMatches(file.readAsStringSync()))
            (m[1] ?? m[2])!,
    };
    expect(used, containsAll(['requires_confirmation', 'denied']));
    expect(used.difference(statuses), isEmpty);
  });

  test('only tools with a runner are generated into the page', () {
    expect({
      for (final t in webMcpTools)
        if (webMcpReadRunners.containsKey(t.id)) t.id,
    }, webMcpReadRunners.keys.toSet());
  });
}
