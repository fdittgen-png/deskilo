// SPDX-License-Identifier: MIT
//
// Edit & cancel own reservations from the shared detail sheet (0033):
// the sheet serves the hub's plan, Day, Week and the calendar timeline,
// so one surface change gives every entry point the two actions that
// were missing — a granularity-aware window edit and cancel (with the
// series occurrence/following choice).
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/features/plan/domain/half_day_windows.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'reserve_hub_test.dart' show pumpHub;
import 'package:deskilo/features/workspace/domain/booking_granularity.dart';

Reservation _mine(
  DateTime day, {
  String id = 'res-own',
  String? seriesId,
  ReservationStatus status = ReservationStatus.reserved,
}) {
  return Reservation(
    id: id,
    workspaceId: 'ws-1',
    seatId: 'seat-4',
    memberId: 'member-1',
    seriesId: seriesId,
    startsAt: WorkspaceTime.at(day.year, day.month, day.day, 9),
    endsAt: WorkspaceTime.at(day.year, day.month, day.day, 11),
    status: status,
  );
}

DateTime get _today {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// Opens my booking's detail sheet through the hub's Day view block.
Future<void> openDetail(WidgetTester tester) async {
  await tester.tap(find.text('Day'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('timeline-block-res-own')));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(WorkspaceTime.reset);

  testWidgets('my upcoming booking offers Edit and Cancel in the sheet; '
      'cancelling removes it', (tester) async {
    WorkspaceTime.install('Europe/Berlin');
    final repo = await pumpHub(tester, seed: [_mine(_today)]);

    await openDetail(tester);
    expect(find.byKey(const ValueKey('reservation-edit')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('reservation-cancel')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('reservation-cancel')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Cancel reservation'));
    await tester.pumpAndSettle();

    expect(
      repo.reservations.single.status,
      ReservationStatus.cancelled,
    );
    expect(find.text('Reservation cancelled.'), findsOneWidget);
  });

  testWidgets('a series booking offers occurrence AND following; '
      'following cancels from this start', (tester) async {
    WorkspaceTime.install('Europe/Berlin');
    final tomorrow =
        DateTime(_today.year, _today.month, _today.day + 1);
    final repo = await pumpHub(tester, seed: [
      _mine(_today, seriesId: 'series-1'),
      _mine(tomorrow, id: 'res-next', seriesId: 'series-1'),
    ]);

    await openDetail(tester);
    await tester.tap(find.byKey(const ValueKey('reservation-cancel')));
    await tester.pumpAndSettle();
    expect(find.text('Cancel this occurrence'), findsOneWidget);
    await tester.tap(find.text('Cancel this and following'));
    await tester.pumpAndSettle();

    expect(
      repo.reservations.every(
        (r) => r.status == ReservationStatus.cancelled,
      ),
      isTrue,
    );
  });

  testWidgets('Edit under half-day granularity: switching my morning '
      'booking to the afternoon moves it to the canonical window',
      (tester) async {
    WorkspaceTime.install('Europe/Berlin');
    final repo = await pumpHub(
      tester,
      granularity: BookingGranularity.halfDay,
      seed: [
        Reservation(
          id: 'res-own',
          workspaceId: 'ws-1',
          seatId: 'seat-4',
          memberId: 'member-1',
          startsAt: HalfDayWindows.morning(_today).start,
          endsAt: HalfDayWindows.morning(_today).end,
          status: ReservationStatus.reserved,
        ),
      ],
    );

    await openDetail(tester);
    await tester.tap(find.byKey(const ValueKey('reservation-edit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit-window-pm')));
    await tester.pumpAndSettle();
    // The edit flow now also asks about repetition — keep it a single.
    await tester.tap(find.byKey(const ValueKey('edit-repeat-none')));
    await tester.pumpAndSettle();

    final updated = repo.reservations.single;
    final expected = HalfDayWindows.afternoon(_today);
    expect(updated.startsAt.toUtc(), expected.start.toUtc());
    expect(updated.endsAt.toUtc(), expected.end.toUtc());
    expect(find.text('Reservation updated.'), findsOneWidget);
  });

  testWidgets('Edit can turn a single booking into a series: choosing a '
      'weekly repeat books the recurrence and drops the single',
      (tester) async {
    WorkspaceTime.install('Europe/Berlin');
    final repo = await pumpHub(
      tester,
      granularity: BookingGranularity.halfDay,
      seed: [
        Reservation(
          id: 'res-own',
          workspaceId: 'ws-1',
          seatId: 'seat-4',
          memberId: 'member-1',
          startsAt: HalfDayWindows.morning(_today).start,
          endsAt: HalfDayWindows.morning(_today).end,
          status: ReservationStatus.reserved,
        ),
      ],
    );

    await openDetail(tester);
    await tester.tap(find.byKey(const ValueKey('reservation-edit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit-window-am')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit-repeat-weekly')));
    await tester.pumpAndSettle();

    // The original single is cancelled and a weekly series now exists.
    final series =
        repo.reservations.where((r) => r.seriesPattern == 'weekly').toList();
    expect(series, isNotEmpty);
    expect(
      repo.reservations
          .firstWhere((r) => r.id == 'res-own')
          .status,
      ReservationStatus.cancelled,
    );
  });

  testWidgets('a checked-in booking stays read-only in the sheet',
      (tester) async {
    WorkspaceTime.install('Europe/Berlin');
    await pumpHub(
      tester,
      seed: [_mine(_today, status: ReservationStatus.checkedIn)],
    );

    await openDetail(tester);
    expect(find.byKey(const ValueKey('reservation-edit')), findsNothing);
    expect(find.byKey(const ValueKey('reservation-cancel')), findsNothing);
  });
}
