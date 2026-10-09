// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2313 — four years of a space's life, from January three years back to
// the end of this year: the members' weekly bookings (done in the past,
// reserved ahead), the public holidays the space closes on, a monthly bill
// per member with the payment that settled it, the charges behind it, a
// cleaning contract's monthly expense and the decisions taken along the
// way. Reports, BI, statements and the calendar all have years to show.
//
// Placed relative to the seeded instant, never a literal date. Today and
// tomorrow are left to the hand-written story (demo_booking_seed.dart),
// so the plan a visitor lands on still has a free seat.
import '../../../features/events/domain/event_decision.dart';
import '../../../features/events/domain/workspace_event.dart';
import '../../../features/money/domain/expense_schedule.dart';
import '../../../features/money/domain/invoice.dart';
import '../../../features/money/domain/ledger_entry.dart';
import '../../../features/reservations/domain/reservation.dart';
import '../../../features/workspace/domain/closure_day.dart';
import '../data/event_repository.dart';
import '../data/floor_plan_repository.dart';
import '../data/money_repository.dart';
import '../data/reservation_repository.dart';
import '../data/workspace_repository.dart';
import 'demo_space_seed.dart';
import 'demo_people_seed.dart';

/// The first day the demo's history covers.
DateTime demoHistoryStart(DateTime now) => DateTime(now.year - 3, 1, 1);

/// The last day it covers: the end of the seeded year.
DateTime demoHistoryEnd(DateTime now) => DateTime(now.year, 12, 31);

/// One member's place in the history: when they joined, what they book
/// and what they pay.
class _Regular {
  const _Regular(
    this.memberId,
    this.name,
    this.joined,
    this.weekdays,
    this.from,
    this.to,
    this.monthlyCents,
  );
  final String memberId;
  final String name;
  final DateTime joined;
  final Set<int> weekdays;
  final int from;
  final int to;
  final int monthlyCents;
}

List<_Regular> _regulars(DateTime now, String windowSeat) => [
  _Regular(
    'member-1',
    'Ada Lindqvist',
    demoHistoryStart(now),
    {DateTime.monday, DateTime.wednesday, DateTime.friday},
    9,
    18,
    18000,
  ),
  _Regular(
    'member-2',
    'Bruno Kessler',
    DateTime(now.year - 2, 1, 1),
    {DateTime.tuesday, DateTime.thursday},
    9,
    13,
    9000,
  ),
  _Regular(
    'member-3',
    'Chiara Rossi',
    DateTime(now.year - 1, 7, 1),
    {DateTime.wednesday},
    13,
    18,
    18000,
  ),
];

String _seatOf(String memberId, String windowSeat) => switch (memberId) {
  'member-1' => windowSeat,
  'member-2' => 'demo-seat-1',
  _ => DemoSpace.studioSeats.last,
};

/// France's fixed public holidays, every year of the history.
void seedDemoHolidays(FakeWorkspaceRepository workspaces, DateTime now) {
  const fixed = [
    (1, 1),
    (5, 1),
    (5, 8),
    (7, 14),
    (8, 15),
    (11, 1),
    (11, 11),
    (12, 25),
  ];
  for (var y = now.year - 3; y <= now.year; y++) {
    for (final (m, d) in fixed) {
      workspaces.closureDays.add(
        ClosureDay(
          id: 'demo-holiday-$y-$m-$d',
          workspaceId: 'ws-1',
          day: DateTime(y, m, d),
          reason: 'Public holiday',
        ),
      );
    }
  }
}

/// The weekly bookings over the whole history.
void seedDemoHistoryBookings(
  FakeReservationRepository reservations,
  FakeFloorPlanRepository plan,
  FakeWorkspaceRepository workspaces,
  DateTime now,
) {
  final window = plan.seats.first.id;
  final today = DateTime(now.year, now.month, now.day);
  final closed = {
    for (final c in workspaces.closureDays)
      DateTime(c.day.year, c.day.month, c.day.day),
  };
  // A member books one place at a time: a day they already hold a booking
  // on (the hand-written story) keeps that one.
  final taken = {
    for (final r in reservations.reservations)
      (r.memberId, DateTime(r.startsAt.year, r.startsAt.month, r.startsAt.day)),
  };
  final end = demoHistoryEnd(now);
  final added = <Reservation>[];
  for (final regular in _regulars(now, window)) {
    for (
      var day = regular.joined;
      !day.isAfter(end);
      day = DateTime(day.year, day.month, day.day + 1)
    ) {
      if (!regular.weekdays.contains(day.weekday)) continue;
      if (closed.contains(day)) continue;
      // Today and tomorrow belong to the story; the plan stays bookable.
      final offset = day.difference(today).inDays;
      if (offset == 0 || offset == 1) continue;
      if (taken.contains((regular.memberId, day))) continue;
      final starts = day.add(Duration(hours: regular.from));
      final ends = day.add(Duration(hours: regular.to));
      final past = day.isBefore(today);
      added.add(
        Reservation(
          id: 'demo-h-${regular.memberId}-${day.year}-${day.month}-${day.day}',
          workspaceId: 'ws-1',
          seatId: _seatOf(regular.memberId, window),
          memberId: regular.memberId,
          startsAt: starts,
          endsAt: ends,
          status: past
              ? ReservationStatus.completed
              : ReservationStatus.reserved,
          checkedInAt: past ? starts : null,
          checkedOutAt: past ? ends : null,
        ),
      );
    }
  }
  reservations.reservations.addAll(added);
}

/// [base] after the 4 % the price rises every January of the history.
int demoMonthlyCents(int base, int year, DateTime now) =>
    (base * (1 + 0.04 * (year - demoHistoryStart(now).year))).round();

String _period(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

/// The invoice number of [member]'s bill for the month of [issued]:
/// year, month and the member's place, so the archive reads in order.
String demoInvoiceNumber(DateTime issued, int memberIndex) =>
    'F-${issued.year}-${issued.month.toString().padLeft(2, '0')}'
    '${memberIndex.toString().padLeft(2, '0')}';

/// A monthly bill per member for every month of the history before last
/// month (which the story issues), each paid a few days after issue.
void seedDemoHistoryMoney(FakeMoneyRepository money, DateTime now) {
  final lastMonth = DateTime(now.year, now.month - 1, 1);
  for (final (index, regular) in _regulars(now, '').indexed) {
    for (
      var month = DateTime(regular.joined.year, regular.joined.month, 1);
      month.isBefore(lastMonth);
      month = DateTime(month.year, month.month + 1, 1)
    ) {
      final cents = demoMonthlyCents(regular.monthlyCents, month.year, now);
      final issued = DateTime(month.year, month.month, 28);
      final period = _period(month);
      final id = 'demo-h-inv-${regular.memberId}-$period';
      money.invoices.add(
        Invoice(
          id: id,
          workspaceId: 'ws-1',
          memberId: regular.memberId,
          number: demoInvoiceNumber(issued, index + 1),
          issuedAt: issued,
          period: period,
          title: period,
          lines: [InvoiceLine(label: period, amountCents: cents)],
          totalCents: cents,
          currency: 'EUR',
          memberName: regular.name,
          memberAddress: '',
          workspaceName: demoSpaceName,
          workspaceAddress: demoSpaceAddress,
          issuerName: 'Ada Lindqvist',
          signature: 'demo',
          dueOn: issued.add(const Duration(days: 10)),
        ),
      );
      money.ledger.add(
        LedgerEntry(
          id: 'demo-h-sub-${regular.memberId}-$period',
          memberId: regular.memberId,
          kind: LedgerKind.charge,
          category: LedgerCategory.subscription,
          amountCents: cents,
          description: 'Subscription',
          period: period,
          createdAt: issued,
        ),
      );
      // Bruno pays late now and then; everybody pays in the end.
      final late = regular.memberId == 'member-2' && month.month.isEven;
      final paidOn = issued.add(Duration(days: late ? 19 : 4));
      final ledgerId = 'demo-h-pay-${regular.memberId}-$period';
      money.ledger.add(
        LedgerEntry(
          id: ledgerId,
          memberId: regular.memberId,
          kind: LedgerKind.credit,
          category: LedgerCategory.payment,
          amountCents: cents,
          description: 'Bank transfer',
          period: period,
          createdAt: paidOn,
          occurredOn: paidOn,
        ),
      );
      money.consumedPaymentIds.add(ledgerId);
      money.invoiceMatchesStore[id] = InvoiceMatch(
        invoiceId: id,
        paidCents: cents,
        resolution: 'exact',
        paymentLedgerId: ledgerId,
        matchedAt: paidOn,
        byName: 'Ada Lindqvist',
      );
      if (late) {
        money.invoiceReminders[id] = [issued.add(const Duration(days: 12))];
      }
    }
  }

  // The cleaning contract has run since the start of last year: every
  // past month's occurrence was added.
  for (
    var month = DateTime(now.year - 1, 1, 1);
    month.isBefore(DateTime(now.year, now.month, 1));
    month = DateTime(month.year, month.month + 1, 1)
  ) {
    money.expenseOccurrences.add(
      ExpenseOccurrence(
        id: 'demo-h-cleaning-${_period(month)}',
        scheduleId: 'demo-schedule-cleaning',
        workspaceId: 'ws-1',
        memberId: 'member-3',
        dueOn: month,
        amountCents: 12000,
        scheduleTitle: 'Cleaning service',
        scheduledAmountCents: 12000,
        status: OccurrenceStatus.added,
      ),
    );
  }
}

/// The decisions of the years: extra half-days asked each quarter, and
/// settled.
void seedDemoHistoryDecisions(FakeEventRepository events, DateTime now) {
  for (
    var month = DateTime(now.year - 2, 1, 15);
    month.isBefore(DateTime(now.year, now.month - 1, 1));
    month = DateTime(month.year, month.month + 3, 15)
  ) {
    final id = 'demo-h-quota-${_period(month)}';
    final refused = month.month == 7;
    events.events.add(
      WorkspaceEvent(
        id: id,
        workspaceId: 'ws-1',
        type: EventType.quota,
        action: EventAction.submitted,
        actorMemberId: 'member-2',
        subjectMemberId: 'member-2',
        payload: {'half_days': 2, 'period': _period(month)},
        status: refused ? EventStatus.rejected : EventStatus.confirmed,
        createdAt: month,
        decidedAt: month.add(const Duration(days: 1)),
      ),
    );
    events.decisions.add(
      EventDecision(
        id: 'demo-h-decision-${_period(month)}',
        eventId: id,
        memberId: 'member-1',
        accept: !refused,
        decidedBySystem: false,
        decidedAt: month.add(const Duration(days: 1)),
      ),
    );
  }
}
