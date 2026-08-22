// SPDX-License-Identifier: 0BSD
// #587 — owner-only delete of plan objects despite past reservations:
// the confirm warning announces the audit substitution while the
// planObjectDelete flag is on, degrades to the historic wording off;
// deleted targets render through the substitution snapshot.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/navigation.dart';

Reservation _reservation({String? seatId, String? spaceLabel}) => Reservation(
      id: 'res-1',
      workspaceId: 'ws-1',
      seatId: seatId,
      memberId: 'member-1',
      startsAt: DateTime.utc(2026, 8, 20, 9),
      endsAt: DateTime.utc(2026, 8, 20, 11),
      status: ReservationStatus.completed,
      spaceLabel: spaceLabel,
    );

void main() {
  group('spaceNameFrom (#587)', () {
    test('the live plan name wins while the target exists', () {
      expect(
        _reservation(seatId: 'seat-1', spaceLabel: 'Old · Chain')
            .spaceNameFrom(const {'seat-1': 'A1'}),
        'A1',
      );
    });

    test('a deleted target falls back to the substitution snapshot', () {
      expect(
        _reservation(spaceLabel: 'Pézenas · Ground floor · Main room')
            .spaceNameFrom(const {}),
        'Pézenas · Ground floor · Main room',
      );
    });

    test('no target and no snapshot degrade to the empty label', () {
      expect(_reservation().spaceNameFrom(const {}), '');
    });
  });

  Future<void> openLevelDeleteDialog(
    WidgetTester tester, {
    Map<String, dynamic> featureFlags = const {},
  }) async {
    final plans = FakeFloorPlanRepository();
    await plans.createLevel('ws-1', 'Doomed floor', 0);
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(
          workspace:
              FakeWorkspaceRepository.withWorkspace(featureFlags: featureFlags),
          floorPlan: plans,
        ),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    await switchToPlanTab(tester);
    await tester.tap(find.byIcon(Icons.design_services_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').first);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'flag ON (default): the level delete warning announces the audit '
      'substitution', (tester) async {
    await openLevelDeleteDialog(tester);
    expect(find.textContaining('text snapshot for audits'), findsOneWidget);
  });

  testWidgets(
      'flag OFF: the level delete warning keeps the historic wording',
      (tester) async {
    await openLevelDeleteDialog(
      tester,
      featureFlags: const {'planObjectDelete': false},
    );
    expect(find.textContaining('text snapshot for audits'), findsNothing);
    expect(
      find.textContaining('All offices, desks and seats on it are removed.'),
      findsOneWidget,
    );
  });
}
