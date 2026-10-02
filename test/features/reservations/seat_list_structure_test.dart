// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1825 — the reserve list shows the structure: each office, its desks,
// each desk's seats (indented under it, no "Room · Table" subtitle). A
// desk or office header is actionable only when the space is bookable as
// a whole AND the member may reserve whole spaces; tapping it opens the
// whole-space sheet for exactly that space. A bookable desk with no seat
// still appears. The whole level heads the list where the level rail
// offers it: bookable as a whole and the grant or admin role.
import 'package:deskilo/core/demo/data/floor_plan_repository.dart';
import 'package:deskilo/features/plan/domain/level.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/plan/domain/desk.dart';
import 'package:deskilo/features/plan/domain/floor_plan.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/office.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:deskilo/features/reservations/presentation/widgets/seat_list_view.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

const _rect = GridRect(x: 0, y: 0, w: 2, h: 2);

FloorPlan _plan({bool officeWhole = false}) => FloorPlan(
  levelId: 'l1',
  offices: [
    Office(
      id: 'o1',
      workspaceId: 'ws-1',
      levelId: 'l1',
      name: 'Atelier',
      color: 0,
      bookableAsWhole: officeWhole,
      rect: _rect,
    ),
  ],
  desks: [
    const Desk(
      id: 'd1',
      workspaceId: 'ws-1',
      officeId: 'o1',
      name: 'Long table',
      rect: _rect,
      bookableAsWhole: true,
    ),
    const Desk(
      id: 'd2',
      workspaceId: 'ws-1',
      officeId: 'o1',
      name: 'Bench',
      rect: _rect,
    ),
  ],
  seats: [
    const Seat(id: 's1', workspaceId: 'ws-1', deskId: 'd2', name: 'B1', x: 0, y: 0, orientation: SeatOrientation.n,
      chair: 'standard',
      amenities: [],),
  ],
);

Future<List<(String?, String?)>> _pump(
  WidgetTester tester, {
  required bool mayReserveWhole,
  bool levelWhole = false,
  bool officeWhole = false,
  bool dayOpen = true,
  List<Reservation> reservations = const [],
  Map<String, bool> flags = const {},
}) async {
  final taps = <(String?, String?)>[];
  final floorPlan = FakeFloorPlanRepository()
    ..levels.add(Level(
      id: 'l1',
      workspaceId: 'ws-1',
      name: 'Ground floor',
      sortOrder: 0,
      bookableAsWhole: levelWhole,
    ));
  final workspace = FakeWorkspaceRepository.withWorkspace(
    featureFlags: {'levelBooking': true, ...flags},
  );
  workspace.myMember = workspace.myMember.copyWith(
    canReserveLevel: mayReserveWhole,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides:
          standardTestOverrides(floorPlan: floorPlan, workspace: workspace),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SeatListView(
            plan: _plan(officeWhole: officeWhole),
            reservations: reservations,
            names: const {'m-2': 'Ana'},
            at: DateTime.utc(2026, 5, 13, 9),
            windowEndOrNull: DateTime.utc(2026, 5, 13, 13),
            dayOpen: dayOpen,
            onSeatTap: (_) {},
            onSpaceTap: mayReserveWhole ? (d, o) => taps.add((d, o)) : null,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return taps;
}

void main() {
  testWidgets('office → desks → seats, in order, a seatless bookable desk '
      'included', (tester) async {
    await _pump(tester, mayReserveWhole: true);
    double top(String key) => tester.getTopLeft(find.byKey(ValueKey(key))).dy;
    expect(top('list-office-o1'), lessThan(top('list-desk-d2')));
    expect(top('list-desk-d2'), lessThan(top('list-seat-s1')));
    expect(
      find.byKey(const ValueKey('list-desk-d1')),
      findsOneWidget,
      reason: 'bookable as a whole, though it has no seat',
    );
    expect(
      find.textContaining('Atelier · Bench'),
      findsNothing,
      reason: 'the structure replaces the Room · Table subtitle',
    );
  });

  testWidgets('only the bookable desk is actionable, and opens that desk', (
    tester,
  ) async {
    final taps = await _pump(tester, mayReserveWhole: true);
    await tester.tap(find.byKey(const ValueKey('list-desk-d2')));
    await tester.tap(find.byKey(const ValueKey('list-office-o1')));
    expect(taps, isEmpty, reason: 'neither is bookable as a whole');
    await tester.tap(find.byKey(const ValueKey('list-desk-d1')));
    expect(taps.single.$1, 'd1');
  });

  testWidgets('without the right to reserve whole spaces nothing is '
      'actionable', (tester) async {
    await _pump(tester, mayReserveWhole: false);
    final tile = tester.widget<ListTile>(
      find.byKey(const ValueKey('list-desk-d1')),
    );
    expect(tile.onTap, isNull);
  });

  testWidgets('a level bookable as a whole heads the list and opens the '
      'level', (tester) async {
    final taps = await _pump(tester, mayReserveWhole: true, levelWhole: true);
    double top(String key) => tester.getTopLeft(find.byKey(ValueKey(key))).dy;
    // The level's only room is named by the level (#1273), so the desks
    // follow the level header directly.
    expect(top('list-level-l1'), lessThan(top('list-desk-d1')));
    await tester.tap(find.byKey(const ValueKey('list-level-l1')));
    expect(taps.single, (null, null), reason: 'neither desk nor office');
  });

  testWidgets('no level header when the level is not bookable as a whole, '
      'or the member may not reserve whole spaces', (tester) async {
    await _pump(tester, mayReserveWhole: true);
    expect(find.byKey(const ValueKey('list-level-l1')), findsNothing);
    await _pump(tester, mayReserveWhole: false, levelWhole: true);
    expect(find.byKey(const ValueKey('list-level-l1')), findsNothing);
  });

  testWidgets('a reservable header says what it covers', (tester) async {
    await _pump(tester, mayReserveWhole: true, officeWhole: true);
    expect(
      find.descendant(
          of: find.byKey(const ValueKey('list-office-o1')),
          matching: find.text('Reservable as a whole · 2 tables · 1 seat')),
      findsOneWidget,
    );
    expect(
      find.descendant(
          of: find.byKey(const ValueKey('list-desk-d1')),
          matching: find.text('Reservable as a whole')),
      findsOneWidget,
      reason: 'a seatless bookable desk covers no seats',
    );
  });

  testWidgets('a seat taken in the window makes its room unavailable and '
      'names the holder; the free desk stays reservable', (tester) async {
    final taps = await _pump(
      tester,
      mayReserveWhole: true,
      officeWhole: true,
      reservations: [
        Reservation(
          id: 'r1',
          workspaceId: 'ws-1',
          memberId: 'm-2',
          seatId: 's1',
          startsAt: DateTime.utc(2026, 5, 13, 8),
          endsAt: DateTime.utc(2026, 5, 13, 12),
          status: ReservationStatus.reserved,
        ),
      ],
    );
    expect(
      find.descendant(
          of: find.byKey(const ValueKey('list-office-o1')),
          matching: find.text('Reserved by Ana')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('list-office-o1')));
    expect(taps, isEmpty, reason: 'a taken room is not offered');
    await tester.tap(find.byKey(const ValueKey('list-desk-d1')));
    expect(taps.single, ('d1', null));
  });

  testWidgets('a closed day: headers are not actionable', (tester) async {
    await _pump(tester, mayReserveWhole: true, officeWhole: true, dayOpen: false);
    for (final k in ['list-office-o1', 'list-desk-d1']) {
      expect(tester.widget<ListTile>(find.byKey(ValueKey(k))).onTap, isNull,
          reason: k);
    }
  });

  testWidgets('a single-room level named by its room prints one header '
      '(#1273)', (tester) async {
    await _pump(
      tester,
      mayReserveWhole: true,
      levelWhole: true,
      flags: {'singleRoomLevelNames': true},
    );
    expect(find.byKey(const ValueKey('list-level-l1')), findsOneWidget);
    expect(find.byKey(const ValueKey('list-office-o1')), findsNothing);
    expect(find.byKey(const ValueKey('list-desk-d2')), findsOneWidget);
  });
}
