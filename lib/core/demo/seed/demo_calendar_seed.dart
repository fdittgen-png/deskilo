// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2313 — the calendar reads its own list (calendar_items on a server),
// so the demo builds it from the session's records: every booking,
// check-in, invoice, payment, due date, scheduled expense and decision
// lands on the day it happened.
import '../../calendar/calendar_item.dart';
import '../../../features/reservations/domain/reservation.dart';
import '../data/calendar_repository.dart';
import '../data/event_repository.dart';
import '../data/money_repository.dart';
import '../data/reservation_repository.dart';

void seedDemoCalendar(
  FakeCalendarRepository calendar, {
  required FakeReservationRepository reservations,
  required FakeMoneyRepository money,
  required FakeEventRepository events,
}) {
  final items = <CalendarItem>[];
  for (final r in reservations.reservations) {
    items.add(
      CalendarItem(
        kind: CalendarKind.reservation,
        id: 'cal-res-${r.id}',
        at: r.startsAt,
        until: r.endsAt,
        memberId: r.memberId,
        title: r.seatId != null ? 'Seat booking' : 'Room booking',
        status: r.status.name,
        link: ReservationLink(r.id),
      ),
    );
    if (r.checkedInAt case final inAt?) {
      items.add(
        CalendarItem(
          kind: CalendarKind.checkIn,
          id: 'cal-in-${r.id}',
          at: inAt,
          memberId: r.memberId,
          title: 'Check-in',
          link: ReservationLink(r.id),
        ),
      );
    }
    if (r.checkedOutAt case final outAt?) {
      items.add(
        CalendarItem(
          kind: CalendarKind.checkOut,
          id: 'cal-out-${r.id}',
          at: outAt,
          memberId: r.memberId,
          title: 'Check-out',
          link: ReservationLink(r.id),
        ),
      );
    }
    if (r.status == ReservationStatus.checkedIn) {
      items.add(
        CalendarItem(
          kind: CalendarKind.checkIn,
          id: 'cal-in-${r.id}',
          at: r.startsAt,
          memberId: r.memberId,
          title: 'Check-in',
          link: ReservationLink(r.id),
        ),
      );
    }
  }
  for (final invoice in money.invoices) {
    items.add(
      CalendarItem(
        kind: CalendarKind.invoice,
        id: 'cal-inv-${invoice.id}',
        at: invoice.issuedAt,
        memberId: invoice.memberId,
        title: invoice.number,
        amountCents: invoice.totalCents,
        currency: invoice.currency,
        link: InvoiceLink(invoice.id),
      ),
    );
    final open =
        !money.invoiceMatchesStore.containsKey(invoice.id) &&
        invoice.totalCents > 0;
    if (open && invoice.dueOn != null) {
      items.add(
        CalendarItem(
          kind: CalendarKind.due,
          id: 'cal-due-${invoice.id}',
          at: invoice.dueOn!,
          memberId: invoice.memberId,
          title: invoice.number,
          status: 'open',
          amountCents: invoice.totalCents,
          currency: invoice.currency,
          link: InvoiceLink(invoice.id),
        ),
      );
    }
  }
  for (final entry in money.ledger) {
    if (entry.category.name != 'payment') continue;
    items.add(
      CalendarItem(
        kind: CalendarKind.payment,
        id: 'cal-pay-${entry.id}',
        at: entry.occurredOn ?? entry.createdAt,
        memberId: entry.memberId,
        title: entry.description,
        amountCents: entry.amountCents,
        currency: 'EUR',
        link: LedgerLink(entry.period),
      ),
    );
  }
  for (final o in money.expenseOccurrences) {
    items.add(
      CalendarItem(
        kind: CalendarKind.scheduled,
        id: 'cal-sched-${o.id}',
        at: o.dueOn,
        memberId: o.memberId,
        title: o.scheduleTitle,
        amountCents: o.amountCents,
        currency: 'EUR',
      ),
    );
  }
  for (final e in events.events) {
    items.add(
      CalendarItem(
        kind: CalendarKind.event,
        id: 'cal-ev-${e.id}',
        at: e.createdAt,
        memberId: e.subjectMemberId,
        title: '${e.type.dbName}.submitted',
        status: e.status.name,
        link: EventLink(e.id),
      ),
    );
  }
  calendar.items
    ..clear()
    ..addAll(items);
}
