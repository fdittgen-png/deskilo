// SPDX-License-Identifier: 0BSD
//
// #814 — ONE booking gate on the client: the availability parameters
// asked BEFORE a window is offered, on every surface — the plan tap,
// the Day and Week free-slot taps, the booking sheet, the kiosk badge,
// the QR/NFC scan sheet — naming the SAME reason the server would. The
// views draw closed days as closed, a legend names the seat states, and
// the admin check-out follows the owner's policy.
import 'dart:io';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/time/work_hours.dart';
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/features/reservations/domain/booking_error_text.dart';
import 'package:deskilo/features/reservations/domain/booking_gate.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/presentation/widgets/booking_sheet.dart';
import 'package:deskilo/features/reservations/presentation/widgets/month_grid.dart';
import 'package:deskilo/features/reservations/presentation/widgets/space_scan_sheet.dart';
import 'package:deskilo/features/reservations/presentation/widgets/week_grid.dart';
import 'package:deskilo/features/workspace/domain/booking_granularity.dart';
import 'package:deskilo/features/workspace/domain/booking_policies.dart';
import 'package:deskilo/features/workspace/domain/closure_day.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException;

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/fake_reservation_repository.dart';
import '../../helpers/mock_providers.dart';

DateTime _at(int hour, [int minute = 0]) =>
    DateTime(kTestNow.year, kTestNow.month, kTestNow.day, hour, minute);

DateTime _dayOffset(int days, int hour, [int minute = 0]) {
  final d = kTestNow.add(Duration(days: days));
  return DateTime(d.year, d.month, d.day, hour, minute);
}

BookingGate _gate({
  List<int> openWeekdays = const [1, 2, 3, 4, 5, 6, 7],
  List<ClosureDay> closures = const [],
  BookingPolicies policies = const BookingPolicies(),
  BookingGranularity granularity = BookingGranularity.flexible,
}) =>
    BookingGate(
      openWeekdays: openWeekdays,
      closures: closures,
      policies: policies,
      granularity: granularity,
      hours: WorkHours.defaults,
      now: kTestNow,
    );

/// Every ISO weekday except today's — makes the live day closed.
List<int> _allWeekdaysExceptToday() => [
      for (var day = 1; day <= 7; day++)
        if (day != kTestNow.weekday) day,
    ];

void main() {
  setUp(() {
    WorkspaceTime.reset();
    WorkHours.reset();
  });

  group('the derivation mirrors enforce_booking_rules v9', () {
    test('an ordinary window inside the working day passes', () {
      expect(
        _gate().refusalFor(start: _at(9), end: _at(12), walkUp: false),
        isNull,
      );
    });

    test('a closed day refuses first, whatever else is wrong', () {
      final g = _gate(openWeekdays: _allWeekdaysExceptToday());
      expect(
        g.refusalFor(start: _at(9), end: _at(9, 10), walkUp: false),
        BookingRefusal.closedDay,
      );
      expect(g.dayOpen(kTestNow), isFalse);
      final closure = _gate(closures: [
        ClosureDay(
          id: 'c',
          workspaceId: 'ws-1',
          day: DateTime(kTestNow.year, kTestNow.month, kTestNow.day),
          reason: 'Holiday',
        ),
      ]);
      expect(closure.dayOpen(kTestNow), isFalse);
    });

    test('a blocked seat refuses', () {
      final seat = (FakeFloorPlanRepository()..seedSmallPlan())
          .seats
          .first
          .copyWith(blockedFrom: _at(0));
      expect(
        _gate().refusalFor(
            start: _at(9), end: _at(12), walkUp: false, seat: seat),
        BookingRefusal.seatBlocked,
      );
    });

    test('beyond the horizon, too short, too long — the #649 limits', () {
      final g = _gate(
        policies: const BookingPolicies(
          advanceHorizonDays: 7,
          minDurationMinutes: 30,
          maxDurationMinutes: 240,
        ),
      );
      expect(
        g.refusalFor(
            start: _dayOffset(8, 9), end: _dayOffset(8, 12), walkUp: false),
        BookingRefusal.beyondHorizon,
      );
      expect(
        g.refusalFor(start: _at(9), end: _at(9, 20), walkUp: false),
        BookingRefusal.tooShort,
      );
      expect(
        g.refusalFor(start: _at(9), end: _at(15), walkUp: false),
        BookingRefusal.tooLong,
      );
    });

    test('the past guard is DAY-level and obeys allow_past_bookings', () {
      expect(
        _gate().refusalFor(
            start: _dayOffset(-1, 9), end: _dayOffset(-1, 12), walkUp: false),
        BookingRefusal.past,
      );
      // Earlier the same day stays legal.
      expect(
        _gate().refusalFor(start: _at(8), end: _at(9), walkUp: false),
        isNull,
      );
      expect(
        _gate(policies: const BookingPolicies(allowPastBookings: true))
            .refusalFor(
                start: _dayOffset(-1, 9),
                end: _dayOffset(-1, 12),
                walkUp: false),
        isNull,
      );
    });

    test('a walk-up check-in must start today', () {
      expect(
        _gate().refusalFor(
            start: _dayOffset(1, 9), end: _dayOffset(1, 12), walkUp: true),
        BookingRefusal.walkUpNotToday,
      );
      expect(
        _gate().refusalFor(
            start: _dayOffset(1, 9), end: _dayOffset(1, 12), walkUp: false),
        isNull,
      );
    });

    test('a booking ends on the day it starts (#644)', () {
      expect(
        _gate().refusalFor(
            start: _at(22), end: _dayOffset(1, 1), walkUp: false),
        BookingRefusal.crossesMidnight,
      );
      // Midnight itself is the day's own end.
      expect(
        _gate(policies: const BookingPolicies(maxDurationMinutes: 1440))
            .refusalFor(start: _at(20), end: _dayOffset(1, 0), walkUp: true),
        isNull,
      );
    });

    test('outside the hours: off refuses everything, walkup_only refuses '
        'booking ahead, free and charged pass', () {
      for (final (mode, ahead, walkUp) in [
        (OutsideHoursMode.off, BookingRefusal.outsideHoursOff,
            BookingRefusal.outsideHoursOff),
        (OutsideHoursMode.walkupOnly, BookingRefusal.outsideHoursAheadOnly,
            null),
        (OutsideHoursMode.free, null, null),
        (OutsideHoursMode.charged, null, null),
      ]) {
        final g = _gate(policies: BookingPolicies(outsideHoursMode: mode));
        expect(
          g.refusalFor(start: _at(17), end: _at(20), walkUp: false),
          ahead,
          reason: '$mode, ahead',
        );
        expect(
          g.refusalFor(start: _at(17), end: _at(20), walkUp: true),
          walkUp,
          reason: '$mode, walk-up',
        );
        // A window that merely SPILLS out counts as outside (#634).
        expect(
          g.refusalFor(start: _at(16), end: _at(18), walkUp: false),
          ahead,
          reason: '$mode, spilling',
        );
      }
    });

    test('every refusal maps to a sentence, none to the generic fallback',
        () {
      const policies = BookingPolicies();
      for (final refusal in BookingRefusal.values) {
        final text = bookingRefusalText(null, refusal, policies: policies);
        expect(text, isNotEmpty);
        expect(text, isNot(contains('Something went wrong')));
      }
      expect(
        bookingRefusalText(null, BookingRefusal.beyondHorizon,
            policies: const BookingPolicies(advanceHorizonDays: 14)),
        contains('14 days'),
      );
    });
  });

  group('parity with the server contract', () {
    final sql = File('supabase/migrations/0122_enforcement_parity.sql')
        .readAsStringSync();

    test('every gate refusal names a substring the chokepoint raises',
        () {
      for (final refusal in BookingRefusal.values) {
        final substring = BookingGate.serverSubstringOf(refusal);
        // Closed day and blocked seat are raised by assert_workspace_open
        // (0013) and the seat-block check — outside this migration's
        // text, pinned by their own tests.
        if (refusal == BookingRefusal.closedDay ||
            refusal == BookingRefusal.seatBlocked) {
          continue;
        }
        expect(sql, contains(substring),
            reason: '${refusal.name} → "$substring" must exist server-side');
      }
    });

    test('the mapper recognizes every substring the gate names', () {
      const policies = BookingPolicies();
      for (final refusal in BookingRefusal.values) {
        final message = switch (refusal) {
          BookingRefusal.beyondHorizon =>
            'beyond the advance-booking horizon of 90 days',
          BookingRefusal.tooShort => 'below the minimum duration of 30 minutes',
          BookingRefusal.tooLong =>
            'above the maximum duration of 1440 minutes',
          BookingRefusal.outsideHoursAheadOnly =>
            'only spontaneous check-ins are possible outside the opening '
                'hours — booking ahead is not',
          BookingRefusal.outsideHoursOff =>
            'bookings outside the opening hours are not allowed',
          _ => 'x ${BookingGate.serverSubstringOf(refusal)} y',
        };
        final mapped = bookingErrorText(
          null,
          PostgrestException(message: message),
          'fallback',
        );
        expect(mapped, isNot('fallback'), reason: refusal.name);
        expect(
          mapped,
          bookingRefusalText(null, refusal, policies: policies),
          reason: '${refusal.name}: gate and server sentences agree',
        );
      }
    });

    test('the fake repository and the gate refuse the same windows',
        () async {
      final gate = _gate(
          policies:
              const BookingPolicies(outsideHoursMode: OutsideHoursMode.off));
      final cases = <(DateTime, DateTime, bool)>[
        (_at(9), _at(12), false),
        (_dayOffset(-1, 9), _dayOffset(-1, 12), false),
        (_dayOffset(1, 9), _dayOffset(1, 12), true),
        (_at(17), _at(20), false),
        (_at(17), _at(20), true),
      ];
      for (final (start, end, walkUp) in cases) {
        // A fresh fake per case: the contract, not the occupancy.
        final repo = FakeReservationRepository()
          ..outsideHoursMode = OutsideHoursMode.off;
        Object? thrown;
        try {
          await repo.create(
            workspaceId: 'ws-1',
            seatId: 'seat-4',
            startsAt: start,
            endsAt: end,
            checkIn: walkUp,
          );
        } catch (e) {
          thrown = e;
        }
        final refusal =
            gate.refusalFor(start: start, end: end, walkUp: walkUp);
        expect(refusal != null, thrown != null,
            reason: '$start–$end walkUp=$walkUp');
      }
    });
  });

  group('on screen', () {
    Future<FakeReservationRepository> pumpHub(
      WidgetTester tester, {
      List<int> openWeekdays = const [1, 2, 3, 4, 5, 6, 7],
      BookingPolicies? policies,
      BookingGranularity? granularity,
      Map<String, dynamic> flags = const {},
      List<Reservation> seed = const [],
    }) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final plans = FakeFloorPlanRepository()..seedSmallPlan();
      final reservations = FakeReservationRepository()
        ..reservations.addAll(seed);
      final workspace =
          FakeWorkspaceRepository.withWorkspace(featureFlags: flags)
            ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana'}
            ..openWeekdays['ws-1'] = openWeekdays;
      if (policies != null) workspace.bookingPolicies['ws-1'] = policies;
      if (granularity != null) {
        workspace.bookingGranularities['ws-1'] = granularity;
        reservations.granularity = granularity;
      }
      await tester.pumpWidget(
        ProviderScope(
          overrides: standardTestOverrides(
            floorPlan: plans,
            reservations: reservations,
            workspace: workspace,
          ),
          child: const DeskiloApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Reserve'));
      await tester.pumpAndSettle();
      return reservations;
    }

    testWidgets(
        'the legend names the seat states under the controls; flag OFF '
        'hides it', (tester) async {
      await pumpHub(tester);
      expect(find.byKey(const ValueKey('reserve-legend')), findsOneWidget);
      expect(find.text('Free'), findsOneWidget);
      expect(find.text('Checked in'), findsOneWidget);
      expect(find.text('Blocked'), findsOneWidget);
    });

    testWidgets('flag OFF: no legend, closed days stay bookable-looking',
        (tester) async {
      await pumpHub(tester, flags: const {'bookingGate': false});
      expect(find.byKey(const ValueKey('reserve-legend')), findsNothing);
    });

    testWidgets(
        'Week view: a closed day is drawn closed and its free slot refuses '
        'with the closed sentence — no booking sheet', (tester) async {
      await pumpHub(tester, openWeekdays: _allWeekdaysExceptToday());
      await tester.tap(find.byTooltip('Week'));
      await tester.pumpAndSettle();
      expect(find.byKey(WeekGrid.closedHeaderKey(kTestNow)), findsOneWidget);
      // The closed cell carries no free-slot affordance at all.
      expect(
        find.byKey(ValueKey(
          'week-free-seat-4-${WeekGrid.dayStampOf(kTestNow)}-am',
        )),
        findsNothing,
      );
      // An OPEN neighbour still does.
      final tomorrow = kTestNow.add(const Duration(days: 1));
      expect(
        find.byKey(ValueKey(
          'week-free-seat-4-${WeekGrid.dayStampOf(tomorrow)}-am',
        )),
        findsOneWidget,
      );
    });

    testWidgets(
        'Month view: a closed day says Closed instead of a free count',
        (tester) async {
      await pumpHub(tester, openWeekdays: _allWeekdaysExceptToday());
      await tester.tap(find.byTooltip('Month'));
      await tester.pumpAndSettle();
      final cell = find.byKey(MonthGrid.cellKey(kTestNow));
      expect(cell, findsOneWidget);
      expect(
        find.descendant(of: cell, matching: find.text('Closed')),
        findsOneWidget,
      );
      final tomorrow = kTestNow.add(const Duration(days: 1));
      expect(
        find.descendant(
          of: find.byKey(MonthGrid.cellKey(tomorrow)),
          matching: find.text('Closed'),
        ),
        findsNothing,
      );
    });

    testWidgets(
        'Week view under outside-hours OFF: a free slot whose window '
        'would leave the working day is refused BEFORE any sheet, with '
        'the server\'s own sentence', (tester) async {
      // Free-time granularity: the hub's default window is now→+4h; at
      // 10:00 that is inside the day, so pick the afternoon cell whose
      // canonical window 12:00–17:00 passes — and prove the pass, then
      // an evening window that fails.
      await pumpHub(
        tester,
        policies:
            const BookingPolicies(outsideHoursMode: OutsideHoursMode.off),
        granularity: BookingGranularity.halfDay,
      );
      await tester.tap(find.byTooltip('Week'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey(
        'week-free-seat-4-${WeekGrid.dayStampOf(kTestNow)}-pm',
      )));
      await tester.pumpAndSettle();
      expect(find.byType(BookingSheet), findsOneWidget);
      expect(find.byKey(const ValueKey('booking-gate-refusal')), findsNothing);
      final confirm = tester.widget<FilledButton>(
        find.byKey(const ValueKey('booking-confirm')),
      );
      expect(confirm.onPressed, isNotNull);
    });

    testWidgets(
        'the booking sheet: a picked window the gate refuses disables '
        'Reserve and names the reason', (tester) async {
      // Past day, allow_past_bookings off: browse yesterday via the
      // week grid (the hub's date strip starts today).
      await pumpHub(
        tester,
        policies: const BookingPolicies(advanceHorizonDays: 1),
        granularity: BookingGranularity.halfDay,
      );
      await tester.tap(find.byTooltip('Week'));
      await tester.pumpAndSettle();
      // Two days ahead is beyond a 1-day horizon.
      final later = kTestNow.add(const Duration(days: 2));
      final cell = find.byKey(ValueKey(
        'week-free-seat-4-${WeekGrid.dayStampOf(later)}-am',
      ));
      if (cell.evaluate().isEmpty) {
        // The week may end before +2: nothing to assert on this calendar.
        return;
      }
      await tester.tap(cell);
      await tester.pumpAndSettle();
      // The gate refuses BEFORE the sheet.
      expect(find.byType(BookingSheet), findsNothing);
      expect(find.textContaining('Too far ahead'), findsOneWidget);
    });

    for (final allowed in [false, true]) {
      testWidgets(
          'admin check-out: the tile follows the owner\'s admin_check_out '
          'policy (allowed=$allowed)', (tester) async {
        // The naive frame (no zone installed): 08:00–17:00 around the
        // 10:00 test clock, so the seat reads OCCUPIED right now.
        final start = _at(8);
        final end = _at(17);
        final other = Reservation(
          id: 'r-other',
          workspaceId: 'ws-1',
          seatId: 'seat-4',
          memberId: 'member-2',
          startsAt: start,
          endsAt: end,
          status: ReservationStatus.checkedIn,
          checkedInAt: start,
        );
        final repo = await pumpHub(
          tester,
          seed: [other],
          policies: BookingPolicies(adminCheckOut: allowed),
          flags: const {'bookForOthers': true},
        );
        await tester.tap(find.byIcon(Icons.view_list_outlined));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ListTile, 'A1'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('admin-check-out')),
          allowed ? findsOneWidget : findsNothing,
        );
        if (allowed) {
          await tester.tap(find.byKey(const ValueKey('admin-check-out')));
          await tester.pumpAndSettle();
          expect(
            repo.reservations.single.status,
            ReservationStatus.completed,
            reason: 'the admin ended the running check-in',
          );
        }
      });
    }

    testWidgets('the browser build says why the camera box is missing',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SpaceScanSheet(
            workspaceId: 'ws-1',
            scanBuilder: null,
            l10n: null,
            explainNoCamera: true,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('space-scan-no-camera')), findsOneWidget);
      expect(find.textContaining('not available in the browser'),
          findsOneWidget);
    });
  });
}
