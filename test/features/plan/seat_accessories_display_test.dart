// SPDX-License-Identifier: MIT
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/plan/presentation/widgets/seat_accessory_row.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_accessory_repository.dart';
import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/fake_reservation_repository.dart';
import '../../helpers/mock_providers.dart';
import 'plan_screen_test.dart' show seatCenter;

/// Pumps the Plan tab (#169 harness): the seeded small plan plus the small
/// accessory catalog (Monitor 1.00 active, Standing desk 0 active, Docking
/// station 0.50 INACTIVE). [assignByName] assigns those catalog entries to
/// the plan's single seat; [featureFlags] seeds the workspace toggles
/// (accessorySupplements defaults OFF, #170).
Future<FakeReservationRepository> pumpPlanWithAccessories(
  WidgetTester tester, {
  Map<String, dynamic> featureFlags = const {},
  List<String> assignByName = const [],
}) async {
  final plans = FakeFloorPlanRepository()..seedSmallPlan();
  final accessories = FakeAccessoryRepository()..seedSmallCatalog();
  final reservations = FakeReservationRepository();
  if (assignByName.isNotEmpty) {
    await accessories.setSeatAccessories(plans.seats.single.id, {
      for (final name in assignByName)
        accessories.accessories.firstWhere((a) => a.name == name).id,
    });
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        floorPlan: plans,
        accessories: accessories,
        reservations: reservations,
        workspace:
            FakeWorkspaceRepository.withWorkspace(featureFlags: featureFlags),
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  return reservations;
}

void main() {
  testWidgets(
      'the booking sheet lists the seat\'s active accessories without '
      'prices when the supplements toggle is off, and still checks in',
      (tester) async {
    final reservations = await pumpPlanWithAccessories(
      tester,
      assignByName: ['Monitor', 'Standing desk', 'Docking station'],
    );

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();

    expect(find.byKey(SeatAccessoryRow.chipsKey), findsOneWidget);
    expect(find.text('Monitor'), findsOneWidget);
    expect(find.text('Standing desk'), findsOneWidget);
    // The deactivated catalog entry never shows to bookers.
    expect(find.textContaining('Docking station'), findsNothing);
    // Toggle off (#170 default): names only, no supplement suffix, no hint.
    expect(find.textContaining('(+'), findsNothing);
    expect(find.text('Supplements are per half-day.'), findsNothing);

    // The extended sheet still books end-to-end.
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Check in'));
    await tester.tap(find.widgetWithText(FilledButton, 'Check in'));
    await tester.pumpAndSettle();
    expect(
      reservations.reservations.single.status,
      ReservationStatus.checkedIn,
    );
  });

  testWidgets(
      'priced accessories carry the (+supplement) suffix and the '
      'per-half-day hint when the toggle is on', (tester) async {
    await pumpPlanWithAccessories(
      tester,
      featureFlags: const {'accessorySupplements': true},
      assignByName: ['Monitor', 'Standing desk'],
    );

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();

    // Only the Monitor (1.00) is priced; the free standing desk keeps its
    // bare name even with the toggle on.
    expect(find.textContaining('Monitor (+'), findsOneWidget);
    expect(find.textContaining('(+'), findsOneWidget);
    expect(find.text('Standing desk'), findsOneWidget);
    expect(find.text('Supplements are per half-day.'), findsOneWidget);
  });

  testWidgets('a seat without accessories renders no accessory row',
      (tester) async {
    await pumpPlanWithAccessories(tester);

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();

    // The sheet itself is up …
    expect(find.textContaining('Starts now'), findsOneWidget);
    // … but no chips, no header, no empty box.
    expect(find.byKey(SeatAccessoryRow.chipsKey), findsNothing);
    expect(find.text('Monitor'), findsNothing);
  });

  testWidgets(
      'a seat whose only assigned accessory is inactive renders no row',
      (tester) async {
    await pumpPlanWithAccessories(
      tester,
      featureFlags: const {'accessorySupplements': true},
      assignByName: ['Docking station'],
    );

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();

    expect(find.byKey(SeatAccessoryRow.chipsKey), findsNothing);
    expect(find.textContaining('Docking station'), findsNothing);
    expect(find.textContaining('(+'), findsNothing);
  });
}
