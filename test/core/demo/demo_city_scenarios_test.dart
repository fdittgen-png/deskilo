// SPDX-License-Identifier: AGPL-3.0-or-later
// Invariant: both synthetic cities retain their own plans, members, bookings
// and invoices, and hourly New York usage is billed from booked time.
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_link.dart';
import 'package:deskilo/core/demo/seed/demo_london_seed.dart';
import 'package:deskilo/core/demo/seed/demo_new_york_seed.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:deskilo/features/workspace/domain/booking_granularity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('city data stays separate and is reachable with a Demo link', () {
    final fixture = DemoFixture.build(now: DateTime.utc(2026, 11, 2, 10));
    final london = fixture.london;
    final newYork = fixture.newYork;
    expect([
      london.workspaces.myMember,
      ...london.workspaces.otherMembers,
    ], hasLength(85));
    expect(
      [
        london.workspaces.myMember,
        ...london.workspaces.otherMembers,
      ].where((m) => m.subscriptionPct < 100),
      hasLength(20),
    );
    expect([
      newYork.workspaces.myMember,
      ...newYork.workspaces.otherMembers,
    ], hasLength(60));
    expect(london.workspaces.sites, hasLength(3));
    expect(newYork.workspaces.sites, hasLength(5));
    expect(
      london.floorPlan.levels.where((l) => l.siteId == demoLondonSiteId),
      hasLength(4),
    );
    expect(
      newYork.floorPlan.levels.where((l) => l.siteId == 'ny-site-main'),
      hasLength(4),
    );
    expect(
      london.floorPlan.offices.where((o) => o.levelId == 'uk-level-0-1'),
      hasLength(12),
    );
    expect(
      newYork.floorPlan.offices.where(
        (o) =>
            o.levelId.startsWith('ny-level-0-') && o.name.startsWith('Office'),
      ),
      hasLength(12),
    );
    expect(
      london.floorPlan.seats.any((s) => s.resourceKind == ResourceKind.parking),
      isTrue,
    );
    expect(
      newYork.floorPlan.seats.any(
        (s) => s.resourceKind == ResourceKind.parking,
      ),
      isTrue,
    );
    expect(
      newYork.workspaces.bookingGranularities[demoNewYorkSpaceId],
      BookingGranularity.minutes60,
    );
    expect(london.reservations.reservations.length, greaterThan(10000));
    expect(newYork.reservations.reservations.length, greaterThan(10000));
    expect(
      london.reservations.reservations.every(
        (r) => r.workspaceId == demoLondonSpaceId,
      ),
      isTrue,
    );
    expect(
      newYork.reservations.reservations.every(
        (r) => r.workspaceId == demoNewYorkSpaceId,
      ),
      isTrue,
    );
    expect(
      DemoLink.parse({'space': 'new-york'}).workspaceId,
      demoNewYorkSpaceId,
    );
    expect(
      const DemoLink(workspaceId: demoNewYorkSpaceId).toQuery()['space'],
      'new-york',
    );
    expect(london.money.vatDeclarations, hasLength(1));
    expect(london.money.invoices.length, greaterThan(100));
    expect(newYork.money.invoices.length, greaterThan(100));
    final usage = newYork.money.invoices
        .expand((invoice) => invoice.lines)
        .firstWhere((line) => line.label.contains('hours at'));
    expect(usage.amountCents, usage.quantity * 800);
    for (final money in [london.money, newYork.money]) {
      final services = money.services.map((s) => s.name).toSet();
      expect(
        services,
        containsAll([
          'Bottled water',
          'Beer',
          'Sweets and snacks',
          'Black and white pages',
          'Colour pages',
          'Copies',
          '3D print jobs',
        ]),
      );
      expect(
        money.invoices
            .expand((invoice) => invoice.lines)
            .any((line) => line.label == 'Beer'),
        isTrue,
      );
    }
    expect(
      london.reservations.reservations.where(
        (r) => r.id.contains('site-rental'),
      ),
      hasLength(2),
    );
  });
}
