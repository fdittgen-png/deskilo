// SPDX-License-Identifier: MIT
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/calendar/presentation/widgets/day_timeline.dart';
import 'package:deskilo/features/plan/domain/desk.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/level.dart';
import 'package:deskilo/features/plan/domain/office.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/fake_reservation_repository.dart';
import '../../helpers/mock_providers.dart';

/// A reservation today from [startHour] to [startHour]+2 on the seeded
/// seat ('seat-4' = A1) unless [seatId]/[officeId] say otherwise.
Reservation todayReservation({
  String id = 'res-1',
  String memberId = 'member-1',
  String? seatId = 'seat-4',
  String? officeId,
  int startHour = 9,
}) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day, startHour);
  return Reservation(
    id: id,
    workspaceId: 'ws-1',
    seatId: seatId,
    officeId: officeId,
    memberId: memberId,
    startsAt: start,
    endsAt: start.add(const Duration(hours: 2)),
    status: ReservationStatus.reserved,
  );
}

/// Adds a second level ('First floor') with office/desk and seat 'B1'
/// (id 'seat-9') to the seeded small plan.
void addSecondLevel(FakeFloorPlanRepository plans) {
  plans.levels.add(
    const Level(
      id: 'level-9',
      workspaceId: 'ws-1',
      name: 'First floor',
      sortOrder: 1,
    ),
  );
  plans.offices.add(
    const Office(
      id: 'office-9',
      workspaceId: 'ws-1',
      levelId: 'level-9',
      name: 'Quiet room',
      color: 1,
      bookableAsWhole: false,
      rect: GridRect(x: 0, y: 0, w: 30, h: 20),
    ),
  );
  plans.desks.add(
    const Desk(
      id: 'desk-9',
      workspaceId: 'ws-1',
      officeId: 'office-9',
      name: 'Corner desk',
      rect: GridRect(x: 2, y: 2, w: 12, h: 4),
    ),
  );
  plans.seats.add(
    const Seat(
      id: 'seat-9',
      workspaceId: 'ws-1',
      deskId: 'desk-9',
      name: 'B1',
      x: 2,
      y: 2,
      orientation: SeatOrientation.n,
      chair: 'standard',
      amenities: [],
    ),
  );
}

/// Pumps the app on the Calendar tab and switches the selected-day area
/// to the timeline view (#187). [mutatePlans] tweaks the seeded plan
/// repository before pumping (e.g. an extra seat-less level for #221).
Future<FakeReservationRepository> pumpTimeline(
  WidgetTester tester, {
  List<Reservation> seed = const [],
  bool twoLevels = false,
  void Function(FakeFloorPlanRepository plans)? mutatePlans,
}) async {
  final plans = FakeFloorPlanRepository()..seedSmallPlan();
  if (twoLevels) addSecondLevel(plans);
  mutatePlans?.call(plans);
  final reservations = FakeReservationRepository()..reservations.addAll(seed);
  final workspace = FakeWorkspaceRepository.withWorkspace()
    ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana'};
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
  await tester.tap(find.text('Calendar'));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.view_timeline_outlined));
  await tester.pumpAndSettle();
  return reservations;
}

void main() {
  test('axis constants are pinned (visual contract of #187)', () {
    expect(TimelineAxis.hourWidth, 48.0);
    expect(TimelineAxis.hoursPerDay, 24);
    expect(TimelineAxis.trackWidth, 1152.0);
    expect(TimelineAxis.labelStepHours, 2);
    expect(TimelineAxis.rowHeight, 36.0);
    expect(TimelineAxis.headerRowHeight, 28.0);
    expect(TimelineAxis.levelHeaderRowHeight, 32.0);
    expect(TimelineAxis.rulerHeight, 24.0);
    expect(TimelineAxis.leadingWidth, 112.0);
    expect(TimelineAxis.defaultStartHour, 8);
    expect(TimelineAxis.blockInset, 4.0);
  });

  testWidgets(
      'the timeline toggle swaps the day list for seat rows under an '
      'office · desk header, and back', (tester) async {
    await pumpTimeline(tester, seed: [todayReservation()]);

    expect(find.byType(DayTimeline), findsOneWidget);
    expect(find.text('Main room · Window desk'), findsOneWidget);
    expect(find.text('A1'), findsOneWidget);
    expect(find.byKey(DayTimeline.trackKey('seat-4')), findsOneWidget);
    // Hour ruler labels every 2h.
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('09:00'), findsNothing);
    // The selected day is today → "now" line present.
    expect(find.byKey(DayTimeline.nowLineKey), findsOneWidget);
    // No ListTile rows in timeline mode.
    expect(find.byType(ListTile), findsNothing);

    // Back to the (default) list view.
    await tester.tap(find.byIcon(Icons.view_list_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(DayTimeline), findsNothing);
    expect(find.byType(ListTile), findsOneWidget);
  });

  testWidgets('a 09:00–11:00 block sits at 9×hourWidth and spans 2 hours',
      (tester) async {
    await pumpTimeline(tester, seed: [todayReservation()]);

    final track = find.byKey(DayTimeline.trackKey('seat-4'));
    final block = find.byKey(DayTimeline.blockKey('res-1'));
    expect(block, findsOneWidget);

    final trackTopLeft = tester.getTopLeft(track);
    final blockTopLeft = tester.getTopLeft(block);
    expect(blockTopLeft.dx - trackTopLeft.dx, TimelineAxis.hourWidth * 9);
    expect(blockTopLeft.dy - trackTopLeft.dy, TimelineAxis.blockInset);
    expect(tester.getSize(block).width, TimelineAxis.hourWidth * 2);
  });

  testWidgets('level chips switch the rows to the chosen level',
      (tester) async {
    await pumpTimeline(
      tester,
      twoLevels: true,
      seed: [
        todayReservation(),
        todayReservation(id: 'res-2', seatId: 'seat-9', startHour: 10),
      ],
    );

    // Default: first level by sort order.
    expect(find.byKey(DayTimeline.trackKey('seat-4')), findsOneWidget);
    expect(find.byKey(DayTimeline.trackKey('seat-9')), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'First floor'));
    await tester.pumpAndSettle();

    expect(find.byKey(DayTimeline.trackKey('seat-9')), findsOneWidget);
    expect(find.text('Quiet room · Corner desk'), findsOneWidget);
    expect(find.text('B1'), findsOneWidget);
    expect(find.byKey(DayTimeline.trackKey('seat-4')), findsNothing);
  });

  testWidgets(
      'the All levels chip renders first but the default selection stays '
      'the first real level (#221)', (tester) async {
    await pumpTimeline(tester, twoLevels: true, seed: [todayReservation()]);

    // The sentinel chip leads the selector row.
    final allChip = find.widgetWithText(ChoiceChip, 'All levels');
    expect(allChip, findsOneWidget);
    expect(
      tester.getTopLeft(allChip).dx,
      lessThan(
        tester.getTopLeft(find.widgetWithText(ChoiceChip, 'Ground floor')).dx,
      ),
    );

    // Default unchanged: first level only, no level-header rows.
    expect(tester.widget<ChoiceChip>(allChip).selected, isFalse);
    expect(find.byKey(DayTimeline.trackKey('seat-4')), findsOneWidget);
    expect(find.byKey(DayTimeline.trackKey('seat-9')), findsNothing);
    expect(find.byKey(DayTimeline.levelHeaderKey('level-1')), findsNothing);
  });

  testWidgets(
      'All levels stacks both levels under level-name headers in sort '
      'order, with blocks positioned per level (#221)', (tester) async {
    await pumpTimeline(
      tester,
      twoLevels: true,
      seed: [
        todayReservation(),
        todayReservation(id: 'res-2', seatId: 'seat-9', startHour: 10),
      ],
    );

    await tester.tap(find.widgetWithText(ChoiceChip, 'All levels'));
    await tester.pumpAndSettle();

    // Both level headers, Ground floor (sortOrder 0) above First floor.
    final groundHeader = find.byKey(DayTimeline.levelHeaderKey('level-1'));
    final firstHeader = find.byKey(DayTimeline.levelHeaderKey('level-9'));
    expect(groundHeader, findsOneWidget);
    expect(firstHeader, findsOneWidget);
    expect(
      tester.getTopLeft(groundHeader).dy,
      lessThan(tester.getTopLeft(firstHeader).dy),
    );

    // Both levels' group headers and seat rows are on one axis.
    expect(find.text('Main room · Window desk'), findsOneWidget);
    expect(find.text('Quiet room · Corner desk'), findsOneWidget);
    expect(find.byKey(DayTimeline.trackKey('seat-4')), findsOneWidget);
    expect(find.byKey(DayTimeline.trackKey('seat-9')), findsOneWidget);

    // Each block sits on its own level's track at its start hour.
    final upperTrack = find.byKey(DayTimeline.trackKey('seat-9'));
    final upperBlock = find.byKey(DayTimeline.blockKey('res-2'));
    expect(find.byKey(DayTimeline.blockKey('res-1')), findsOneWidget);
    expect(upperBlock, findsOneWidget);
    expect(
      tester.getTopLeft(upperBlock).dx - tester.getTopLeft(upperTrack).dx,
      TimelineAxis.hourWidth * 10,
    );
    expect(
      tester.getTopLeft(upperBlock).dy - tester.getTopLeft(upperTrack).dy,
      TimelineAxis.blockInset,
    );
  });

  testWidgets(
      'All levels skips levels with no seats and levels without a visible '
      'reservation that day (#221)', (tester) async {
    await pumpTimeline(
      tester,
      twoLevels: true,
      // A third, seat-less level must never contribute a header row.
      mutatePlans: (plans) => plans.levels.add(
        const Level(
          id: 'level-99',
          workspaceId: 'ws-1',
          name: 'Attic',
          sortOrder: 2,
        ),
      ),
      seed: [todayReservation()],
    );

    await tester.tap(find.widgetWithText(ChoiceChip, 'All levels'));
    await tester.pumpAndSettle();

    expect(find.byKey(DayTimeline.levelHeaderKey('level-1')), findsOneWidget);
    expect(find.byKey(DayTimeline.trackKey('seat-4')), findsOneWidget);
    // First floor has seats but no visible reservation → skipped, like the
    // single-level empty rule; the seat-less Attic is skipped too.
    expect(find.byKey(DayTimeline.levelHeaderKey('level-9')), findsNothing);
    expect(find.byKey(DayTimeline.trackKey('seat-9')), findsNothing);
    expect(find.byKey(DayTimeline.levelHeaderKey('level-99')), findsNothing);
  });

  testWidgets(
      'All levels with nothing to show anywhere uses the all-levels empty '
      'hint (#221)', (tester) async {
    await pumpTimeline(tester, twoLevels: true);

    await tester.tap(find.widgetWithText(ChoiceChip, 'All levels'));
    await tester.pumpAndSettle();

    expect(
      find.text('No reservations on any level for this day.'),
      findsOneWidget,
    );
    expect(find.byKey(DayTimeline.trackKey('seat-4')), findsNothing);
  });

  testWidgets(
      "Mine hides other members' blocks; Everyone shows them with the "
      'occupant name inside', (tester) async {
    await pumpTimeline(
      tester,
      seed: [todayReservation(id: 'res-x', memberId: 'member-2')],
    );

    // Mine (default): the other member's booking is invisible.
    expect(find.byKey(DayTimeline.blockKey('res-x')), findsNothing);
    expect(
      find.text('No reservations on this level for this day.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Everyone'));
    await tester.pumpAndSettle();

    expect(find.byKey(DayTimeline.blockKey('res-x')), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
  });

  testWidgets('tapping my block opens the reservation detail sheet (#182)',
      (tester) async {
    await pumpTimeline(tester, seed: [todayReservation()]);

    await tester.tap(find.byKey(DayTimeline.blockKey('res-1')));
    await tester.pumpAndSettle();

    expect(
      find.text('Ground floor · Main room · Window desk · A1'),
      findsOneWidget,
    );
    expect(find.text('Show on plan'), findsOneWidget);
  });

  testWidgets("tapping another member's block shows the occupant snackbar",
      (tester) async {
    await pumpTimeline(
      tester,
      seed: [todayReservation(id: 'res-x', memberId: 'member-2')],
    );
    await tester.tap(find.text('Everyone'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(DayTimeline.blockKey('res-x')));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.textContaining('Occupied by Ana'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('until 11:00'), findsOneWidget);
  });

  testWidgets('a whole-office reservation spans every seat of the office',
      (tester) async {
    await pumpTimeline(
      tester,
      seed: [
        todayReservation(id: 'res-o', seatId: null, officeId: 'office-2'),
      ],
    );

    // The office block renders on seat A1's row (the office's only seat).
    final track = find.byKey(DayTimeline.trackKey('seat-4'));
    final block = find.byKey(DayTimeline.blockKey('res-o'));
    expect(block, findsOneWidget);
    expect(
      tester.getTopLeft(block).dx - tester.getTopLeft(track).dx,
      TimelineAxis.hourWidth * 9,
    );
  });

  testWidgets('an empty day shows the localized timeline hint',
      (tester) async {
    await pumpTimeline(tester);

    expect(
      find.text('No reservations on this level for this day.'),
      findsOneWidget,
    );
    expect(find.byKey(DayTimeline.trackKey('seat-4')), findsNothing);
  });
}
