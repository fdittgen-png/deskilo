// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3291 — the Demo's operational journeys, second part (the first is
// demo_workflow_audit_test.dart): decisions, each city's own currency,
// switching and resetting spaces, and the catalogue's subprocesses. Two
// files, because every case builds the whole Demo and one file with all of
// them outgrew the memory a test process is allowed.
// The matrix these rows pin is
// docs/testing/evidence/demo-audit-3291-workflows.md.
import 'package:deskilo/core/calendar/calendar_item.dart';
import 'package:deskilo/core/demo/data/money/demo_member_account_commands.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/core/demo/demo_session.dart';
import 'package:deskilo/core/demo/seed/demo_london_seed.dart';
import 'package:deskilo/core/demo/seed/demo_new_york_seed.dart';
import 'package:deskilo/core/demo/seed/demo_second_space_seed.dart';
import 'package:deskilo/features/calendar/providers/calendar_providers.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/events/providers/event_providers.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/providers/money_queries_providers.dart';
import 'package:deskilo/features/plan/domain/half_day_windows.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_process.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _spaces = ['ws-1', demoSecondSpaceId, demoLondonSpaceId, demoNewYorkSpaceId];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DemoFixture fixture;
  late ProviderContainer container;

  setUp(() {
    fixture = DemoFixture.build();
    container = ProviderContainer(overrides: demoOverrides(fixture))
      ..listen(currentWorkspaceProvider, (_, _) {});
  });
  tearDown(() => container.dispose());

  Future<void> enter(String space) async {
    await container.read(currentWorkspaceProvider.future);
    container.read(activeWorkspaceIdProvider.notifier).activate(space);
    expect((await container.read(currentWorkspaceProvider.future))?.id, space);
    // The booking right is read from the member and the space, as on screen.
    container.listen(myPermissionsProvider, (_, _) {});
    await container.read(myMemberProvider.future);
  }

  List<Reservation> storeOf(String space) => switch (space) {
        demoSecondSpaceId => fixture.secondSpace.reservations.reservations,
        demoLondonSpaceId => fixture.london.reservations.reservations,
        demoNewYorkSpaceId => fixture.newYork.reservations.reservations,
        _ => fixture.reservations.reservations,
      };

  group('decisions apply what respond_to_event applies (0101)', () {
    Future<WorkspaceEvent> decide(String space, String eventId, {required bool accept}) async {
      await enter(space);
      final events = container.read(eventRepositoryProvider);
      await events.respond(eventId, accept: accept);
      return (await events.fetchEvent(eventId))!;
    }

    test('a recorded payment files a pending request; its confirmation '
        'credits the member\'s account (record_payment 0070, 0101)', () async {
      await enter('ws-1');
      final id = await container.read(memberAccountCommandsProvider).recordPayment(
            workspaceId: 'ws-1', memberId: 'member-2', amountCents: 4200, note: 'June rent');
      final events = container.read(eventRepositoryProvider);
      final filed = await events.fetchEvent(id);
      expect(filed?.type, EventType.payment);
      expect(filed?.status, EventStatus.pending);
      expect(fixture.money.ledger.where((l) => l.amountCents == 4200 && l.memberId == 'member-2'), isEmpty,
          reason: 'recorded is not paid: no credit before the decision');
      // Ada recorded it; another person decides (#434, no self-approval):
      // the subject of an admin-initiated event confirms it (rule (a)).
      fixture.becomePersona(DemoPersona.member);
      await events.respond(id, accept: true);
      final credit = fixture.money.ledger
          .where((l) => l.memberId == 'member-2' && l.kind == LedgerKind.credit &&
              l.category == LedgerCategory.payment && l.amountCents == 4200)
          .toList();
      expect(credit, hasLength(1), reason: 'the confirmed payment is credited once');
    });

    test('a payment recorded at a 2027 Demo clock is filed and paid in 2027', () async {
      final f = DemoFixture.build(now: DateTime(2027, 1, 1, 10));
      final id = await DemoMemberAccountCommands(f.money).recordPayment(
            workspaceId: 'ws-1', memberId: 'member-2', amountCents: 4200);
      final filed = f.money.eventRepository!.events.singleWhere((e) => e.id == id);
      expect(filed.createdAt, DateTime(2027, 1, 1, 10));
      expect(filed.payload['paid_on'], '2027-01-01');
      expect(filed.payload['period'], '2027-01');
    });

    test('an approved reservation deletion cancels the booking', () async {
      final e = await decide('ws-1', 'demo-delete-request', accept: true);
      expect(e.status, EventStatus.confirmed);
      final target = e.payload['reservation_id'] as String? ?? e.reservationId;
      expect(fixture.reservations.reservations.singleWhere((r) => r.id == target).status,
          ReservationStatus.cancelled);
    });

    test('an approved join makes the member active; a refused one exits', () async {
      await decide('ws-1', 'demo-join-request', accept: true);
      final members = await container.read(workspaceRepositoryProvider).fetchMembers('ws-1');
      expect(members.singleWhere((m) => m.id == 'member-4').status, MemberStatus.active);

      final again = DemoFixture.build();
      await again.events.respond('demo-join-request', accept: false);
      final after = await again.workspaces.fetchMembers('ws-1');
      expect(after.singleWhere((m) => m.id == 'member-4').status, MemberStatus.exited);
    });

    test('a refused room request cancels the room it held', () async {
      final e = await decide('ws-1', 'demo-room-request-event', accept: false);
      expect(e.status, EventStatus.rejected);
      expect(fixture.reservations.reservations.singleWhere((r) => r.id == 'demo-room-request').status,
          ReservationStatus.cancelled);
    });

    for (final (space, expense, service) in [
      ('ws-1', 'demo-expense', 'demo-service-charge'),
      (demoLondonSpaceId, 'uk-expense', 'uk-service'),
      (demoNewYorkSpaceId, 'ny-expense', 'ny-service'),
    ]) {
      test('$space — an approved expense credits the member and an approved '
          'service charges them, in that space\'s account', () async {
        final money = switch (space) {
          demoLondonSpaceId => fixture.london.money,
          demoNewYorkSpaceId => fixture.newYork.money,
          _ => fixture.money,
        };
        final ex = await decide(space, expense, accept: true);
        final sv = await decide(space, service, accept: true);
        // 0101 credits the expense's amount; #2860 — a service request
        // carries a unit price and a quantity (0016), charged as their product.
        int cents(WorkspaceEvent e) => e.payload['amount_cents'] != null
            ? (e.payload['amount_cents'] as num).toInt()
            : (e.payload['price_cents'] as num).toInt() * (e.payload['quantity'] as num).toInt();
        LedgerEntry? entryFor(WorkspaceEvent e, LedgerKind kind) => money.ledger
            .where((l) => l.memberId == e.subjectMemberId && l.kind == kind && l.amountCents == cents(e))
            .firstOrNull;
        expect(entryFor(ex, LedgerKind.credit), isNotNull, reason: 'the expense is credited');
        expect(entryFor(sv, LedgerKind.charge), isNotNull, reason: 'the service is charged');
      });
    }
  });

  test('each city\'s calendar states its amounts in the space\'s own '
      'currency', () async {
    for (final (space, currency) in [(demoLondonSpaceId, 'GBP'), (demoNewYorkSpaceId, 'USD')]) {
      await enter(space);
      final page = await container.read(calendarRepositoryProvider).fetchItems(
            space,
            CalendarQuery(
              from: fixture.seededAt.subtract(const Duration(days: 400)),
              to: fixture.seededAt.add(const Duration(days: 400)),
            ),
          );
      final stated = {for (final i in page.items) if (i.currency != null) i.currency};
      expect(stated, isNotEmpty, reason: '$space has amounts in its calendar');
      expect(stated, {currency}, reason: '$space never states an amount in another currency');
    }
  });

  test('switching spaces: each space reads its own plan, bookings and '
      'requests, and returns to them unchanged', () async {
    final before = <String, int>{};
    for (final space in _spaces) {
      await enter(space);
      final events = await container.read(eventRepositoryProvider).fetchEvents(space);
      expect(events.every((e) => e.workspaceId == space), isTrue, reason: '$space reads its own requests');
      before[space] = storeOf(space).length;
    }
    for (final space in _spaces.reversed) {
      await enter(space);
      expect(storeOf(space).length, before[space], reason: 'switching changed nothing in $space');
    }
  });

  test('reset after mutations restores every space', () async {
    final session = ProviderContainer();
    addTearDown(session.dispose);
    final controller = session.read(demoSessionControllerProvider.notifier);
    final f = session.read(demoSessionControllerProvider).fixture;
    final seat = f.london.floorPlan.seats.first.id;
    final w = [
      for (var d = 7; d < 60; d++) HalfDayWindows.morning(f.seededAt.add(Duration(days: d))),
    ].firstWhere((w) => !f.london.reservations.reservations.any((r) =>
        r.seatId == seat && r.isActive && r.startsAt.isBefore(w.end) && w.start.isBefore(r.endsAt)));
    final id = await f.london.reservations
        .create(workspaceId: demoLondonSpaceId, seatId: seat, startsAt: w.start, endsAt: w.end);
    await f.events.respond('demo-join-request', accept: true);
    controller.reset();
    final fresh = session.read(demoSessionControllerProvider).fixture;
    expect(fresh.london.reservations.reservations.where((r) => r.id == id && r.startsAt == w.start), isEmpty);
    expect(fresh.events.events.singleWhere((e) => e.id == 'demo-join-request').status, EventStatus.pending);
  });

  test('every subprocess of the catalogue is either effective in a space '
      'or off there for a stated reason', () {
    final gaps = <String>[];
    final reasoned = <String>{};
    for (final ws in fixture.workspaces.workspaces) {
      final effective = effectiveFeatures(resolveEnabledFeatures(ws.featureFlags), country: ws.countryCode);
      for (final process in workspaceProcesses) {
        for (final step in process.subprocesses) {
          final key = '${ws.id}/${process.key}/${step.key}';
          if (step.capabilities.any(effective.contains)) continue;
          _offOnPurpose.containsKey(key) ? reasoned.add(key) : gaps.add(key);
        }
      }
    }
    expect(gaps, isEmpty, reason: 'each needs a scenario or a stated reason in _offOnPurpose');
    expect(_offOnPurpose.keys.toSet().difference(reasoned), isEmpty,
        reason: 'a reason for a subprocess that is in fact on is stale');
  });
}


/// Subprocesses a space keeps entirely off, and why (the matrix's exclusions).
const _leipzigNew = 'Leipzig carries exactly what a new workspace starts with '
    '(defaultFeatureFlagsForNewWorkspace, pinned by demo_second_space_test): the '
    'space shows the Demo a fresh, basic space, so these steps are off there by design.';
const _offOnPurpose = <String, String>{
  'ws-2/billingPayments/collection': _leipzigNew,
  'ws-2/billingPayments/expenses': _leipzigNew,
  'ws-2/billingPayments/tax': _leipzigNew,
  'ws-2/documentsInformation/reportDesign': _leipzigNew,
  'ws-2/reservationsUsage/attendance': _leipzigNew,
};
