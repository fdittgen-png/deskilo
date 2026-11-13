// SPDX-License-Identifier: AGPL-3.0-or-later
// Invariant: every city booking and invoice refers to its own people and
// space, no person or seat is double-booked, and invoice lines and VAT add up.
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the complete city histories reconcile', () {
    final fixture = DemoFixture.build(now: DateTime.utc(2026, 11, 2, 10));
    for (final city in [
      (
        id: 'ws-3',
        space: fixture.london.workspaces,
        plan: fixture.london.floorPlan,
        bookings: fixture.london.reservations,
        money: fixture.london.money,
        months: 36,
      ),
      (
        id: 'ws-4',
        space: fixture.newYork.workspaces,
        plan: fixture.newYork.floorPlan,
        bookings: fixture.newYork.reservations,
        money: fixture.newYork.money,
        months: 48,
      ),
      // #3832 - the trade cities: two years, no hourly usage line.
      (
        id: 'ws-5',
        space: fixture.zurich.workspaces,
        plan: fixture.zurich.floorPlan,
        bookings: fixture.zurich.reservations,
        money: fixture.zurich.money,
        months: 24,
      ),
      (
        id: 'ws-6',
        space: fixture.milan.workspaces,
        plan: fixture.milan.floorPlan,
        bookings: fixture.milan.reservations,
        money: fixture.milan.money,
        months: 24,
      ),
    ]) {
      final members = {
        city.space.myMember.id,
        ...city.space.otherMembers.map((m) => m.id),
      };
      final seats = city.plan.seats.map((s) => s.id).toSet();
      final officeLevel = {
        for (final office in city.plan.offices) office.id: office.levelId,
      };
      final deskLevel = {
        for (final desk in city.plan.desks) desk.id: officeLevel[desk.officeId],
      };
      final seatLevel = {
        for (final seat in city.plan.seats) seat.id: deskLevel[seat.deskId],
      };
      final levelsBooked = <String>{};
      final peopleAtTime = <String>{}, seatsAtTime = <String>{};
      final completed = <String>{};
      final errors = <String>[];
      for (final booking in city.bookings.reservations) {
        if (booking.workspaceId != city.id ||
            !members.contains(booking.memberId) ||
            !booking.endsAt.isAfter(booking.startsAt)) {
          errors.add('invalid booking ${booking.id}');
        }
        if (booking.seatId case final seat?) {
          if (booking.status == ReservationStatus.completed) {
            completed.add(booking.id);
          }
          if (seatLevel[seat] case final level?) levelsBooked.add(level);
          final when = booking.startsAt.toIso8601String();
          if (!seats.contains(seat) ||
              !seatsAtTime.add('$seat/$when') ||
              !peopleAtTime.add('${booking.memberId}/$when')) {
            errors.add('duplicate or missing booking target ${booking.id}');
          }
        }
      }
      final usageIds = city.money.usageRecords
          .map((u) => u.reservationId)
          .toSet();
      expect(usageIds.length, completed.length);
      expect(
        usageIds.containsAll(completed),
        isTrue,
        reason: 'every completed booking produces exactly its own usage record',
      );
      expect(
        city.money.usageRecords.every(
          (u) => u.countedMinutes == u.reservedMinutes,
        ),
        isTrue,
      );
      final bookedHours = <(String, String), int>{};
      for (final usage in city.money.usageRecords) {
        final key = (usage.memberId, usage.period);
        bookedHours[key] = (bookedHours[key] ?? 0) + usage.countedMinutes ~/ 60;
      }
      expect(
        levelsBooked,
        containsAll(city.plan.levels.map((level) => level.id)),
        reason: 'every site and level has booking activity',
      );
      for (final rental in city.bookings.reservations.where(
        (r) => r.id.contains('site-rental'),
      )) {
        expect(
          city.bookings.reservations.where(
            (r) =>
                r.seatId != null &&
                seatLevel[r.seatId] == rental.levelId &&
                r.startsAt.isBefore(rental.endsAt) &&
                r.endsAt.isAfter(rental.startsAt),
          ),
          isEmpty,
          reason: 'the entire rented level is reserved exclusively',
        );
      }
      final months = <String>{};
      for (final invoice in city.money.invoices) {
        if (invoice.workspaceId != city.id ||
            !members.contains(invoice.memberId)) {
          errors.add('invalid invoice ${invoice.id}');
        }
        final gross = invoice.lines.fold<int>(
          0,
          (sum, line) => sum + line.amountCents,
        );
        if (gross != invoice.totalCents) {
          errors.add('invoice total ${invoice.id}');
        }
        final net = invoice.lines.fold<int>(
          0,
          (sum, line) =>
              sum + vatSplit(line.amountCents, line.vatPercent).netCents,
        );
        if (invoice.vatTotals.isNotEmpty &&
            invoice.vatTotals.fold<int>(
                  0,
                  (sum, rate) => sum + rate.netCents,
                ) !=
                net) {
          errors.add('invoice VAT ${invoice.id}');
        }
        if (invoice.id.contains('-invoice-')) {
          if (invoice.period case final period?) {
            months.add(period);
          } else {
            errors.add('invoice without period ${invoice.id}');
          }
          if (city.id == 'ws-4') {
            final hours = bookedHours[(invoice.memberId, invoice.period)] ?? 0;
            final usageLines = invoice.lines
                .where((line) => line.label.startsWith('Workspace use'))
                .toList();
            if (hours == 0
                ? usageLines.isNotEmpty
                : usageLines.length != 1 ||
                      usageLines.single.quantity != hours ||
                      usageLines.single.amountCents != hours * 800) {
              errors.add('hourly usage ${invoice.id}');
            }
          }
          final match = city.money.invoiceMatchesStore[invoice.id];
          final paymentDue = invoice.issuedAt.add(const Duration(days: 5));
          final overdueMonth = DateTime(
            fixture.seededAt.year,
            fixture.seededAt.month - 2,
          );
          final overdue =
              invoice.memberId == 'member-2' &&
              invoice.issuedAt.year == overdueMonth.year &&
              invoice.issuedAt.month == overdueMonth.month;
          if (overdue && !city.money.invoiceReminders.containsKey(invoice.id)) {
            errors.add('missing reminder ${invoice.id}');
          }
          if (paymentDue.isAfter(fixture.seededAt) || overdue
              ? match != null
              : match == null ||
                    match.paidCents != invoice.totalCents ||
                    match.matchedAt.isBefore(invoice.issuedAt)) {
            errors.add('invoice payment ${invoice.id}');
          }
        }
      }
      expect(
        errors.take(20),
        isEmpty,
        reason: '${city.id}: ${errors.length} inconsistencies',
      );
      expect(months, hasLength(city.months), reason: city.id);
    }
  });
}
