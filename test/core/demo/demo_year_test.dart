// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The demo carries the whole year and the whole finance story: rooms and
// parking booked until 31 December, invoices in every payment state, the
// rent and utilities schedules, suppliers, received supplier invoices, bills,
// receipts and claims. Whatever "today" is.
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/seed/demo_purchase_seed.dart';
import 'package:deskilo/features/money/domain/einvoice_inbox.dart';
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final now in [DateTime(2026, 10, 17, 10), DateTime(2031, 3, 5, 10)]) {
    group('the demo opened on ${now.year}-${now.month}-${now.day}', () {
      final fixture = DemoFixture.build(now: now);
      final reservations = fixture.reservations.reservations;

      test('parking, the boardroom and the meeting room are booked until '
          'the end of the year', () {
        final lastDay = DateTime(now.year, 12, 31);
        bool onResource(Reservation r, String prefix) =>
            r.id.startsWith('demo-y-$prefix') &&
            r.startsAt.isAfter(DateTime(now.year, 12)) &&
            !r.startsAt.isAfter(lastDay.add(const Duration(days: 1)));
        expect(reservations.any((r) => onResource(r, 'ev-')), isTrue);
        expect(reservations.any((r) => onResource(r, 'p1-')), isTrue);
        expect(reservations.any((r) => onResource(r, 'board-')), isTrue);
        // The first Friday of a month, up to the last month of the year.
        expect(
          reservations
              .where((r) => r.id.startsWith('demo-y-meeting-'))
              .map((r) => r.startsAt.month),
          contains(12),
        );
        // Nothing beyond the year, nothing before three months back.
        for (final r in reservations.where((r) => r.id.startsWith('demo-y-'))) {
          expect(r.startsAt.year, lessThanOrEqualTo(now.year));
        }
      });

      test('what is behind is completed, what is ahead is reserved', () {
        final y = reservations.where((r) => r.id.startsWith('demo-y-'));
        expect(
          y
              .where((r) => r.endsAt.isBefore(now))
              .every((r) => r.status == ReservationStatus.completed),
          isTrue,
        );
        expect(
          y
              .where((r) => r.startsAt.isAfter(now))
              .every((r) => r.status == ReservationStatus.reserved),
          isTrue,
        );
      });

      test('room and parking invoices stand in every payment state', () {
        final money = fixture.money;
        final matches = money.invoiceMatchesStore;
        expect(matches['demo-usage-chiara-a']?.resolution, 'exact');
        final writtenOff = matches['demo-usage-chiara-b'];
        expect(writtenOff?.resolution, 'under_accepted');
        expect(writtenOff?.writeoffAt, isNotNull);
        final partial = matches['demo-usage-chiara-c'];
        expect(partial?.resolution, 'under_accepted');
        expect(partial?.writeoffAt, isNull);
        final total = money.invoices
            .firstWhere((i) => i.id == 'demo-usage-chiara-c')
            .totalCents;
        expect(partial!.paidCents, lessThan(total));
        expect(
          matches.containsKey('demo-usage-bruno'),
          isFalse,
          reason: 'unpaid and reminded',
        );
        expect(money.invoiceReminders['demo-usage-bruno'], isNotEmpty);
        expect(matches['demo-credit-ada']?.resolution, 'refunded');
      });

      test('sales carry France\'s four VAT rates, stated per rate', () {
        final rates = <double>{
          for (final i in fixture.money.invoices)
            for (final t in i.vatTotals) t.percent,
        };
        expect(rates, containsAll(<double>[20, 10, 5.5, 0]));
        // Every invoice states its VAT; the tax adds up to the gross.
        for (final i in fixture.money.invoices.where((i) => i.totalCents > 0)) {
          expect(i.vatTotals, isNotEmpty, reason: i.id);
          expect(
            i.vatTotals.fold(0, (s, t) => s + t.netCents + t.vatCents),
            i.vatTotals.fold(0, (s, t) => s + t.grossCents),
            reason: i.id,
          );
        }
        final exempt = fixture.money.invoices
            .firstWhere((i) => i.id == 'demo-usage-chiara-a')
            .vatTotals
            .firstWhere((t) => t.percent == 0);
        expect(exempt.exemptionReason, 'Article 261 CGI');
      });

      test('the space has two sites in France, the parking on the garage', () {
        final sites = fixture.workspaces.sites;
        expect(sites.map((s) => s.countryCode).toSet(), {'FR'});
        expect(sites, hasLength(2));
        expect(sites.where((s) => s.isDefault), hasLength(1));
        final garage = sites.firstWhere((s) => s.name == 'Garage Saint-Jean');
        final parking = fixture.floorPlan.levels.firstWhere(
          (l) => l.id == 'demo-level-parking',
        );
        expect(parking.siteId, garage.id);
        final studio = fixture.floorPlan.levels.where(
          (l) => l.id != 'demo-level-parking',
        );
        expect(studio.every((l) => l.siteId != garage.id), isTrue);
      });

      test('the space pays its rent and its utilities every month', () {
        final titles = {
          for (final s in fixture.money.expenseSchedules) s.title,
        };
        expect(
          titles,
          containsAll(<String>[
            'Rent of the premises',
            'Fibre internet',
            'Coffee beans',
          ]),
        );
        expect(
          fixture.money.expenseOccurrences.where(
            (o) => o.scheduleId == 'demo-schedule-rent',
          ),
          isNotEmpty,
        );
      });
    });
  }

  test('the purchase side: suppliers, received invoices, bills, receipts, '
      'claims and a payment', () async {
    final p = seedDemoPurchasing(DateTime(2026, 10, 17, 10));
    expect(p.suppliers.suppliers.length, greaterThanOrEqualTo(4));
    expect({
      for (final d in p.inbox.documents) d.status,
    }, containsAll(InboxStatus.values));
    final docs = await p.purchases.fetchPurchases('ws-1');
    expect({for (final d in docs) d.kind}, containsAll(PurchaseKind.values));
    expect(
      {for (final d in docs) d.state},
      containsAll(<PurchaseState>[
        PurchaseState.draft,
        PurchaseState.pending,
        PurchaseState.approved,
        PurchaseState.rejected,
      ]),
    );
    final claims = await p.purchases.fetchPayables('ws-1');
    expect(claims.any((c) => c.obligation.paidCents > 0), isTrue);
    expect(claims.any((c) => c.obligation.paidCents == 0), isTrue);
    // A bill opens with its supplier and its due date.
    final rent = await p.purchases.fetchDetail('ws-1', 'demo-bill-rent');
    expect(rent.supplierName, 'SCI Les Remparts');
    expect(rent.dueOn, isNotNull);
    // Purchases carry several rates, one bill several at once.
    final rates = <double>{};
    for (final d in docs) {
      final detail = await p.purchases.fetchDetail('ws-1', d.id);
      rates.addAll([
        for (final l in detail.lines)
          if (l.taxRatePercent != null) l.taxRatePercent!,
      ]);
    }
    expect(rates, containsAll(<double>[20, 10, 5.5, 0]));
    final energy = await p.purchases.fetchDetail('ws-1', 'demo-bill-energy');
    expect(energy.lines.map((l) => l.taxRatePercent), [5.5, 20]);
    // A bill that never stated its tax stays unknown, not zero.
    final water = await p.purchases.fetchDetail(
      'ws-1',
      'demo-bill-energy-unread',
    );
    expect(water.lines.single.taxStated, isFalse);
  });
}
