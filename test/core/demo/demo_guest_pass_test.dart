// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3308 — guest passes in the Demo, through the Demo's own composition:
// each space sells its own passes in its own currency (London a day pass,
// New York by the hour), a sale books the place day by day for a customer
// record of origin guest, invoices the pass to the guest by name, files a
// pending payment when the money was taken, and the same request never
// sells twice; a persona without issueInvoices is refused.
import 'package:deskilo/core/demo/data/guest_pass_repository.dart';
import 'package:deskilo/core/demo/demo_clock.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/core/demo/seed/demo_london_seed.dart';
import 'package:deskilo/core/demo/seed/demo_new_york_seed.dart';
import 'package:deskilo/core/demo/seed/demo_second_space_seed.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/money/domain/guest_pass.dart';
import 'package:deskilo/features/money/providers/guest_pass_providers.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../helpers/demo_free_seat.dart';

void main() {
  late DemoFixture fixture;
  late ProviderContainer container;

  setUp(() {
    fixture = DemoFixture.build();
    container = ProviderContainer(overrides: demoOverrides(fixture))
      ..listen(currentWorkspaceProvider, (_, _) {});
  });
  tearDown(() => container.dispose());

  Future<GuestPassRepository> enter(String space) async {
    await container.read(currentWorkspaceProvider.future);
    container.read(activeWorkspaceIdProvider.notifier).activate(space);
    expect((await container.read(currentWorkspaceProvider.future))?.id, space);
    container.listen(myPermissionsProvider, (_, _) {});
    await container.read(myMemberProvider.future);
    return container.read(guestPassRepositoryProvider);
  }

  DateTime aDay(int ahead) {
    final d = fixture.seededAt.add(Duration(days: ahead));
    return DateTime(d.year, d.month, d.day);
  }

  test('the units and the amount are counted as the server counts them', () {
    const hour = GuestPassOffer(id: 'h', name: 'H', unit: GuestPassUnit.hour, priceCents: 900);
    const day = GuestPassOffer(id: 'd', name: 'D', unit: GuestPassUnit.day, priceCents: 2500);
    final d = DateTime(2026, 5, 20);
    final hourly = GuestPassDraft(offer: hour, seatId: 's', day: d, startMinutes: 600, endMinutes: 750);
    expect(guestPassUnits(hourly), 3, reason: '10:00-12:30 is three started hours');
    expect(guestPassAmountCents(hourly), 2700);
    final daily = GuestPassDraft(offer: day, seatId: 's', day: d, startMinutes: 540, endMinutes: 1080, days: 3);
    expect(guestPassUnits(daily), 3);
    expect(guestPassAmountCents(daily), 7500);
    expect(guestPassProblems(daily), isEmpty);
    expect(
      guestPassProblems(GuestPassDraft(offer: hour, seatId: null, day: d, startMinutes: 600, endMinutes: 600, days: 2)),
      [GuestPassProblem.noSeat, GuestPassProblem.endBeforeStart, GuestPassProblem.hourlyOneDay],
    );
    expect(guestPassOfferProblems(' ', null), {GuestPassOfferProblem.name, GuestPassOfferProblem.price});
  });

  test('each space lists its own passes; Leipzig, with the passes off, none', () async {
    expect((await (await enter(demoLondonSpaceId)).offers(demoLondonSpaceId)).map((o) => o.unit).toSet(),
        {GuestPassUnit.day, GuestPassUnit.hour});
    expect((await (await enter(demoNewYorkSpaceId)).offers(demoNewYorkSpaceId)).single.unit, GuestPassUnit.hour);
    expect(await (await enter(demoSecondSpaceId)).offers(demoSecondSpaceId), isEmpty);
  });

  test('a two-day London pass books the seat each day and invoices the guest in pounds', () async {
    final passes = await enter(demoLondonSpaceId);
    final offer = (await passes.offers(demoLondonSpaceId)).firstWhere((o) => o.unit == GuestPassUnit.day);
    final slot = freeSeatForPass(fixture.london.floorPlan.seats, fixture.london.reservations.reservations, aDay(20),
        days: 2, startMinutes: 540, endMinutes: 1080);
    final seat = slot.seatId;
    final sale = await passes.sell(
      demoLondonSpaceId,
      draft: GuestPassDraft(offer: offer, seatId: seat, day: slot.day, startMinutes: 540, endMinutes: 1080, days: 2, paid: true, method: 'card'),
      guest: const {'first_name': 'Gwen', 'last_name': 'Guest', 'email': 'gwen@guest.test'},
      requestId: 'r-london',
    );
    expect(sale.units, 2);
    expect(sale.amountCents, 2 * offer.priceCents);
    final booked = fixture.london.reservations.reservations.where((r) => sale.reservationIds.contains(r.id)).toList();
    expect(booked, hasLength(2));
    expect(booked.every((r) => r.memberId == sale.memberId && r.seatId == seat), isTrue);
    expect(booked.map((r) => r.startsAt.day).toSet(), {slot.day.day, DateTime(slot.day.year, slot.day.month, slot.day.day + 1).day});
    final guest = fixture.london.workspaces.otherMembers.singleWhere((m) => m.id == sale.memberId);
    expect(guest.origin, MemberOrigin.guest);
    expect(guest.subscriptionPct, 0);
    expect(guest.userId, isEmpty, reason: 'no account');
    final invoice = fixture.london.money.invoices.singleWhere((i) => i.id == sale.invoiceId);
    expect(invoice.currency, 'GBP');
    expect(invoice.totalCents, sale.amountCents);
    expect(invoice.memberName, 'Gwen Guest');
    expect(
      fixture.london.money.eventRepository!.events
          .any((e) => e.id == sale.paymentEventId && e.type == EventType.payment && e.status == EventStatus.pending),
      isTrue,
      reason: 'the money taken at the desk is a payment waiting for its decision',
    );
    expect(fixture.reservations.reservations.any((r) => r.memberId == sale.memberId), isFalse,
        reason: 'nothing in Pézenas');
  });

  test('a New York hourly pass is priced by the started hour, in dollars', () async {
    final passes = await enter(demoNewYorkSpaceId);
    final offer = (await passes.offers(demoNewYorkSpaceId)).single;
    final sale = await passes.sell(
      demoNewYorkSpaceId,
      draft: () {
        final slot = freeSeatForPass(fixture.newYork.floorPlan.seats, fixture.newYork.reservations.reservations, aDay(21),
            startMinutes: 600, endMinutes: 750);
        return GuestPassDraft(offer: offer, seatId: slot.seatId, day: slot.day, startMinutes: 600, endMinutes: 750);
      }(),
      guest: const {'first_name': 'Hal', 'last_name': 'Hourly'},
      requestId: 'r-ny',
    );
    expect(sale.units, 3);
    expect(fixture.newYork.money.invoices.singleWhere((i) => i.id == sale.invoiceId).currency, 'USD');
    expect(sale.paymentEventId, isNull, reason: 'not paid at the desk: nothing recorded');
  });

  test('the same request sells once', () async {
    final passes = await enter(demoLondonSpaceId);
    final offer = (await passes.offers(demoLondonSpaceId)).firstWhere((o) => o.unit == GuestPassUnit.hour);
    final slot = freeSeatForPass(fixture.london.floorPlan.seats, fixture.london.reservations.reservations, aDay(22),
        startMinutes: 600, endMinutes: 660);
    final draft = GuestPassDraft(offer: offer, seatId: slot.seatId, day: slot.day, startMinutes: 600, endMinutes: 660);
    const guest = {'first_name': 'Rita', 'last_name': 'Retry'};
    final a = await passes.sell(demoLondonSpaceId, draft: draft, guest: guest, requestId: 'r-same');
    final invoices = fixture.london.money.invoices.length;
    final b = await passes.sell(demoLondonSpaceId, draft: draft, guest: guest, requestId: 'r-same');
    expect(b.passId, a.passId);
    expect(b.replayed, isTrue);
    expect(fixture.london.money.invoices.length, invoices);
  });

  test('a persona without issueInvoices cannot sell a pass', () async {
    fixture.becomePersona(DemoPersona.member);
    final passes = await enter(demoLondonSpaceId);
    final offer = (await passes.offers(demoLondonSpaceId)).first;
    await expectLater(
      passes.sell(
        demoLondonSpaceId,
        draft: GuestPassDraft(offer: offer, seatId: fixture.london.floorPlan.seats.first.id, day: aDay(23), startMinutes: 540, endMinutes: 600),
        guest: const {'first_name': 'No', 'last_name': 'Sale'},
        requestId: 'r-refused',
      ),
      throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '42501')),
    );
  });

  test('the London journey sells at any Demo clock: the seat and day come from the fixture', () async {
    for (final now in [demoSeedNow, demoSeedNow.add(const Duration(days: 47, hours: 5))]) {
      final f = DemoFixture.build(now: now);
      final passes = FakeGuestPassRepository(
        workspaceId: demoLondonSpaceId,
        currency: 'GBP',
        reservations: f.london.reservations,
        workspaces: f.london.workspaces,
        money: f.london.money,
        now: () => f.seededAt,
        maySell: () => true,
        mayPrice: () => true,
        floorPlanSeats: () => f.london.floorPlan.seats,
        offers: const [GuestPassOffer(id: 'd', name: 'Day pass', unit: GuestPassUnit.day, priceCents: 2500)],
      );
      final from = DateTime(f.seededAt.year, f.seededAt.month, f.seededAt.day + 20);
      final slot = freeSeatForPass(f.london.floorPlan.seats, f.london.reservations.reservations, from,
          days: 2, startMinutes: 540, endMinutes: 1080);
      final sale = await passes.sell(demoLondonSpaceId,
          draft: GuestPassDraft(offer: (await passes.offers(demoLondonSpaceId)).single, seatId: slot.seatId,
              day: slot.day, startMinutes: 540, endMinutes: 1080, days: 2),
          guest: const {'first_name': 'Clock', 'last_name': 'Proof'},
          requestId: 'clock-$now');
      expect(sale.reservationIds, hasLength(2), reason: 'at $now');
    }
  });
}
