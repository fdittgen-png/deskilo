// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3618 — a selection's change of plan, pause or resume runs member by
// member on what the space holds NOW: every member gets an outcome, one that
// cannot be changed is named with its reason and left as it was, and a
// refusal of one does not stop the others.
import 'package:deskilo/features/members/application/member_batch_change.dart';
import 'package:deskilo/features/workspace/application/set_member_subscription.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/overage_policy.dart';
import 'package:flutter_test/flutter_test.dart';

Member _m(
  String id, {
  MemberStatus status = MemberStatus.active,
  int pct = 50,
  bool kiosk = false,
  OveragePolicy overage = OveragePolicy.blocked,
}) => Member(
  id: id,
  workspaceId: 'ws',
  userId: 'u-$id',
  isAdmin: false,
  isOwner: false,
  status: status,
  subscriptionPct: pct,
  isKiosk: kiosk,
  overagePolicy: overage,
);

/// The space's members as the commands see them, and what was sent.
class _Commands implements MemberChangeCommands {
  _Commands(this.now, {this.failing = const {}});

  final List<Member> now;
  final Set<String> failing;
  final sent = <String>[];

  @override
  Future<List<Member>> members() async => now;

  @override
  Future<void> setStatus(Member member, MemberStatus status) async {
    if (failing.contains(member.id)) throw StateError('refused');
    sent.add('${member.id}:${status.name}');
  }

  @override
  Future<SubscriptionChange> setShare(Member member, int pct) async {
    if (failing.contains(member.id)) throw StateError('refused');
    final change = subscriptionChange(member, pct);
    if (change == SubscriptionChange.saved) sent.add('${member.id}:$pct');
    return change;
  }
}

void main() {
  test(
    'a pause changes the active, names every other with its reason',
    () async {
      final commands = _Commands(
        [
          _m('a'),
          _m('p', status: MemberStatus.pending),
          _m('x', status: MemberStatus.exited),
          _m('k', kiosk: true),
          _m('z', status: MemberStatus.paused),
          _m('f'),
        ],
        failing: {'f'},
      );
      final outcomes = await applyMemberChange(commands, [
        'a',
        'p',
        'x',
        'k',
        'z',
        'f',
        'gone',
      ], const PauseMembers());
      expect(outcomes, {
        'a': MemberChangeOutcome.applied,
        'p': MemberChangeOutcome.pending,
        'x': MemberChangeOutcome.exited,
        'k': MemberChangeOutcome.kiosk,
        'z': MemberChangeOutcome.unchanged,
        'f': MemberChangeOutcome.failed,
        'gone': MemberChangeOutcome.gone,
      });
      // Only the one that could be changed was sent; the failure did not stop
      // the members after it.
      expect(commands.sent, ['a:paused']);
    },
  );

  test(
    'the rule is checked on the member as the space holds them now',
    () async {
      // Selected while active; paused since by someone else: a resume applies,
      // a pause is "already so" — nothing is decided on the stale row.
      final commands = _Commands([_m('a', status: MemberStatus.paused)]);
      expect(await applyMemberChange(commands, ['a'], const PauseMembers()), {
        'a': MemberChangeOutcome.unchanged,
      });
      expect(await applyMemberChange(commands, ['a'], const ResumeMembers()), {
        'a': MemberChangeOutcome.applied,
      });
      expect(commands.sent, ['a:active']);
    },
  );

  test(
    'a resume of an active member is already so, of a pending one refused',
    () async {
      final commands = _Commands([
        _m('a'),
        _m('p', status: MemberStatus.pending),
      ]);
      expect(
        await applyMemberChange(commands, ['a', 'p'], const ResumeMembers()),
        {'a': MemberChangeOutcome.unchanged, 'p': MemberChangeOutcome.pending},
      );
      expect(commands.sent, isEmpty);
    },
  );

  test(
    'a change of plan goes through the share rule, member by member',
    () async {
      final commands = _Commands([
        _m('a'),
        _m('same', pct: 75),
        _m('payg', overage: OveragePolicy.payg),
      ]);
      // No subscription with pay-as-you-go would book for free: refused for
      // that member only.
      expect(
        await applyMemberChange(commands, [
          'a',
          'same',
          'payg',
        ], const ChangePlan(0)),
        {
          'a': MemberChangeOutcome.applied,
          'same': MemberChangeOutcome.applied,
          'payg': MemberChangeOutcome.ruleRefused,
        },
      );
      expect(
        await applyMemberChange(commands, ['same'], const ChangePlan(75)),
        {'same': MemberChangeOutcome.unchanged},
      );
      expect(commands.sent, ['a:0', 'same:0']);
    },
  );
}
