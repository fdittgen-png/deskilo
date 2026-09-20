// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1456 — the controlled workload the journey benchmark runs against,
// and the meter that separates its three costs.
//
// The suite's fixture is one office, one desk, one seat. Nothing
// measured on it says anything about a floor a member actually books
// on, and an N+1 read is invisible at n=1. This builds the same shape
// at three sizes, deterministically: no random, no wall clock, no
// network — the same bytes on every machine and every run.
//
// ## The three costs, kept apart
//
// A single "booking took 480 ms" hides which half regressed. So the
// benchmark never adds them up:
//
//  * **network** is counted as ROUND TRIPS, not milliseconds. This
//    backend is in memory; a per-trip latency would be an assumption
//    dressed as a measurement. The count is the shape of the traffic —
//    the thing that turns a 200 ms network into 2 s — and it is exact.
//  * **UI** is frames and elements (deterministic) beside a wall clock
//    (reported, host-dependent, never gated).
//  * **retries** come from `kRetryDelays` in the app itself, so the
//    worst case a member can wait moves when that policy moves.
//
// The ledger scale is deliberately NOT duplicated here: twelve months
// of it, against a real planner, is `supabase/tests/database/
// 30_query_budgets.sql`. Re-seeding it in memory would measure a List.
import 'package:deskilo/core/demo/data/fixture_clock.dart';
import 'package:deskilo/core/demo/data/floor_plan_repository.dart';
import 'package:deskilo/core/demo/data/reservation_repository.dart';
import 'package:deskilo/features/plan/domain/floor_plan.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/level.dart';
import 'package:deskilo/features/plan/domain/office.dart';
import 'package:deskilo/features/plan/domain/desk.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';

/// A workspace size the benchmark runs at. Ten desks per office and four
/// seats per desk is the shape of a real coworking floor; the plan grid
/// is 120 cells a side, which holds twenty rooms of 24×15.
enum WorkloadScale {
  small(offices: 2, reservations: 40),
  medium(offices: 8, reservations: 400),
  large(offices: 20, reservations: 2000);

  const WorkloadScale({required this.offices, required this.reservations});

  final int offices;
  final int reservations;

  int get desks => offices * 10;
  int get seats => desks * 4;

  /// What the record calls this run's dataset.
  String get label => '$name(${offices}o/${desks}d/${seats}s/'
      '${reservations}r)';
}

/// Fills [plans] with one level at [scale]. Ids are positional, so the
/// same scale always produces the same plan.
void seedPlan(FakeFloorPlanRepository plans, WorkloadScale scale,
    {String workspaceId = 'ws-1'}) {
  plans.levels.add(Level(
    id: 'level-1',
    workspaceId: workspaceId,
    name: 'Ground floor',
    sortOrder: 0,
  ));
  for (var o = 0; o < scale.offices; o++) {
    final ox = (o % 5) * 24;
    final oy = (o ~/ 5) * 15;
    plans.offices.add(Office(
      id: 'office-$o',
      workspaceId: workspaceId,
      levelId: 'level-1',
      name: 'Room ${o + 1}',
      color: o % 6,
      bookableAsWhole: false,
      rect: GridRect(x: ox, y: oy, w: 23, h: 14),
    ));
    for (var d = 0; d < 10; d++) {
      final dx = ox + 1 + (d % 5) * 4;
      final dy = oy + 1 + (d ~/ 5) * 6;
      final deskId = 'desk-$o-$d';
      plans.desks.add(Desk(
        id: deskId,
        workspaceId: workspaceId,
        officeId: 'office-$o',
        name: 'Desk ${o + 1}.${d + 1}',
        rect: GridRect(x: dx, y: dy, w: 4, h: 4),
      ));
      for (var s = 0; s < 4; s++) {
        plans.seats.add(Seat(
          id: 'seat-$o-$d-$s',
          workspaceId: workspaceId,
          deskId: deskId,
          name: '${o + 1}.${d + 1}.${s + 1}',
          x: dx + (s % 2) * 2,
          y: dy + (s ~/ 2) * 2,
          orientation: SeatOrientation.n,
          chair: 'standard',
          amenities: const ['monitor'],
        ));
      }
    }
  }
}

/// Fills [repo] with [WorkloadScale.reservations] bookings spread over
/// the fourteen days around [kTestNow], round-robin over the seats and
/// twenty members. Seat 0 of office 0 is left free on the fixture day so
/// the booking journey always has somewhere to book.
void seedReservations(FakeReservationRepository repo, WorkloadScale scale,
    {String workspaceId = 'ws-1'}) {
  final day = DateTime(kTestNow.year, kTestNow.month, kTestNow.day);
  for (var i = 0; i < scale.reservations; i++) {
    final seat = 1 + i % (scale.seats - 1);
    final offset = (i % 14) - 7;
    final start = day.add(Duration(days: offset, hours: 9));
    repo.reservations.add(Reservation(
      id: 'res-$i',
      workspaceId: workspaceId,
      seatId: 'seat-${seat ~/ 40}-${(seat % 40) ~/ 4}-${seat % 4}',
      memberId: 'member-${2 + i % 20}',
      startsAt: start,
      endsAt: start.add(const Duration(hours: 8)),
      status: offset < 0
          ? ReservationStatus.completed
          : ReservationStatus.reserved,
    ));
  }
}

/// Counts the backend round trips a journey makes, by call.
///
/// Only the calls the metered repositories below override are counted,
/// and that is the point of the gate's MINIMUM: a journey that suddenly
/// reports zero trips has lost the seam, not gained a cache, and the
/// gate must say so rather than record a triumph.
class BackendMeter {
  final calls = <String, int>{};

  int get trips => calls.values.fold(0, (a, b) => a + b);

  Future<T> trip<T>(String op, Future<T> Function() body) {
    calls.update(op, (n) => n + 1, ifAbsent: () => 1);
    return body();
  }

  void reset() => calls.clear();
}

/// The plan reads the Reserve hub makes on the way to its first frame.
class MeteredPlans extends FakeFloorPlanRepository {
  MeteredPlans(this.meter);

  final BackendMeter meter;

  @override
  Future<List<Level>> fetchLevels(String workspaceId) =>
      meter.trip('plan.fetchLevels', () => super.fetchLevels(workspaceId));

  @override
  Future<FloorPlan> fetchPlan(String levelId) =>
      meter.trip('plan.fetchPlan', () => super.fetchPlan(levelId));

  @override
  Future<Map<String, String>> fetchTargetNames(String workspaceId) => meter
      .trip('plan.fetchTargetNames', () => super.fetchTargetNames(workspaceId));
}

/// The reservation window read, and the booking write.
class MeteredReservations extends FakeReservationRepository {
  MeteredReservations(this.meter);

  final BackendMeter meter;

  @override
  Future<List<Reservation>> fetchWindow(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
  }) =>
      meter.trip('reservations.fetchWindow',
          () => super.fetchWindow(workspaceId, from: from, to: to));

  @override
  Future<String> create({
    required String workspaceId,
    String? seatId,
    String? deskId,
    String? officeId,
    String? levelId,
    required DateTime startsAt,
    required DateTime endsAt,
    bool checkIn = false,
  }) =>
      meter.trip(
          'reservations.create',
          () => super.create(
                workspaceId: workspaceId,
                seatId: seatId,
                deskId: deskId,
                officeId: officeId,
                levelId: levelId,
                startsAt: startsAt,
                endsAt: endsAt,
                checkIn: checkIn,
              ));
}
