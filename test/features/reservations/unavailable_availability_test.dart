// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Invariant (#1848): a window read that failed with nothing to show is never
// drawn as an empty day. The Day view says availability could not be loaded,
// shows no seat as free, and Retry reads the SAME window again — the
// selection is kept.
import 'package:deskilo/core/demo/data/floor_plan_repository.dart';
import 'package:deskilo/core/demo/data/reservation_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/reserve_view.dart';
import 'reserve_hub_test.dart' show pumpHub;

void main() {
  testWidgets('a failed day read is unavailable, then retry restores it',
      (tester) async {
    final repo = FakeReservationRepository()..failWindowReads = true;
    await pumpHub(tester, repo: repo);
    await pickReserveView(tester, 'day');
    await tester.pumpAndSettle();

    const banner = ValueKey('reserve-availability-unavailable');
    expect(find.byKey(banner), findsOneWidget);
    expect(find.textContaining('no seat is shown as free'), findsOneWidget);

    repo.failWindowReads = false;
    await tester.tap(find.descendant(
        of: find.byKey(banner), matching: find.text('Retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(banner), findsNothing);
  });

  for (final view in ['week', 'month']) {
    testWidgets('a failed $view read is unavailable, then retry restores it',
        (tester) async {
      final repo = FakeReservationRepository()..failWindowReads = true;
      await pumpHub(tester, repo: repo);
      await pickReserveView(tester, view);
      await tester.pumpAndSettle();

      const banner = ValueKey('reserve-availability-unavailable');
      expect(find.byKey(banner), findsOneWidget);
      expect(find.byKey(ValueKey('reserve-$view-grid')), findsNothing);

      repo.failWindowReads = false;
      await tester.tap(find.descendant(
          of: find.byKey(banner), matching: find.text('Retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(banner), findsNothing);
      expect(find.byKey(ValueKey('reserve-$view-grid')), findsOneWidget);
    });
  }

  testWidgets('a failed read on the Plan is unavailable, never every seat free',
      (tester) async {
    final repo = FakeReservationRepository()..failWindowReads = true;
    await pumpHub(tester, repo: repo);
    const banner = ValueKey('reserve-availability-unavailable');
    expect(find.byKey(banner), findsOneWidget);
    expect(find.byKey(const ValueKey('reserve-plan-canvas')), findsNothing);
    repo.failWindowReads = false;
    await tester.tap(find.descendant(
        of: find.byKey(banner), matching: find.text('Retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(banner), findsNothing);
    expect(find.byKey(const ValueKey('reserve-plan-canvas')), findsOneWidget);
  });

  testWidgets('a floor plan that cannot be read offers Retry and keeps the level',
      (tester) async {
    final plans = FakeFloorPlanRepository()..failPlanReads = true;
    await pumpHub(tester, floorPlans: plans);
    const banner = ValueKey('reserve-plan-unavailable');
    expect(find.byKey(banner), findsOneWidget);
    plans.failPlanReads = false;
    await tester.tap(find.descendant(
        of: find.byKey(banner), matching: find.text('Retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(banner), findsNothing);
    expect(find.byKey(const ValueKey('reserve-plan-canvas')), findsOneWidget);
  });
}
