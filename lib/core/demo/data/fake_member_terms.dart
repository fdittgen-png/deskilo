// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3858 — the Demo's dated plan changes and pauses: the changes it holds,
// the months its invoices froze, and the dated commands (a share from a
// month's first day after the last invoiced month, as soon as possible or
// scheduled; a pause from a day until a day or until resumed), on the
// server's rules.
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/member_term_answer.dart';
import 'package:deskilo/features/workspace/domain/member_term_change.dart';

import 'fake_workspace_members.dart';
import 'fake_workspace_state.dart';

mixin FakeMemberTerms on FakeWorkspaceState, FakeWorkspaceMembers {
  /// #3858 — the Demo's dated plan changes and pauses.
  final memberTermChanges = <MemberTermChange>[];

  @override
  Future<List<MemberTermChange>> fetchMemberTermChanges(
    String workspaceId,
  ) async => List.of(memberTermChanges);

  /// #3858 — the months a standing subscription invoice froze, by member.
  final memberInvoicedMonths = <String, Set<DateTime>>{};

  @override
  Future<Map<String, Set<DateTime>>> fetchInvoicedMonths(
    String workspaceId,
  ) async => {
    for (final e in memberInvoicedMonths.entries) e.key: {...e.value},
  };

  /// #3858 — the day the demo's dated changes are measured from.
  Clock termClock = const SystemClock();

  DateTime get _termToday {
    final now = termClock.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// The first day after the last invoiced month from [on]'s month on.
  DateTime _earliestOpen(String memberId, DateTime on) => earliestShareDay(
    on,
    memberInvoicedMonths[memberId] ?? const <DateTime>{},
  );

  MemberTermChange _term(
    String memberId,
    MemberTermKind kind,
    DateTime on, {
    int? pct,
    String? status,
    String? group,
  }) => MemberTermChange(
    id: 'term-${memberTermChanges.length + 1}',
    memberId: memberId,
    kind: kind,
    toPct: pct,
    toStatus: status,
    dueOn: on,
    state: on.isAfter(_termToday)
        ? MemberTermState.scheduled
        : MemberTermState.applied,
    groupId: group,
  );

  @override
  Future<MemberTermAnswer> requestMemberShare(String memberId, int pct) async {
    final today = _termToday;
    final on = _earliestOpen(memberId, today);
    final dated = _term(memberId, MemberTermKind.share, on, pct: pct);
    // written by the immediate command, not scheduled by a person
    final change = MemberTermChange(
      id: dated.id,
      memberId: memberId,
      kind: MemberTermKind.share,
      toPct: pct,
      dueOn: on,
      state: dated.state,
      scheduled: false,
    );
    memberTermChanges.add(change);
    if (change.state == MemberTermState.applied) {
      await updateMemberSubscription(memberId, pct);
    }
    return MemberTermAnswer(state: change.state, effectiveOn: on);
  }

  @override
  Future<MemberTermAnswer> scheduleMemberShare(
    String memberId,
    int pct,
    DateTime on,
    String requestId,
  ) async {
    final today = _termToday;
    final open = _earliestOpen(memberId, today);
    if (on.isBefore(today) && on != open) throw MemberTermDateRefused(open);
    final earliest = _earliestOpen(memberId, on);
    if (earliest.isAfter(DateTime(on.year, on.month))) {
      throw MemberTermDateRefused(earliest);
    }
    if (on.day != 1) {
      throw MemberTermDateRefused(
        _earliestOpen(memberId, DateTime(on.year, on.month + 1)),
      );
    }
    final change = _term(memberId, MemberTermKind.share, on, pct: pct);
    memberTermChanges.add(change);
    if (change.state == MemberTermState.applied) {
      await updateMemberSubscription(memberId, pct);
    }
    return MemberTermAnswer(state: change.state, effectiveOn: on);
  }

  @override
  Future<MemberTermAnswer> scheduleMemberPause(
    String memberId,
    DateTime from,
    DateTime? until,
    String requestId,
  ) async {
    if (from.isBefore(_termToday)) throw MemberTermDateRefused(_termToday);
    final group = 'pause-${memberTermChanges.length + 1}';
    final start = _term(
      memberId,
      MemberTermKind.status,
      from,
      status: 'paused',
      group: group,
    );
    memberTermChanges.add(start);
    if (until != null) {
      memberTermChanges.add(
        _term(
          memberId,
          MemberTermKind.status,
          until,
          status: 'active',
          group: group,
        ),
      );
    }
    if (start.state == MemberTermState.applied) {
      await updateMemberStatus(memberId, MemberStatus.paused);
    }
    final money = pauseMoneyOf(
      from,
      until,
      invoiced: memberInvoicedMonths[memberId] ?? const {},
    );
    return MemberTermAnswer(
      state: start.state,
      effectiveOn: from,
      charged: money.charged,
      firstFree: money.free.isEmpty ? null : money.free.first,
    );
  }
}
