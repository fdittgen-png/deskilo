// SPDX-License-Identifier: AGPL-3.0-or-later
// Invariant: both synthetic cities retain their own plans, members, bookings
// and invoices, and hourly New York usage is billed from booked time.
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_link.dart';
import 'package:deskilo/core/demo/seed/demo_london_seed.dart';
import 'package:deskilo/core/demo/seed/demo_new_york_seed.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:deskilo/features/workspace/domain/booking_granularity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'city decisions, roles, fields and badges belong to their space',
    () async {
      final fixture = DemoFixture.build(now: DateTime.utc(2026, 11, 2, 10));
      for (final city in [
        (
          id: demoLondonSpaceId,
          events: fixture.london.events,
          roles: fixture.london.roles,
          fields: fixture.london.fields,
          credits: fixture.london.credits,
          space: fixture.london.workspaces,
        ),
        (
          id: demoNewYorkSpaceId,
          events: fixture.newYork.events,
          roles: fixture.newYork.roles,
          fields: fixture.newYork.fields,
          credits: fixture.newYork.credits,
          space: fixture.newYork.workspaces,
        ),
      ]) {
        expect(city.fields.fields, isNotEmpty);
        expect(city.fields.answers['member-2'], isNotEmpty);
        expect(
          city.roles.assignments.values.expand((ids) => ids),
          contains('member-3'),
        );
        expect(city.credits.products, isNotEmpty);
        expect(
          city.space.badges.every((b) => b.workspaceId == city.id),
          isTrue,
        );
        expect(
          city.space.documents.every((d) => d.workspaceId == city.id),
          isTrue,
        );
        final pending = await city.events.fetchEvents(city.id);
        expect(pending.map((event) => event.type), contains(EventType.expense));
        final expense = pending.firstWhere(
          (event) => event.type == EventType.expense,
        );
        await city.events.respond(expense.id, accept: true);
        expect(
          (await city.events.fetchEvent(expense.id))!.status,
          EventStatus.confirmed,
        );
        final writeoff = await city.events.requestInvoiceWriteoff('example');
        expect((await city.events.fetchEvent(writeoff))!.workspaceId, city.id);
      }
    },
  );
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
    final partTime = {
      for (final member in [
        london.workspaces.myMember,
        ...london.workspaces.otherMembers,
      ])
        if (member.subscriptionPct < 100) member.id,
    };
    expect(
      london.reservations.reservations.where(
        (r) =>
            r.seatId != null &&
            partTime.contains(r.memberId) &&
            r.startsAt.weekday > 3,
      ),
      isEmpty,
    );
    expect([
      newYork.workspaces.myMember,
      ...newYork.workspaces.otherMembers,
    ], hasLength(60));
    expect(london.workspaces.sites, hasLength(3));
    expect(newYork.workspaces.sites, hasLength(5));
    expect(
      london.floorPlan.seats.where((s) => s.resourceKind == ResourceKind.room),
      hasLength(3),
    );
    expect(
      newYork.floorPlan.seats.where((s) => s.resourceKind == ResourceKind.room),
      hasLength(5),
    );
    expect(london.chargingStations.stations['uk-parking-1'], isNotNull);
    expect(newYork.chargingStations.stations['ny-parking-1'], isNotNull);
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
      expect(money.expenseSchedules, isNotEmpty);
      expect(
        money.expenseOccurrences.single.scheduleId,
        money.expenseSchedules.single.id,
      );
      expect(money.invoiceReminders, isNotEmpty);
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
