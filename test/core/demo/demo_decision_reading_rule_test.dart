// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4146 — the Demo decides as the server does: a decision needs the right to
// read the event (DKN01), the owner always decides.
import 'package:deskilo/core/codes/dk_code.dart';
import 'package:deskilo/core/demo/data/event_repository.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

Member _admin({bool owner = false}) => Member(
  id: 'member-9',
  workspaceId: 'ws-1',
  userId: 'user-9',
  isAdmin: true,
  isOwner: owner,
  status: MemberStatus.active,
);

FakeEventRepository _repo(Member me, Set<WorkspacePermission> held) =>
    FakeEventRepository(
        actor: () => me.id,
        decider: () => me,
        viewerPermissions: () => held,
      )
      ..events.add(
        WorkspaceEvent(
          id: 'expense-1',
          workspaceId: 'ws-1',
          type: EventType.expense,
          action: EventAction.submitted,
          actorMemberId: 'member-2',
          subjectMemberId: 'member-2',
          payload: const {'amount_cents': 1000},
          status: EventStatus.pending,
          createdAt: DateTime(2026, 11, 16),
        ),
      );

void main() {
  test(
    'an administrator whose rights do not read expenses is refused',
    () async {
      final repo = _repo(_admin(), {WorkspacePermission.manageReservations});
      await expectLater(
        repo.respond('expense-1', accept: true),
        throwsA(
          isA<PostgrestException>().having((e) => e.code, 'code', DkCode.dkn01),
        ),
      );
      expect(repo.decisions, isEmpty);
    },
  );

  test('one whose rights read them decides', () async {
    final repo = _repo(_admin(), {WorkspacePermission.approveExpenses});
    await repo.respond('expense-1', accept: true);
    expect(repo.decisions, hasLength(1));
  });

  test('the owner always decides', () async {
    final repo = _repo(_admin(owner: true), const {});
    await repo.respond('expense-1', accept: true);
    expect(repo.decisions, hasLength(1));
  });
}
