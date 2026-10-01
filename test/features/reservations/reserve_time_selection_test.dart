// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2016 — reserving from the hub needs no header workaround. A free seat on
// the live hub opens on RESERVE with its period editable; checking in now
// is an explicit choice in the same sheet, and what is written is what was
// confirmed there — never a flag the caller captured before the sheet
// opened. A header pre-selection only sets the starting window; "Back to
// now" is a named action that returns to live without removing the
// reservation path; cancelling writes nothing. Driven through the real
// hub with real taps, at a fixed instant one hour into the morning half
// (so the morning contains now and the afternoon is still ahead).
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/plan/domain/half_day_windows.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/presentation/widgets/booking_sheet.dart';
import 'package:deskilo/features/workspace/domain/booking_granularity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_reservation_repository.dart';
import 'reserve_hub_test.dart' show pumpHub, seatCenter;

final _day = DateTime(2026, 5, 13);
HalfDayWindow get _am => HalfDayWindows.morning(_day);
HalfDayWindow get _pm => HalfDayWindows.afternoon(_day);

/// One hour into the morning half, on the workspace clock.
Clock get _clock => FixedClock(_am.start.add(const Duration(hours: 1)));

Finder _key(String k) => find.byKey(ValueKey(k));

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(_key(key));
  await tester.pumpAndSettle();
  await tester.tap(_key(key));
  await tester.pumpAndSettle();
}

Future<void> _openSeat(WidgetTester tester) async {
  await tester.tapAt(seatCenter(tester));
  await tester.pumpAndSettle();
  expect(find.byType(BookingSheet), findsOneWidget);
}

Future<void> _confirm(WidgetTester tester) => _tap(tester, 'booking-confirm');

bool _selected(WidgetTester tester, String key) =>
    tester.widget<ChoiceChip>(_key(key)).selected;

Reservation _single(FakeReservationRepository repo) => repo.reservations.single;

void _expectWindow(Reservation r, HalfDayWindow w) {
  expect(r.startsAt.toUtc(), w.start.toUtc());
  expect(r.endsAt.toUtc(), w.end.toUtc());
}

void main() {
  group('half-day workspace', () {
    testWidgets('T01 — fresh hub, free seat: Reserve with the period '
        'editable, no header pre-click; Afternoon writes 13:00-style '
        'afternoon, not a check-in', (tester) async {
      final repo = await pumpHub(
        tester,
        granularity: BookingGranularity.halfDay,
        clock: _clock,
      );
      await _openSeat(tester);

      // Reserve is the default action, and the period is right here.
      expect(_key('booking-mode'), findsOneWidget);
      expect(
        tester.widget<SegmentedButton<bool>>(_key('booking-mode')).selected,
        {false},
      );
      expect(_key('booking-pm'), findsOneWidget);
      expect(find.textContaining('Starts now'), findsNothing);

      await _tap(tester, 'booking-pm');
      await _confirm(tester);

      final created = _single(repo);
      _expectWindow(created, _pm);
      expect(created.status, ReservationStatus.reserved);
      expect(created.checkedInAt, isNull);
    });

    testWidgets('T02 — a header Afternoon pre-selects; switching to '
        'Morning in the sheet writes Morning', (tester) async {
      final repo = await pumpHub(
        tester,
        granularity: BookingGranularity.halfDay,
        clock: _clock,
      );
      await _tap(tester, 'reserve-pm-chip');
      await _openSeat(tester);
      expect(_selected(tester, 'booking-pm'), isTrue);

      await _tap(tester, 'booking-am');
      await _confirm(tester);
      _expectWindow(_single(repo), _am);
    });

    testWidgets('T03 — Morning, then Back to now, then a seat: the period '
        'is still offered; repeated, no leftover mode; cancel writes '
        'nothing', (tester) async {
      final repo = await pumpHub(
        tester,
        granularity: BookingGranularity.halfDay,
        clock: _clock,
      );
      for (var i = 0; i < 2; i++) {
        await _tap(tester, 'reserve-am-chip');
        expect(_key('reserve-now-button'), findsOneWidget);
        await _tap(tester, 'reserve-now-button');
        expect(
          _key('reserve-now-button'),
          findsNothing,
          reason: 'back on live, the action hides',
        );
        await _openSeat(tester);
        expect(_key('booking-mode'), findsOneWidget);
        expect(_key('booking-am'), findsOneWidget);
        expect(_key('booking-pm'), findsOneWidget);
        // Dismiss the sheet (a swipe-down pops it with no choice):
        // nothing is written.
        Navigator.of(tester.element(find.byType(BookingSheet))).pop();
        await tester.pumpAndSettle();
        expect(find.byType(BookingSheet), findsNothing);
      }
      expect(repo.reservations, isEmpty);
      expect(repo.createCalls, 0);
    });

    testWidgets('T05 — Check in now, back to Reserve, confirm: a plain '
        'reservation (the final mode decides)', (tester) async {
      final repo = await pumpHub(
        tester,
        granularity: BookingGranularity.halfDay,
        clock: _clock,
      );
      await _openSeat(tester);
      await _tap(tester, 'booking-mode-check-in');
      expect(find.textContaining('Starts now'), findsOneWidget);
      expect(
        _key('booking-pm'),
        findsNothing,
        reason: 'a walk-up keeps its computed end',
      );
      await _tap(tester, 'booking-mode-reserve');
      await _tap(tester, 'booking-pm');
      await _confirm(tester);

      final created = _single(repo);
      _expectWindow(created, _pm);
      expect(created.checkedInAt, isNull);
    });

    testWidgets('T05 — Check in now, confirmed, checks in', (tester) async {
      final repo = await pumpHub(
        tester,
        granularity: BookingGranularity.halfDay,
        clock: _clock,
      );
      await _openSeat(tester);
      await _tap(tester, 'booking-mode-check-in');
      await _confirm(tester);

      final created = _single(repo);
      expect(created.status, ReservationStatus.checkedIn);
      expect(created.checkedInAt, isNotNull);
    });

    testWidgets('T06 — a later booking on the seat: the overlapping '
        'Afternoon cannot be confirmed; the Morning still can', (tester) async {
      final later = _pm.start.add(const Duration(hours: 1));
      final repo = await pumpHub(
        tester,
        granularity: BookingGranularity.halfDay,
        clock: _clock,
        seed: [
          Reservation(
            id: 'res-later',
            workspaceId: 'ws-1',
            seatId: 'seat-4',
            memberId: 'member-2',
            startsAt: later,
            endsAt: later.add(const Duration(hours: 2)),
            status: ReservationStatus.reserved,
          ),
        ],
      );
      await _openSeat(tester);
      await _tap(tester, 'booking-pm');
      expect(_key('booking-overlap'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(_key('booking-confirm')).onPressed,
        isNull,
      );

      await _tap(tester, 'booking-am');
      expect(_key('booking-overlap'), findsNothing);
      await _confirm(tester);
      expect(
        repo.reservations.where((r) => r.id != 'res-later').single.seatId,
        'seat-4',
      );
    });

    testWidgets('T07 — "check in right away" follows the EDITED window: '
        'offered for the morning (contains now), gone for the afternoon', (
      tester,
    ) async {
      await pumpHub(
        tester,
        granularity: BookingGranularity.halfDay,
        clock: _clock,
      );
      await _openSeat(tester);
      await _tap(tester, 'booking-am');
      expect(_key('booking-check-in-now'), findsOneWidget);
      await _tap(tester, 'booking-pm');
      expect(_key('booking-check-in-now'), findsNothing);
    });
  });

  testWidgets('T04 — hours workspace: From/Until are offered on a direct '
      'open, without a header shortcut, and nothing checks in by default', (
    tester,
  ) async {
    final repo = await pumpHub(
      tester,
      granularity: BookingGranularity.hours,
      clock: _clock,
    );
    await _openSeat(tester);
    expect(_key('booking-from-tile'), findsOneWidget);
    expect(_key('booking-until-tile'), findsOneWidget);
    expect(_key('booking-pm'), findsOneWidget);
    await _tap(tester, 'booking-pm');
    await _confirm(tester);
    final created = _single(repo);
    _expectWindow(created, _pm);
    expect(created.checkedInAt, isNull);
  });

  testWidgets('T09 — Back to now is named: a visible word, the full action '
      'for screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpHub(
      tester,
      granularity: BookingGranularity.halfDay,
      clock: _clock,
    );
    await _tap(tester, 'reserve-am-chip');
    expect(
      find.descendant(
        of: _key('reserve-now-button'),
        matching: find.text('Now'),
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Back to now'), findsOneWidget);
    handle.dispose();
  });
}
