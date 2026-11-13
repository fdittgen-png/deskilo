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
import 'package:deskilo/core/demo/demo_clock.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/core/demo/seed/demo_london_seed.dart';
import 'package:deskilo/core/demo/seed/demo_new_york_seed.dart';
import 'package:deskilo/core/demo/seed/demo_second_space_seed.dart';
import 'package:deskilo/core/realtime/invalidation_map.dart';
import 'package:deskilo/core/realtime/realtime_wiring.dart';
import 'package:deskilo/features/calendar/providers/calendar_providers.dart';
import 'package:deskilo/features/plan/domain/half_day_windows.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/providers/reservation_providers.dart';
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

  String seatOf(String space) => switch (space) {
        demoSecondSpaceId => fixture.secondSpace.floorPlan.seats.first.id,
        demoLondonSpaceId => fixture.london.floorPlan.seats.first.id,
        demoNewYorkSpaceId => fixture.newYork.floorPlan.seats.first.id,
        _ => fixture.floorPlan.seats.first.id,
      };

  /// A free morning a week ahead for [seat], so no seeded booking holds it.
  ({DateTime start, DateTime end}) freeMorning(String space, String seat) =>
      _freeDay(fixture, storeOf(space), seat);

  bool isBooking(CalendarItem i, String id) => i.link is ReservationLink && (i.link! as ReservationLink).id == id;

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
        expect((await calendarAround(space, w.start)).where((i) => isBooking(i, id)), hasLength(1),
            reason: 'calendar_items reads the reservations table live: a booking made '
                'in the session is in the calendar the same moment it is on the plan');

        final later = HalfDayWindows.afternoon(w.start);
        await repo.updateTimes(id, startsAt: later.start, endsAt: later.end);
        expect((await repo.fetchById(id))?.startsAt, later.start, reason: 'moved');
        final moved = (await calendarAround(space, later.start)).where((i) => isBooking(i, id));
        expect(moved.map((i) => i.at), [later.start], reason: 'the calendar follows the move');

        await repo.cancel(id);
        expect((await repo.fetchById(id))?.status, ReservationStatus.cancelled);
        final cancelled = (await calendarAround(space, later.start)).where((i) => isBooking(i, id));
        expect(cancelled.map((i) => i.status), [ReservationStatus.cancelled.name],
            reason: 'the calendar shows the cancellation, not the booking as it was');
      });
    }
  });

  test('the open calendar shows a booking once the app\'s mutation path '
      'invalidates it, as invalidateBookingData does after every booking', () async {
    await enter('ws-1');
    final scope = container;
    final seat = seatOf('ws-1');
    final w = freeMorning('ws-1', seat);
    final query = CalendarQuery(from: w.start.subtract(const Duration(days: 1)), to: w.end.add(const Duration(days: 1)));
    scope.listen(calendarItemsProvider(query), (_, _) {});
    final before = await scope.read(calendarItemsProvider(query).future);

    final id = await scope
        .read(reservationRepositoryProvider)
        .create(workspaceId: 'ws-1', seatId: seat, startsAt: w.start, endsAt: w.end);
    expect(before.items.where((i) => isBooking(i, id)), isEmpty);
    // What the booking sheet runs after a booking (invalidateBookingData):
    // the providers the realtime map names for the tables it wrote.
    for (final table in bookingMutationTables) {
      for (final provider in scope.read(invalidationLookupProvider)(table).providers) {
        scope.invalidate(provider);
      }
    }
    final after = await scope.read(calendarItemsProvider(query).future);
    expect(after.items.where((i) => isBooking(i, id)), hasLength(1),
        reason: 'the refetch reads the session\'s bookings, not the seed');
  });

  test('the journey\'s slot is free at any Demo clock', () async {
    for (final now in [demoSeedNow, demoSeedNow.add(const Duration(days: 47, hours: 5))]) {
      final f = DemoFixture.build(now: now);
      for (final (rows, repo, seat, space) in [
        (f.reservations.reservations, f.reservations, f.floorPlan.seats.first.id, 'ws-1'),
        (f.secondSpace.reservations.reservations, f.secondSpace.reservations, f.secondSpace.floorPlan.seats.first.id, demoSecondSpaceId),
        (f.london.reservations.reservations, f.london.reservations, f.london.floorPlan.seats.first.id, demoLondonSpaceId),
        (f.newYork.reservations.reservations, f.newYork.reservations, f.newYork.floorPlan.seats.first.id, demoNewYorkSpaceId),
      ]) {
        final w = _freeDay(f, rows, seat);
        final id = await repo.create(workspaceId: space, seatId: seat, startsAt: w.start, endsAt: w.end);
        final later = HalfDayWindows.afternoon(w.start);
        await repo.updateTimes(id, startsAt: later.start, endsAt: later.end);
      }
    }
  });
}

/// A morning, a week or more ahead, whose morning AND afternoon neither
/// [seat] nor the acting persona holds in [rows] (the one-place rule,
/// `enforce_one_place`), so the book-then-move journey never meets a
/// seeded booking whatever day the Demo believes it is.
({DateTime start, DateTime end}) _freeDay(DemoFixture fixture, List<Reservation> rows, String seat) {
  bool clash(Reservation r, HalfDayWindow w) =>
      r.isActive && r.startsAt.isBefore(w.end) && w.start.isBefore(r.endsAt) &&
      (r.seatId == seat || r.memberId == fixture.activeMemberId);
  for (var d = 7; d < 120; d++) {
    final day = fixture.seededAt.add(Duration(days: d));
    final halves = [HalfDayWindows.morning(day), HalfDayWindows.afternoon(day)];
    if (rows.any((r) => halves.any((w) => clash(r, w)))) continue;
    return (start: halves.first.start, end: halves.first.end);
  }
  throw StateError('no free day for $seat');
}
