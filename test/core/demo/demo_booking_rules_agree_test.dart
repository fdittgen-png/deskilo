// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4284 — what the Demo offers a member is what the Demo's rules accept.
//
// 1. A booking made for the window that is current on the Demo's clock (ten
//    o'clock in Paris, whatever the zone of the device) can be checked in: the
//    repository judges "over" on the same clock the screens show.
// 2. The start card states the business's own limit on bookings held at once,
//    and the repository enforces that same limit: with the Demo's two, a
//    second place in the window is taken and a third refused; with one, the
//    second is refused and the card says one.
import 'package:deskilo/core/codes/dk_code.dart';
import 'package:deskilo/core/demo/demo_clock.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/domain/reservation_refusal.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/screens/demo_journeys.dart' show pumpDemo;
import '../../helpers/screens/reserve_hub.dart' show seatCenter;

final _en = AppLocalizationsEn();

/// The card's sentence about the limit, which the card prints beside its
/// other lines.
Finder _said(int count) => find.descendant(
  of: find.byKey(const ValueKey('getting-started-card')),
  matching: find.textContaining(_en.gettingStartedAllowance(count)),
);

/// Seats nobody holds in [start, end).
List<String> _freeSeats(DemoFixture fixture, DateTime start, DateTime end) => [
  for (final seat in fixture.floorPlan.seats)
    if (!fixture.reservations.reservations.any(
      (r) =>
          r.seatId == seat.id &&
          r.isActive &&
          start.isBefore(r.endsAt) &&
          r.startsAt.isBefore(end),
    ))
      seat.id,
];

void main() {
  late DemoFixture fixture;
  late DateTime start;
  late DateTime end;

  setUp(() {
    fixture = DemoFixture.build()..becomePersona(DemoPersona.member);
    // The window that is current on the Demo's clock: one hour from now.
    start = fixture.seededAt;
    end = start.add(const Duration(hours: 1));
  });

  Future<String> book(String seat) => fixture.reservations.create(
    workspaceId: 'ws-1',
    seatId: seat,
    startsAt: start,
    endsAt: end,
  );

  test('the Demo judges a booking on the clock its screens show', () {
    expect(fixture.reservations.now(), fixture.seededAt);
    expect(fixture.seededAt, demoSeedNow);
  });

  test('a booking made for the current window can be checked in', () async {
    final seat = _freeSeats(fixture, start, end).first;
    final id = await book(seat);

    await fixture.reservations.checkIn(id);

    final held = fixture.reservations.reservations.singleWhere(
      (r) => r.id == id,
    );
    expect(held.status, ReservationStatus.checkedIn);
  });

  test('the repository enforces the limit the policy configures: two places '
      'in the window with the Demo\'s two, a third refused', () async {
    final seats = _freeSeats(fixture, start, end);
    await book(seats[0]);
    await book(seats[1]);

    await expectLater(
      book(seats[2]),
      throwsA(
        isA<ReservationRefused>().having(
          (e) => e.refusal.code,
          'code',
          DkCode.dkk19,
        ),
      ),
    );
  });

  test('with the limit lowered to one the second place is refused', () async {
    await fixture.workspaces.setSimultaneousReservations('ws-1', 1);
    final seats = _freeSeats(fixture, start, end);
    await book(seats[0]);

    await expectLater(
      book(seats[1]),
      throwsA(
        isA<ReservationRefused>().having(
          (e) => e.refusal.code,
          'code',
          DkCode.dkk19,
        ),
      ),
    );
  });

  testWidgets('the start card states the configured limit, and no other', (
    tester,
  ) async {
    final journey = await pumpDemo(tester, persona: DemoPersona.member);

    // The Demo's policy says two, the card says two — and the repository
    // takes two (above): the card never promises more than the Demo accepts.
    expect(_said(2), findsOneWidget);
    expect(_said(1), findsNothing);

    // The owner lowers the limit to one: the card says one, from the same
    // setting the repository reads.
    await journey.fixture.workspaces.setSimultaneousReservations('ws-1', 1);
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
        .invalidate(bookingPoliciesProvider);
    await tester.pumpAndSettle();
    expect(_said(1), findsOneWidget);
    expect(_said(2), findsNothing);
  });

  testWidgets('journey: the window the hub offers now is booked, and its own '
      'sheet checks it in', (tester) async {
    final journey = await pumpDemo(tester, persona: DemoPersona.member);
    final repo = journey.fixture.reservations;
    final before = repo.reservations.length;

    await tester.tapAt(seatCenter(tester));
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('booking-confirm')));
    await tester.pumpAndSettle();
    expect(repo.reservations.length, before + 1);
    final booked = repo.reservations.last;
    expect(booked.status, ReservationStatus.reserved);

    await tester.tapAt(seatCenter(tester));
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith(
              'check-in-sheets-plan-check-in-button',
            ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      repo.reservations.singleWhere((r) => r.id == booked.id).status,
      ReservationStatus.checkedIn,
      reason: 'what the sheet offered is what the Demo accepted',
    );
  });
}
