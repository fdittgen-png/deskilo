// SPDX-License-Identifier: MIT
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/plan/domain/level.dart';
import 'package:deskilo/features/plan/presentation/widgets/floor_plan_painter.dart';
import 'package:deskilo/features/plan/presentation/widgets/seat_accessory_row.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../../helpers/fake_accessory_repository.dart';
import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/fake_reservation_repository.dart';
import '../../helpers/in_memory_default_level_store.dart';
import '../../helpers/mock_providers.dart';

/// A 2-hour reservation of member-1 starting at [start] — on the seeded
/// seat ('seat-4' = A1) or, when [officeId] is set instead, on the office.
Reservation reservationAt(DateTime start, {String? seatId, String? officeId}) {
  return Reservation(
    id: 'res-1',
    workspaceId: 'ws-1',
    seatId: seatId,
    officeId: officeId,
    memberId: 'member-1',
    startsAt: start,
    endsAt: start.add(const Duration(hours: 2)),
    status: ReservationStatus.reserved,
  );
}

/// Pumps the app with the small seeded plan (level-1 'Ground floor',
/// office-2 'Main room', desk-3 'Window desk', seat-4 'A1') and switches
/// to the Calendar tab.
Future<InMemoryDefaultLevelStore> pumpCalendarApp(
  WidgetTester tester, {
  required List<Reservation> seed,
  FakeAccessoryRepository? accessories,
  bool twoLevels = false,
  String? storedLevelId,
}) async {
  final plans = FakeFloorPlanRepository()..seedSmallPlan();
  if (twoLevels) {
    plans.levels.add(
      const Level(
        id: 'level-upper',
        workspaceId: 'ws-1',
        name: 'First floor',
        sortOrder: 1,
      ),
    );
  }
  final store = InMemoryDefaultLevelStore();
  if (storedLevelId != null) store.values['ws-1'] = storedLevelId;
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        floorPlan: plans,
        reservations: FakeReservationRepository()..reservations.addAll(seed),
        accessories: accessories ?? FakeAccessoryRepository(),
        defaultLevel: store,
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Calendar'));
  await tester.pumpAndSettle();
  return store;
}

/// The painter of the live plan canvas.
FloorPlanPainter planPainter(WidgetTester tester) {
  final paint = tester
      .widget<CustomPaint>(find.byKey(const ValueKey('live-plan-canvas')));
  return paint.painter! as FloorPlanPainter;
}

bool chipSelected(WidgetTester tester, String name) =>
    tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, name)).selected;

void main() {
  testWidgets(
      'tapping a seat reservation opens the detail sheet with the full '
      'location chain and the seat accessories', (tester) async {
    final now = DateTime.now();
    final accessories = FakeAccessoryRepository()..seedSmallCatalog();
    accessories.seatAccessories['seat-4'] = {'accessory-1', 'accessory-2'};
    await pumpCalendarApp(
      tester,
      seed: [
        reservationAt(
          DateTime(now.year, now.month, now.day, 9),
          seatId: 'seat-4',
        ),
      ],
      accessories: accessories,
    );

    await tester.tap(find.textContaining('09:00'));
    await tester.pumpAndSettle();

    expect(
      find.text('Ground floor · Main room · Window desk · A1'),
      findsOneWidget,
    );
    expect(find.byKey(SeatAccessoryRow.chipsKey), findsOneWidget);
    expect(find.textContaining('Monitor'), findsOneWidget);
    expect(find.textContaining('Standing desk'), findsOneWidget);
    expect(find.text('Show on plan'), findsOneWidget);
  });

  testWidgets('an office reservation shows level · office and no accessories',
      (tester) async {
    final now = DateTime.now();
    await pumpCalendarApp(
      tester,
      seed: [
        reservationAt(
          DateTime(now.year, now.month, now.day, 9),
          officeId: 'office-2',
        ),
      ],
    );

    await tester.tap(find.textContaining('09:00'));
    await tester.pumpAndSettle();

    expect(find.text('Ground floor · Main room'), findsOneWidget);
    expect(find.byKey(SeatAccessoryRow.chipsKey), findsNothing);
    expect(find.text('Show on plan'), findsOneWidget);
  });

  testWidgets(
      'Show on plan jumps to the Plan tab on the seat\'s level, highlights '
      'the seat and does NOT persist the default level', (tester) async {
    final now = DateTime.now();
    final store = await pumpCalendarApp(
      tester,
      seed: [
        reservationAt(
          DateTime(now.year, now.month, now.day, 9),
          seatId: 'seat-4',
        ),
      ],
      twoLevels: true,
      storedLevelId: 'level-upper',
    );

    await tester.tap(find.textContaining('09:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show on plan'));
    await tester.pumpAndSettle();

    // Plan tab, switched to the seat's level (not the stored default) …
    expect(chipSelected(tester, 'Ground floor'), isTrue);
    expect(chipSelected(tester, 'First floor'), isFalse);
    expect(planPainter(tester).plan.levelId, 'level-1');
    // … with the reserved seat ringed on the canvas …
    expect(planPainter(tester).highlightedSeatId, 'seat-4');
    // … and the member's persisted default untouched (#182: transient).
    expect(store.values['ws-1'], 'level-upper');
    expect(store.writes, 0);
  });

  testWidgets(
      'a future reservation browses the plan at the reservation start',
      (tester) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day + 1, 9);
    await pumpCalendarApp(
      tester,
      seed: [reservationAt(start, seatId: 'seat-4')],
    );

    // Select tomorrow in the month grid (crossing into the next month
    // via the chevron when needed).
    if (start.month != now.month) {
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('${start.day}'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('09:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show on plan'));
    await tester.pumpAndSettle();

    // The time scroller browses the reservation's own window (#184): its
    // date on the date button, [startsAt, endsAt) on the from/to chips.
    expect(find.text(DateFormat.MMMd().format(start)), findsOneWidget);
    final fromChip = find.byKey(const ValueKey('plan-from-chip'));
    expect(
      find.descendant(of: fromChip, matching: find.text('09:00')),
      findsOneWidget,
    );
    final toChip = find.byKey(const ValueKey('plan-to-chip'));
    expect(
      find.descendant(of: toChip, matching: find.text('11:00')),
      findsOneWidget,
    );
    expect(planPainter(tester).highlightedSeatId, 'seat-4');
  });
}
