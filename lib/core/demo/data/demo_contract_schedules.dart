// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3785 — the contract schedules of a Demo space, as the server keeps them
// (`expense_schedules` with origin `workspace_contract`):
//
//   * each term of a lease is its own schedule (0474): its amount every
//     `every_months` months from the day it takes effect, ending the day
//     before the next term of its kind, or on the lease's end once notice
//     is given;
//   * a rented room at a fixed cost per period is one (0515): its cost every
//     month, quarter or year from the day it is available until the day it
//     no longer is;
//   * the schedule's next due day follows the last occurrence generated
//     from it, or is its first day while none is.
//
// And what the contracts still expect in a window, by `kpi_costs_summary`
// (0532): a generated occurrence that is not rejected, less the bills
// matched to it, never below 0; the occurrences not generated yet
// projected from the schedule exactly as the sweep will generate them,
// within its end and its count.
import 'package:meta/meta.dart';

import '../../../features/money/domain/lease_commitment.dart';
import '../../../features/money/domain/premises_lease.dart';
import '../../../features/money/domain/room_rental.dart';
import 'lease_commitment_repository.dart';

/// One contract schedule, as `expense_schedules` holds it.
typedef DemoContractSchedule = ({
  String id,
  int amountCents,
  String unit,
  int every,
  DateTime? nextDue,
  int done,
  DateTime? endsOn,
  int? repeatCount,
  bool active,
});

/// What the contracts expect in a window, and the part already due.
typedef DemoUnbilled = ({int total, int overdue});

/// [d] plus [every] [unit]s, as Postgres adds an interval to a date: a day
/// the target month does not have becomes its last day.
@visibleForTesting
DateTime addScheduleInterval(DateTime d, String unit, int every) {
  final month = d.month + (unit == 'year' ? 12 * every : every);
  final last = DateTime(d.year, month + 1, 0).day;
  return DateTime(d.year, month, d.day > last ? last : d.day);
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// The schedule of [id] from its [first] day, its next due day after the
/// last occurrence [commitments] generated from it.
DemoContractSchedule _schedule(
  FakeLeaseCommitmentRepository commitments,
  ({
    String id,
    int amountCents,
    String unit,
    int every,
    DateTime first,
    DateTime? endsOn,
  })
  terms,
) {
  final (:id, :amountCents, :unit, :every, :first, :endsOn) = terms;
  final generated = [
    for (final occurrences in commitments.occurrencesByLease.values)
      for (final o in occurrences)
        if (commitments.termOf[o.id] == id) _day(o.dueOn),
  ]..sort();
  return (
    id: id,
    amountCents: amountCents,
    unit: unit,
    every: every,
    nextDue: generated.isEmpty
        ? _day(first)
        : addScheduleInterval(generated.last, unit, every),
    done: generated.length,
    endsOn: endsOn == null ? null : _day(endsOn),
    repeatCount: null,
    active: true,
  );
}

/// The schedules of [leases]' terms and of [rentals] at a fixed cost.
List<DemoContractSchedule> demoContractSchedules({
  required Iterable<PremisesLease> leases,
  required Iterable<RoomRental> rentals,
  required FakeLeaseCommitmentRepository commitments,
}) => [
  for (final lease in leases)
    if (lease.status != LeaseStatus.draft)
      for (final t in lease.terms)
        _schedule(commitments, (
          id: t.id,
          amountCents: t.amountCents,
          unit: 'month',
          every: t.everyMonths,
          first: t.effectiveFrom,
          endsOn: _earliest(t.effectiveTo, lease.effectiveEnd),
        )),
  for (final r in rentals)
    if (r.status == RoomRentalStatus.active &&
        r.costKind == 'fixed_per_period' &&
        r.costCents > 0)
      _schedule(commitments, (
        id: r.id,
        amountCents: r.costCents,
        unit: r.period == 'year' ? 'year' : 'month',
        every: r.period == 'quarter' ? 3 : 1,
        first: r.availableFrom,
        endsOn: r.availableUntil,
      )),
];

DateTime? _earliest(DateTime? a, DateTime? b) =>
    a == null ? b : (b == null || a.isBefore(b) ? a : b);

/// What [schedules] and the occurrences of [commitments] still expect from
/// [start] to [cut], and the part due before [today] (0532).
DemoUnbilled demoUnbilled({
  required List<DemoContractSchedule> schedules,
  required FakeLeaseCommitmentRepository commitments,
  required DateTime start,
  required DateTime cut,
  required DateTime today,
}) {
  var total = 0, overdue = 0;
  void count(DateTime due, int left) {
    if (due.isBefore(start) || due.isAfter(cut)) return;
    total += left;
    if (due.isBefore(today)) overdue += left;
  }

  for (final occurrences in commitments.occurrencesByLease.values) {
    for (final CommitmentOccurrence o in occurrences) {
      if (commitments.rejected.contains(o.id)) continue;
      count(_day(o.dueOn), o.remainingCents < 0 ? 0 : o.remainingCents);
    }
  }
  for (final s in schedules) {
    if (!s.active || s.nextDue == null) continue;
    var due = s.nextDue!;
    var done = s.done;
    while (!due.isAfter(cut)) {
      final ended = s.endsOn != null && due.isAfter(s.endsOn!);
      final counted = s.repeatCount != null && done >= s.repeatCount!;
      if (!ended && !counted) count(due, s.amountCents);
      due = addScheduleInterval(due, s.unit, s.every);
      done++;
    }
  }
  return (total: total, overdue: overdue);
}
