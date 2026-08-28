// SPDX-License-Identifier: 0BSD
//
// REGRESSION (field report): tapping a reservation link in the full-
// message sheet did nothing. The links were TextSpan recognizers whose
// hit-testing broke next to WidgetSpan icons — this test taps the REAL
// pixel position (no recognizer shortcut) and must open the sheet.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/workspace/domain/conversation.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/member_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/fake_reservation_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/navigation.dart';

/// One timestamp for the note and the conversation row that
/// summarises it — they must agree or the list sorts a thread away
/// from its own last message.
final _sentAt = DateTime.utc(2026, 5, 12, 9);

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
        createdAt: _sentAt,
      ));
    // #687 — the thread is reached through the messaging centre now.
    workspace
      ..conversationMessages['conv-ana'] = [...workspace.memberNotes]
      ..conversations.add(Conversation(
        id: 'conv-ana',
        kind: ConversationKind.direct,
        otherMemberId: 'member-2',
        lastBody: 'Keep [res:res-link-1|A1 · tomorrow]?',
        lastFromMemberId: 'member-2',
        lastAt: _sentAt,
        unread: 1,
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
    await tapNavIcon(tester, Icons.forum_outlined);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('conversation-conv-ana')));
    await tester.pumpAndSettle();

    // The pixel tap: hit the rendered link itself.
    await tester.tap(find.text('A1 · tomorrow', findRichText: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reservation-cancel')), findsOneWidget);
  });
}
