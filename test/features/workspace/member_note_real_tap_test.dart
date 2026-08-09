// SPDX-License-Identifier: 0BSD
//
// REGRESSION (field report): tapping a reservation link in the full-
// message sheet did nothing. The links were TextSpan recognizers whose
// hit-testing broke next to WidgetSpan icons — this test taps the REAL
// pixel position (no recognizer shortcut) and must open the sheet.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/member_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/fake_reservation_repository.dart';
import '../../helpers/mock_providers.dart';

void main() {
  testWidgets('a REAL tap on the reservation link opens the detail sheet',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final workspace = FakeWorkspaceRepository.withWorkspace()
      ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana'}
      ..otherMembers.add(const Member(
        id: 'member-2',
        workspaceId: 'ws-1',
        userId: 'user-2',
        isAdmin: false,
        isOwner: false,
        status: MemberStatus.active,
      ))
      ..memberNotes.add(MemberNote(
        id: 'note-in',
        workspaceId: 'ws-1',
        fromMemberId: 'member-2',
        toMemberId: 'member-1',
        body: 'Keep [res:res-link-1|A1 · tomorrow]?',
        createdAt: DateTime.utc(2026, 5, 12, 9),
      ));
    final plan = FakeFloorPlanRepository()..seedSmallPlan();
    final reservations = FakeReservationRepository()
      ..reservations.add(Reservation(
        id: 'res-link-1',
        workspaceId: 'ws-1',
        seatId: 'seat-4',
        memberId: 'member-1',
        startsAt:
            DateTime(kTestNow.year, kTestNow.month, kTestNow.day + 1, 9),
        endsAt:
            DateTime(kTestNow.year, kTestNow.month, kTestNow.day + 1, 11),
        status: ReservationStatus.reserved,
      ));
    await tester.pumpWidget(ProviderScope(
      overrides: standardTestOverrides(
        workspace: workspace,
        floorPlan: plan,
        reservations: reservations,
      ),
      child: const DeskiloApp(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Events'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Keep A1 · tomorrow?'));
    await tester.pumpAndSettle();

    // The pixel tap: hit the rendered link itself.
    await tester.tap(find.text('A1 · tomorrow', findRichText: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reservation-cancel')), findsOneWidget);
  });
}
