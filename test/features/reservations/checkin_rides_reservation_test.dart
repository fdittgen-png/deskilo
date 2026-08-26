// SPDX-License-Identifier: 0BSD
//
// #573/#574 (migration 0113): a check-in RIDES a reservation. Day-based
// walk-up check-ins book the canonical SLOT (arrive at 10:00, "morning"
// is 08:00–12:00; the retry anchors at now() only when the early slot
// part is genuinely taken); being early on your own reservation's day is
// presence, not a violation; a RUNNING booking may grow its end to a
// later canonical edge — from the seat, without cancelling anything.
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/workspace/domain/booking_granularity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException;

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/fake_reservation_repository.dart';
import '../../helpers/mock_providers.dart';

DateTime _at(int hour, [int minute = 0]) => DateTime(
    kTestNow.year, kTestNow.month, kTestNow.day, hour, minute);

Reservation _row({
  String id = 'res-1',
  String memberId = 'member-1',
  String seatId = 'seat-1',
  required DateTime start,
  required DateTime end,
  ReservationStatus status = ReservationStatus.reserved,
}) =>
    Reservation(
      id: id,
      workspaceId: 'ws-1',
      seatId: seatId,
      memberId: memberId,
      startsAt: start,
      endsAt: end,
      status: status,
    );

void main() {
  tearDown(WorkspaceTime.reset);

  group('canonical walk-up slot (create, checkIn: true)', () {
    test('half-day: a 10:00 walk-up ending at the boundary books the '
        'WHOLE morning 08:00-12:00', () async {
      final repo = FakeReservationRepository()
        ..granularity = BookingGranularity.halfDay;
      await repo.create(
        workspaceId: 'ws-1',
        seatId: 'seat-1',
        startsAt: _at(10),
        endsAt: _at(12),
        checkIn: true,
      );
      final r = repo.reservations.single;
      expect(r.startsAt, _at(8));
      expect(r.endsAt, _at(12));
      expect(r.status, ReservationStatus.checkedIn);
    });

    test('half-day: a 10:00 walk-up for the FULL day books 08:00-17:00',
        () async {
      final repo = FakeReservationRepository()
        ..granularity = BookingGranularity.halfDay;
      await repo.create(
        workspaceId: 'ws-1',
        seatId: 'seat-1',
        startsAt: _at(10),
        endsAt: _at(17),
        checkIn: true,
      );
      expect(repo.reservations.single.startsAt, _at(8));
      expect(repo.reservations.single.endsAt, _at(17));
    });

    test('the retry anchor: with the early slot genuinely taken by '
        'someone else, the walk-up lands at now() and KEEPS the slot end',
        () async {
      final repo = FakeReservationRepository()
        ..granularity = BookingGranularity.halfDay;
      repo.reservations.add(_row(
        id: 'res-other',
        memberId: 'member-2',
        start: _at(8),
        end: _at(10),
      ));
      await repo.create(
        workspaceId: 'ws-1',
        seatId: 'seat-1',
        startsAt: _at(10),
        endsAt: _at(12),
        checkIn: true,
      );
      final mine =
          repo.reservations.where((r) => r.memberId == 'member-1').single;
      expect(mine.startsAt, kTestNow);
      expect(mine.endsAt, _at(12));
    });

    test('non-day granularity keeps the caller window untouched',
        () async {
      final repo = FakeReservationRepository()
        ..granularity = BookingGranularity.minutes30;
      await repo.create(
        workspaceId: 'ws-1',
        seatId: 'seat-1',
        startsAt: _at(10),
        endsAt: _at(12),
        checkIn: true,
      );
      expect(repo.reservations.single.startsAt, _at(10));
    });
  });

  group('same-day presence (checkIn)', () {
    test('half-day: my 10:30 reservation checks in at 10:00 — being '
        'early on the slot day is presence', () async {
      final repo = FakeReservationRepository()
        ..granularity = BookingGranularity.halfDay;
      repo.reservations
          .add(_row(start: _at(10, 30), end: _at(12)));
      await repo.checkIn('res-1');
      expect(repo.reservations.single.status, ReservationStatus.checkedIn);
    });

    test('flexible: the same shape stays refused outside the leeway',
        () async {
      final repo = FakeReservationRepository();
      repo.reservations
          .add(_row(start: _at(10, 30), end: _at(12)));
      await expectLater(
        repo.checkIn('res-1'),
        throwsA(isA<PostgrestException>().having(
            (e) => e.message, 'message', contains('not open yet'))),
      );
    });

    test('minute grids widen the leeway to one step: 30-minute grid '
        'admits a start 20 minutes ahead, refuses 40', () async {
      final repo = FakeReservationRepository()
        ..granularity = BookingGranularity.minutes30;
      repo.reservations
        ..add(_row(id: 'res-near', start: _at(10, 20), end: _at(12)))
        ..add(_row(
            id: 'res-far',
            seatId: 'seat-2',
            start: _at(10, 40),
            end: _at(12)));
      await repo.checkIn('res-near');
      expect(
        repo.reservations
            .firstWhere((r) => r.id == 'res-near')
            .status,
        ReservationStatus.checkedIn,
      );
      await expectLater(
        repo.checkIn('res-far'),
        throwsA(isA<PostgrestException>().having(
            (e) => e.message, 'message', contains('not open yet'))),
      );
    });
  });

  group('extending a RUNNING booking (updateTimes v2)', () {
    test('the end grows to the day end; the start is immovable', () async {
      final repo = FakeReservationRepository();
      repo.reservations.add(_row(
        start: _at(8),
        end: _at(12),
        status: ReservationStatus.checkedIn,
      ));
      await repo.updateTimes('res-1', startsAt: _at(8), endsAt: _at(17));
      expect(repo.reservations.single.endsAt, _at(17));

      await expectLater(
        repo.updateTimes('res-1', startsAt: _at(9), endsAt: _at(17)),
        throwsA(isA<PostgrestException>().having((e) => e.message,
            'message', contains('keeps its start'))),
      );
    });

    test('#638 — the end may also SHRINK to an edge still ahead of now; '
        'an end behind now is refused', () async {
      final repo = FakeReservationRepository();
      repo.reservations.add(_row(
        start: _at(8),
        end: _at(17),
        status: ReservationStatus.checkedIn,
      ));
      // Freeing the afternoon of a running full day — the server has
      // always accepted this; only the client refused to offer it.
      await repo.updateTimes('res-1', startsAt: _at(8), endsAt: _at(12));
      expect(repo.reservations.single.startsAt, _at(8));
      expect(repo.reservations.single.endsAt, _at(12));

      await expectLater(
        repo.updateTimes('res-1', startsAt: _at(8), endsAt: _at(9)),
        throwsA(isA<PostgrestException>().having((e) => e.message,
            'message', contains('ahead'))),
      );
    });

    test('a completed booking is uneditable', () async {
      final repo = FakeReservationRepository();
      repo.reservations.add(_row(
        start: _at(6),
        end: _at(8),
        status: ReservationStatus.completed,
      ));
      await expectLater(
        repo.updateTimes('res-1', startsAt: _at(6), endsAt: _at(17)),
        throwsA(isA<PostgrestException>().having((e) => e.message,
            'message', contains('only upcoming'))),
      );
    });
  });

  /// Opens the detail sheet of [seed] from the hub's Day view, with the
  /// workspace clock pinned to [nowHour] Berlin — the zone-consistent
  /// idiom the extension test established (the suite VM runs at UTC-7).
  Future<FakeReservationRepository> pumpDetailSheet(
    WidgetTester tester, {
    required Reservation Function(DateTime Function(int hour) berlin) seed,
    required BookingGranularity granularity,
    int nowHour = 10,
  }) async {
    WorkspaceTime.install('Europe/Berlin');
    DateTime berlin(int hour) => WorkspaceTime.at(
        kTestNow.year, kTestNow.month, kTestNow.day, hour);
    final repo = FakeReservationRepository()
      ..granularity = granularity
      ..now = () => berlin(nowHour);
    repo.reservations.add(seed(berlin));
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final plans = FakeFloorPlanRepository()..seedSmallPlan();
    final workspace = FakeWorkspaceRepository.withWorkspace()
      ..memberNames = {'member-1': 'Flo'}
      ..openWeekdays['ws-1'] = [1, 2, 3, 4, 5, 6, 7]
      ..bookingGranularities['ws-1'] = granularity;
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(
          floorPlan: plans,
          reservations: repo,
          workspace: workspace,
          clock: FixedClock(berlin(nowHour)),
        ),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Reserve'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Day'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('timeline-block-res-own')));
    await tester.pumpAndSettle();
    return repo;
  }

  /// The Material time picker in keyboard-input mode (dragging the dial
  /// is not reliable in widget tests); [hour] is 24-hour.
  Future<void> enterPickerTime(
    WidgetTester tester, {
    required int hour,
    required String minute,
  }) async {
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();
    final isPm = hour >= 12;
    var h12 = hour % 12;
    if (h12 == 0) h12 = 12;
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, '$h12');
    await tester.enterText(fields.last, minute);
    await tester.tap(find.text(isPm ? 'PM' : 'AM'));
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'the detail sheet of my RUNNING full day offers "End earlier" and '
      'one tap frees the afternoon — same start, the half-day boundary '
      'as the new end (#638)', (tester) async {
    final repo = await pumpDetailSheet(
      tester,
      granularity: BookingGranularity.halfDay,
      seed: (berlin) => Reservation(
        id: 'res-own',
        workspaceId: 'ws-1',
        seatId: 'seat-4',
        memberId: 'member-1',
        startsAt: berlin(8),
        endsAt: berlin(17),
        status: ReservationStatus.checkedIn,
        checkedInAt: berlin(8),
      ),
    );
    DateTime berlin(int hour) => WorkspaceTime.at(
        kTestNow.year, kTestNow.month, kTestNow.day, hour);

    await tester.tap(find.byKey(const ValueKey('reservation-end-early')));
    await tester.pumpAndSettle();

    final r = repo.reservations.single;
    expect(r.startsAt, berlin(8), reason: 'the start is immovable');
    expect(r.endsAt, berlin(12));
    expect(find.text('Reservation updated.'), findsOneWidget);
  });

  testWidgets(
      'end-earlier under a minute grid refuses a time that is not ahead '
      'of now — nothing is written (#638)', (tester) async {
    final repo = await pumpDetailSheet(
      tester,
      granularity: BookingGranularity.minutes30,
      seed: (berlin) => Reservation(
        id: 'res-own',
        workspaceId: 'ws-1',
        seatId: 'seat-4',
        memberId: 'member-1',
        startsAt: berlin(8),
        endsAt: berlin(17),
        status: ReservationStatus.checkedIn,
        checkedInAt: berlin(8),
      ),
    );
    DateTime berlin(int hour) => WorkspaceTime.at(
        kTestNow.year, kTestNow.month, kTestNow.day, hour);

    await tester.tap(find.byKey(const ValueKey('reservation-end-early')));
    await tester.pumpAndSettle();
    // 09:00 is behind the 10:00 clock: refused before any round trip.
    await enterPickerTime(tester, hour: 9, minute: '00');

    expect(repo.reservations.single.endsAt, berlin(17));
    expect(
      find.text(
          'Pick a time still ahead of now and before the current end.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'a RESERVED booking still ahead keeps today\'s Edit/Cancel actions '
      'and offers no end change (#638)', (tester) async {
    await pumpDetailSheet(
      tester,
      granularity: BookingGranularity.minutes30,
      seed: (berlin) => Reservation(
        id: 'res-own',
        workspaceId: 'ws-1',
        seatId: 'seat-4',
        memberId: 'member-1',
        startsAt: berlin(14),
        endsAt: berlin(17),
        status: ReservationStatus.reserved,
      ),
    );

    expect(find.byKey(const ValueKey('reservation-edit')), findsOneWidget);
    expect(find.byKey(const ValueKey('reservation-cancel')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('reservation-end-early')), findsNothing);
    expect(find.byKey(const ValueKey('reservation-extend')), findsNothing);
  });

  testWidgets(
      'the detail sheet of my RUNNING morning offers "Stay longer" and '
      'one tap grows it to the full working day (#574)', (tester) async {
    // Zone-consistent throughout: Berlin wall times as INSTANTS and a
    // clock pinned to 10:00 Berlin — naive-vs-tz mixes made this gate
    // flip with the machine timezone (the no_wall_clock lesson).
    WorkspaceTime.install('Europe/Berlin');
    DateTime berlin(int hour) => WorkspaceTime.at(
        kTestNow.year, kTestNow.month, kTestNow.day, hour);
    final repo = FakeReservationRepository()
      ..granularity = BookingGranularity.halfDay
      ..now = () => berlin(10);
    repo.reservations.add(Reservation(
      id: 'res-own',
      workspaceId: 'ws-1',
      seatId: 'seat-4',
      memberId: 'member-1',
      startsAt: berlin(8),
      endsAt: berlin(12),
      status: ReservationStatus.checkedIn,
      checkedInAt: berlin(8),
    ));
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final plans = FakeFloorPlanRepository()..seedSmallPlan();
    final workspace = FakeWorkspaceRepository.withWorkspace()
      ..memberNames = {'member-1': 'Flo'}
      ..openWeekdays['ws-1'] = [1, 2, 3, 4, 5, 6, 7]
      ..bookingGranularities['ws-1'] = BookingGranularity.halfDay;
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(
          floorPlan: plans,
          reservations: repo,
          workspace: workspace,
          clock: FixedClock(berlin(10)),
        ),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Reserve'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Day'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('timeline-block-res-own')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('reservation-edit')), findsNothing,
        reason: 'a running booking is not freely editable');
    await tester.tap(find.byKey(const ValueKey('reservation-extend')));
    await tester.pumpAndSettle();

    expect(repo.reservations.single.endsAt, berlin(17));
    expect(find.text('Reservation updated.'), findsOneWidget);
  });
}
