// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1449 A4 — the same share writes nothing; no subscription with
// pay-as-you-go is refused; 0 and 1-100 are written otherwise; a server
// refusal propagates.
import 'package:deskilo/features/workspace/application/set_member_subscription.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/overage_policy.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/mock_providers.dart';

Member _member(
  FakeWorkspaceRepository repo, {
  int pct = 50,
  OveragePolicy policy = OveragePolicy.blocked,
}) => repo.myMember.copyWith(subscriptionPct: pct, overagePolicy: policy);

class _Refusing extends FakeWorkspaceRepository {
  _Refusing() : super.withWorkspace();
  @override
  Future<void> updateMemberSubscription(String memberId, int pct) async =>
      throw StateError('refused');
}

void main() {
  test('the rule', () {
    final repo = FakeWorkspaceRepository.withWorkspace();
    final m = _member(repo);
    expect(subscriptionChange(m, 50), SubscriptionChange.unchanged);
    expect(subscriptionChange(m, 101), SubscriptionChange.outOfRange);
    expect(subscriptionChange(m, -1), SubscriptionChange.outOfRange);
    expect(subscriptionChange(m, 0), SubscriptionChange.saved);
    expect(
      subscriptionChange(_member(repo, policy: OveragePolicy.payg), 0),
      SubscriptionChange.noneWithPayg,
    );
    expect(customShare(' 42 '), 42);
    expect(customShare('0'), isNull);
    expect(customShare('abc'), isNull);
  });

  test(
    'unchanged and refused choices write nothing; a permitted one is written',
    () async {
      final repo = FakeWorkspaceRepository.withWorkspace();
      final command = MemberSubscriptions(repo);
      final before = repo.myMember.subscriptionPct;
      expect(
        await command.set(_member(repo, pct: before), before),
        SubscriptionChange.unchanged,
      );
      expect(
        await command.set(_member(repo, policy: OveragePolicy.payg), 0),
        SubscriptionChange.noneWithPayg,
      );
      expect(repo.myMember.subscriptionPct, before);
      expect(
        await command.set(_member(repo, pct: 50), 0),
        SubscriptionChange.saved,
      );
      expect(repo.myMember.subscriptionPct, 0);
    },
  );

  test('a server refusal propagates', () async {
    final repo = _Refusing();
    await expectLater(
      MemberSubscriptions(repo).set(_member(repo), 30),
      throwsStateError,
    );
  });
}
