// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3843 — the desk calendar's bookings table says what each booking was or
// will be charged: a room's charge with its amount in the business's currency,
// a pass, a carnet, free, the subscription, or the month's extra half-days.
// The period's prices are asked for ONCE, after the table has drawn, never per
// row; the charges are added up under the table per currency, never across
// currencies; the export carries the column.
import 'package:deskilo/app/desk_calendar/bookings_csv.dart';
import 'package:deskilo/app/desk_calendar/desk_bookings_table.dart';
import 'package:deskilo/features/reservations/domain/booking_price.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/providers/booking_price_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

Reservation _r(String id, {String member = 'm1', int day = 12}) => Reservation(
  id: id,
  workspaceId: 'ws-1',
  seatId: 'seat-$id',
  memberId: member,
  startsAt: DateTime(2026, 11, day, 9),
  endsAt: DateTime(2026, 11, day, 13),
  status: ReservationStatus.reserved,
);

final _bookings = [
  for (final id in ['a', 'b', 'c', 'd', 'e', 'f', 'g']) _r(id),
];

const _prices = [
  BookingPrice(
    reservationId: 'a',
    kind: BookingPriceKind.charge,
    amountCents: 6500,
    currency: 'EUR',
  ),
  BookingPrice(
    reservationId: 'b',
    kind: BookingPriceKind.charge,
    amountCents: 3500,
    currency: 'EUR',
  ),
  BookingPrice(
    reservationId: 'c',
    kind: BookingPriceKind.charge,
    amountCents: 4000,
    currency: 'CHF',
  ),
  BookingPrice(reservationId: 'd', kind: BookingPriceKind.pass),
  BookingPrice(reservationId: 'e', kind: BookingPriceKind.carnet),
  BookingPrice(reservationId: 'f', kind: BookingPriceKind.subscription),
  BookingPrice(reservationId: 'g', kind: BookingPriceKind.overage),
];

class _Counting implements BookingPriceReads {
  int calls = 0;

  @override
  Future<List<BookingPrice>> prices(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
  }) async {
    calls++;
    return _prices;
  }
}

final _period = (
  workspaceId: 'ws-1',
  from: DateTime(2026, 11, 9),
  to: DateTime(2026, 11, 16),
);

Widget _table({BookingPricePeriod? period}) => Scaffold(
  body: DeskBookingsTable(
    bookings: _bookings,
    names: const {'m1': 'Ada'},
    placeNames: const {},
    onOpen: (_) {},
    period: period,
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the period is read once, after the table has drawn, and each '
      'booking says its price', (tester) async {
    final reads = _Counting();
    await pumpApp(
      tester,
      _table(period: _period),
      size: const Size(1440, 900),
      overrides: [
        ...standardTestOverrides(),
        bookingPriceReadsProvider.overrideWithValue(reads),
      ],
    );
    // The first frame draws the table and asks nothing yet.
    expect(reads.calls, 0);
    await tester.pumpAndSettle();
    expect(reads.calls, 1);
    for (final word in ['Pass', 'Carnet', 'Subscription', 'Extra half-day']) {
      expect(find.text(word), findsOneWidget, reason: word);
    }
    expect(find.textContaining('Charge'), findsNWidgets(3));
    // A rebuild (a sort) does not ask again.
    await tester.tap(find.text('Price'));
    await tester.pumpAndSettle();
    expect(reads.calls, 1);
  });

  testWidgets('the charges are added up under the table per currency, never '
      'across currencies', (tester) async {
    await pumpApp(
      tester,
      _table(period: _period),
      size: const Size(1440, 900),
      overrides: [
        ...standardTestOverrides(),
        bookingPriceReadsProvider.overrideWithValue(_Counting()),
      ],
    );
    await tester.pumpAndSettle();
    final footer = [
      for (final t in tester.widgetList<Text>(find.byType(Text)))
        t.data ?? t.textSpan?.toPlainText() ?? '',
    ].where((t) => t.contains('100.00') || t.contains('40.00')).join(' ');
    expect(footer, contains('100.00'), reason: 'EUR 65 + 35');
    expect(footer, contains('40.00'), reason: 'CHF 40 on its own');
    expect(footer, isNot(contains('140.00')));
  });

  testWidgets('without a period the table shows no price column', (
    tester,
  ) async {
    final reads = _Counting();
    await pumpApp(
      tester,
      _table(),
      size: const Size(1440, 900),
      overrides: [
        ...standardTestOverrides(),
        bookingPriceReadsProvider.overrideWithValue(reads),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('Price'), findsNothing);
    expect(reads.calls, 0);
  });

  test('a row of the read: a known kind with its amount; an unknown one is '
      'left out', () {
    final charge = BookingPrice.fromRow({
      'reservation_id': 'r1',
      'member_id': 'm1',
      'kind': 'charge',
      'amount_cents': 6500,
      'currency': 'EUR',
    })!;
    expect(charge.isCharge, isTrue);
    expect(charge.amountCents, 6500);
    expect(
      BookingPrice.fromRow({'reservation_id': 'r2', 'kind': 'subscription'})!
          .isCharge,
      isFalse,
    );
    expect(
      BookingPrice.fromRow({'reservation_id': 'r3', 'kind': 'gift'}),
      isNull,
    );
  });

  test('the export carries the price as the table says it', () {
    final l10n = AppLocalizationsEn();
    final bytes = bookingsCsv(
      _bookings.take(2).toList(),
      header: (
        member: 'M',
        place: 'P',
        from: 'F',
        to: 'T',
        state: 'S',
        price: l10n.calendarDeskColumnPrice,
      ),
      who: (_) => 'Ada',
      place: (_) => 'Seat',
      at: (i) => i.toUtc().toIso8601String(),
      state: (_) => 'Reserved',
      price: (r) => bookingPriceText(
        l10n,
        (code, minor) => '$code ${(minor / 100).toStringAsFixed(2)}',
        _prices.firstWhere((p) => p.reservationId == r.id),
      ),
    );
    final lines = String.fromCharCodes(bytes.sublist(3)).split('\r\n');
    expect(lines.first, endsWith('"Price"'));
    expect(lines[1], endsWith('"Charge EUR 65.00"'));
  });
}
