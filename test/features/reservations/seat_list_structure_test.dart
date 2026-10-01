// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1825 — the reserve list shows the structure: each office, its desks,
// each desk's seats (indented under it, no "Room · Table" subtitle). A
// desk or office header is actionable only when the space is bookable as
// a whole AND the member may reserve whole spaces; tapping it opens the
// whole-space sheet for exactly that space. A bookable desk with no seat
// still appears.
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

FloorPlan _plan() => const FloorPlan(
  levelId: 'l1',
  offices: [
    Office(
      id: 'o1',
      workspaceId: 'ws-1',
      levelId: 'l1',
      name: 'Atelier',
      color: 0,
      bookableAsWhole: false,
      rect: _rect,
    ),
  ],
  desks: [
    Desk(
      id: 'd1',
      workspaceId: 'ws-1',
      officeId: 'o1',
      name: 'Long table',
      rect: _rect,
      bookableAsWhole: true,
    ),
    Desk(
      id: 'd2',
      workspaceId: 'ws-1',
      officeId: 'o1',
      name: 'Bench',
      rect: _rect,
    ),
  ],
  seats: [
    Seat(id: 's1', workspaceId: 'ws-1', deskId: 'd2', name: 'B1', x: 0, y: 0, orientation: SeatOrientation.n,
      chair: 'standard',
      amenities: [],),
  ],
);

Future<List<(Desk?, Office?)>> _pump(
  WidgetTester tester, {
  required bool mayReserveWhole,
}) async {
  final taps = <(Desk?, Office?)>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SeatListView(
            plan: _plan(),
            reservations: const [],
            names: const {},
            at: DateTime.utc(2026, 5, 13, 9),
            dayOpen: true,
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
    expect(taps.single.$1?.id, 'd1');
  });

  testWidgets('without the right to reserve whole spaces nothing is '
      'actionable', (tester) async {
    await _pump(tester, mayReserveWhole: false);
    final tile = tester.widget<ListTile>(
      find.byKey(const ValueKey('list-desk-d1')),
    );
    expect(tile.onTap, isNull);
  });
}
