// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3843 — the Demo's reference business (Atelier du Marché, ws-1) answers
// what each booking of a period is charged by the rules of `booking_prices`
// over its own data: every booking of the month has one price; a room's
// charge is its price per half-day times the half-days it spans, in the
// business's currency; a booking a carnet covers says carnet; a seat booking
// of a member's month says subscription or extra half-days by that month's
// own statement; and a member reads only their own bookings' prices.
import 'package:deskilo/core/demo/data/demo_booking_prices.dart';
import 'package:deskilo/core/demo/demo_clock.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_spaces.dart';
import 'package:deskilo/features/reservations/domain/booking_price.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show yearMonth;
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = demoSeedNow;
  final fixture = DemoFixture.build(now: now);
  const key = DemoSpaceKey.home;
  final space = fixture.space(key);
  final from = DateTime(now.year, now.month);
  final to = DateTime(now.year, now.month + 1);

  DemoBookingPriceReads reads({bool all = true, String? me}) =>
      DemoBookingPriceReads(
        reservations: space.reservations,
        plan: space.floorPlan,
        credits: space.credits,
        passes: () =>
            fixture.stores.at(key).guestPasses.repository.passesSold(key.id),
        statement: space.money.fetchStatement,
        currency: key.currency,
        readsAll: () => all,
        me: () => me,
      );

  List<Reservation> counted({String? member}) => [
    for (final r in space.reservations.reservations)
      if (r.workspaceId == key.id &&
          r.status != ReservationStatus.cancelled &&
          r.status != ReservationStatus.released &&
          r.startsAt.isBefore(to) &&
          r.endsAt.isAfter(from) &&
          (member == null || r.memberId == member))
        r,
  ];

  test('every booking of the month has one price, and the month shows more '
      'than one kind', () async {
    final prices = await reads().prices(key.id, from: from, to: to);
    final ids = {for (final p in prices) p.reservationId};
    expect(ids, {for (final r in counted()) r.id});
    expect(ids.length, prices.length, reason: 'one price per booking');
    expect({for (final p in prices) p.kind}.length, greaterThan(1));
  });

  test('a charge is its room\'s price per half-day times the half-days, in '
      'the business\'s currency', () async {
    final prices = await reads().prices(key.id, from: from, to: to);
    final byId = {for (final r in counted()) r.id: r};
    for (final p in prices.where((p) => p.kind == BookingPriceKind.charge)) {
      final r = byId[p.reservationId]!;
      final room = space.floorPlan.offices.firstWhere(
        (o) => o.id == r.officeId,
      );
      final halfDays = (r.endsAt.difference(r.startsAt).inMinutes / 240).ceil();
      expect(p.amountCents, room.priceCents * halfDays, reason: r.id);
      expect(p.currency, key.currency);
    }
  });

  test(
    'a seat booking says the month as its member\'s statement has it',
    () async {
      final prices = await reads().prices(key.id, from: from, to: to);
      final byId = {for (final r in counted()) r.id: r};
      for (final p in prices.where(
        (p) =>
            p.kind == BookingPriceKind.subscription ||
            p.kind == BookingPriceKind.overage,
      )) {
        final r = byId[p.reservationId]!;
        final month = yearMonth(r.startsAt.year, r.startsAt.month);
        final extra = (await space.money.fetchStatement(
          r.memberId,
          month,
        )).extraHalfDays;
        expect(
          p.kind,
          extra > 0 ? BookingPriceKind.overage : BookingPriceKind.subscription,
          reason: '${r.id} in $month',
        );
      }
    },
  );

  test('a member reads only their own bookings\' prices', () async {
    final member = counted().first.memberId;
    final prices = await reads(
      all: false,
      me: member,
    ).prices(key.id, from: from, to: to);
    expect(
      {for (final p in prices) p.reservationId},
      {for (final r in counted(member: member)) r.id},
    );
  });
}
