// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2578 — the capacity figure drills into the bookings that make it: the
// months it was read over, day by day, the place and the member named.
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/presentation/screens/period_reservations_screen.dart';
import 'package:deskilo/features/reservations/providers/reservation_providers.dart';
import 'package:deskilo/features/workspace/domain/bi_modules.dart';
import 'package:deskilo/features/workspace/domain/bi_query.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

Reservation _booking(
  String id,
  DateTime start, {
  String? seatId = 'seat-a1',
  String? levelId,
}) => Reservation(
  id: id,
  workspaceId: 'ws-1',
  seatId: seatId,
  levelId: levelId,
  memberId: 'member-1',
  startsAt: start,
  endsAt: start.add(const Duration(hours: 4)),
  status: ReservationStatus.completed,
);

void main() {
  test('the capacity figure opens its own months', () {
    final drill = biModules
        .firstWhere((m) => m.id == 'capacity.seat_utilisation')
        .drill!;
    expect(
      drill.target(const BiPeriod(BiGrain.quarter, 2026, 1)),
      '/reservations/period?from=2026-01&to=2026-03',
    );
  });

  testWidgets('the bookings of the months, grouped by day, the place and '
      'the member named', (tester) async {
    await pumpApp(
      tester,
      const PeriodReservationsScreen(fromMonth: '2026-03', toMonth: '2026-03'),
      overrides: [
        periodReservationsProvider('2026-03', '2026-03').overrideWith(
          (ref) async => [
            _booking('r-1', DateTime(2026, 3, 2, 9)),
            _booking('r-2', DateTime(2026, 3, 2, 14)),
            _booking('r-3', DateTime(2026, 3, 9, 9)),
          ],
        ),
        memberNamesProvider.overrideWith((ref) async => {'member-1': 'Ada'}),
        bookingTargetNamesProvider.overrideWith(
          (ref) async => {'seat-a1': 'A1'},
        ),
      ],
    );
    await tester.pumpAndSettle();
    for (final id in ['r-1', 'r-2', 'r-3']) {
      expect(find.byKey(ValueKey('period-reservation-$id')), findsOneWidget);
    }
    expect(find.textContaining('Ada'), findsNWidgets(3));
    expect(find.text('A1'), findsNWidgets(3));
  });

  test('a figure narrowed to one level opens that level only', () {
    final drill = biModules
        .firstWhere((m) => m.id == 'capacity.seat_utilisation')
        .drill!;
    expect(
      drill.target(
        const BiPeriod(BiGrain.month, 2026, 3),
        levelId: 'level-a',
      ),
      '/reservations/period?from=2026-03&to=2026-03&level=level-a',
    );
    final finance = biModules
        .firstWhere((m) => m.id == 'finance.invoiced')
        .drill!;
    expect(
      finance.target(
        const BiPeriod(BiGrain.month, 2026, 3),
        levelId: 'level-a',
      ),
      isNot(contains('level')),
      reason: 'a source that cannot narrow to a level is not told one',
    );
  });

  testWidgets('narrowed to a level: its own bookings and those of its '
      'places, the level named; a place off the plan is left out', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const PeriodReservationsScreen(
        fromMonth: '2026-03',
        toMonth: '2026-03',
        levelId: 'level-a',
      ),
      overrides: [
        periodReservationsProvider('2026-03', '2026-03').overrideWith(
          (ref) async => [
            _booking('on-a', DateTime(2026, 3, 2, 9)),
            _booking('on-b', DateTime(2026, 3, 2, 14), seatId: 'seat-b1'),
            _booking(
              'whole-a',
              DateTime(2026, 3, 3, 9),
              seatId: null,
              levelId: 'level-a',
            ),
            _booking('gone', DateTime(2026, 3, 4, 9), seatId: 'seat-gone'),
          ],
        ),
        bookingTargetLevelsProvider.overrideWith(
          (ref) async => {'seat-a1': 'level-a', 'seat-b1': 'level-b'},
        ),
        bookingLevelNameProvider('level-a').overrideWith(
          (ref) async => 'Ground',
        ),
        memberNamesProvider.overrideWith((ref) async => {'member-1': 'Ada'}),
        bookingTargetNamesProvider.overrideWith(
          (ref) async => {'seat-a1': 'A1'},
        ),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('period-reservation-on-a')), findsOne);
    expect(find.byKey(const ValueKey('period-reservation-whole-a')), findsOne);
    expect(find.byKey(const ValueKey('period-reservation-on-b')), findsNothing);
    expect(find.byKey(const ValueKey('period-reservation-gone')), findsNothing);
    expect(find.text('On Ground only'), findsOneWidget);
  });

  testWidgets('no booking in the months says so', (tester) async {
    await pumpApp(
      tester,
      const PeriodReservationsScreen(fromMonth: '2026-04', toMonth: '2026-04'),
      overrides: [
        periodReservationsProvider(
          '2026-04',
          '2026-04',
        ).overrideWith((ref) async => const []),
        memberNamesProvider.overrideWith((ref) async => const {}),
        bookingTargetNamesProvider.overrideWith((ref) async => const {}),
      ],
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('period-reservations-empty')),
      findsOneWidget,
    );
  });
}
