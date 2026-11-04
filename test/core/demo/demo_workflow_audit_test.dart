// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3291 — the Demo's operational journeys followed to their observable
// outcome in every space, through the scope a visitor uses (fixture plus
// the routed overrides). Each expectation is the product contract — the
// server's respond_to_event effects (0101), the calendar's live
// calendar_items read, one space's rows never answering for another —
// never the fake's own bookkeeping. The matrix these rows pin is
// docs/testing/evidence/demo-audit-3291-workflows.md.
import 'package:deskilo/core/calendar/calendar_item.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/core/demo/demo_session.dart';
import 'package:deskilo/core/demo/seed/demo_london_seed.dart';
import 'package:deskilo/core/demo/seed/demo_new_york_seed.dart';
import 'package:deskilo/core/demo/seed/demo_second_space_seed.dart';
import 'package:deskilo/features/calendar/providers/calendar_providers.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/events/providers/event_providers.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/plan/domain/half_day_windows.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/providers/reservation_providers.dart';
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
    container.read(activeWorkspaceIdProvider.notifier).activate(space);
    expect((await container.read(currentWorkspaceProvider.future))?.id, space);
  }

  List<Reservation> storeOf(String space) => switch (space) {
        demoSecondSpaceId => fixture.secondSpace.reservations.reservations,
        demoLondonSpaceId => fixture.london.reservations.reservations,
        demoNewYorkSpaceId => fixture.newYork.reservations.reservations,
        _ => fixture.reservations.reservations,
      };

  String seatOf(String space) => switch (space) {
        demoSecondSpaceId => fixture.secondSpace.floorPlan.seats.first.id,
        demoLondonSpaceId => fixture.london.floorPlan.seats.first.id,
        demoNewYorkSpaceId => fixture.newYork.floorPlan.seats.first.id,
        _ => fixture.floorPlan.seats.first.id,
      };

  /// A free morning a week ahead for [seat], so no seeded booking holds it.
  ({DateTime start, DateTime end}) freeMorning(String space, String seat) {
    for (var d = 7; d < 60; d++) {
      final w = HalfDayWindows.morning(fixture.seededAt.add(Duration(days: d)));
      final taken = storeOf(space).any((r) =>
          r.seatId == seat && r.isActive && r.startsAt.isBefore(w.end) && w.start.isBefore(r.endsAt));
      if (!taken) return (start: w.start, end: w.end);
    }
    throw StateError('no free morning for $seat');
  }

  Future<List<CalendarItem>> calendarAround(String space, DateTime at) async {
    final page = await container.read(calendarRepositoryProvider).fetchItems(
          space,
          CalendarQuery(
            from: at.subtract(const Duration(days: 1)),
            to: at.add(const Duration(days: 1)),
            kinds: const {CalendarKind.reservation},
          ),
        );
    return page.items;
  }

  group('reservations: book, move, cancel, in each space', () {
    for (final space in _spaces) {
      test('$space — the booking is the space\'s own, on the plan and in the '
          'calendar, and its cancellation reaches both', () async {
        await enter(space);
        final repo = container.read(reservationRepositoryProvider);
        final seat = seatOf(space);
        final w = freeMorning(space, seat);

        final id = await repo.create(workspaceId: space, seatId: seat, startsAt: w.start, endsAt: w.end);

        expect(storeOf(space).where((r) => r.id == id), hasLength(1),
            reason: 'the booking is stored by the space it was made in');
        for (final other in _spaces.where((s) => s != space)) {
          expect(storeOf(other).where((r) => r.id == id && r.workspaceId == space), isEmpty,
              reason: '$other never holds $space\'s booking');
        }
        final window = await repo.fetchWindow(space, from: w.start, to: w.end);
        expect(window.map((r) => r.id), contains(id), reason: 'the plan of the day shows it');
        expect((await calendarAround(space, w.start)).map((i) => i.link), contains(ReservationLink(id)),
            reason: 'calendar_items reads the reservations table live: a booking made '
                'in the session is in the calendar the same moment it is on the plan');

        final later = HalfDayWindows.afternoon(w.start);
        await repo.updateTimes(id, startsAt: later.start, endsAt: later.end);
        expect((await repo.fetchById(id))?.startsAt, later.start, reason: 'moved');
        final moved = (await calendarAround(space, later.start)).where((i) => i.link == ReservationLink(id));
        expect(moved.map((i) => i.at), [later.start], reason: 'the calendar follows the move');

        await repo.cancel(id);
        expect((await repo.fetchById(id))?.status, ReservationStatus.cancelled);
        final cancelled = (await calendarAround(space, later.start)).where((i) => i.link == ReservationLink(id));
        expect(cancelled.map((i) => i.status), [ReservationStatus.cancelled.name],
            reason: 'the calendar shows the cancellation, not the booking as it was');
      });
    }
  });

  group('decisions apply what respond_to_event applies (0101)', () {
    Future<WorkspaceEvent> decide(String space, String eventId, {required bool accept}) async {
      await enter(space);
      final events = container.read(eventRepositoryProvider);
      await events.respond(eventId, accept: accept);
      return (await events.fetchEvent(eventId))!;
    }

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
    final w = HalfDayWindows.morning(f.seededAt.add(const Duration(days: 20)));
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
    for (final ws in fixture.workspaces.workspaces) {
      final effective = effectiveFeatures(resolveEnabledFeatures(ws.featureFlags), country: ws.countryCode);
      for (final process in workspaceProcesses) {
        for (final step in process.subprocesses) {
          final on = step.capabilities.where(effective.contains);
          expect(on.isNotEmpty || _offOnPurpose.containsKey('${ws.id}/${process.key}/${step.key}'), isTrue,
              reason: '${ws.id}: ${process.key}/${step.key} has no effective capability and no reason');
        }
      }
    }
  });
}

/// Subprocesses a space keeps entirely off, and why (the matrix's exclusions).
const _offOnPurpose = <String, String>{};
