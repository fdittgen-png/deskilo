// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1294 — reading what a workspace says a new member starts with.
//
// The server decides and applies these; the client only renders them.
// So the failure this guards is a misread: showing 100% where the
// workspace said 50 would tell an owner their configuration did not
// take, and showing "configured" for an unset workspace would hide that
// the product default is what is actually in force.
import 'package:deskilo/features/workspace/domain/new_member_defaults.dart';
import 'package:deskilo/features/workspace/domain/overage_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an unconfigured workspace reads as the product defaults', () {
    const unset = NewMemberDefaults();
    expect(unset.subscriptionPct, 100);
    expect(unset.overagePolicy, OveragePolicy.blocked);
    expect(unset.configured, isFalse,
        reason: '"nobody chose" and "chose the same as the default" must '
            'stay distinguishable — only one of them follows the product '
            'default when it changes');

    expect(NewMemberDefaults.fromRules(null), unset);
    expect(NewMemberDefaults.fromRules(const {}), unset);
  });

  test('it reads what the workspace configured', () {
    final d = NewMemberDefaults.fromRules(const {
      'new_member_defaults': {'subscription_pct': 50, 'overage_policy': 'payg'},
    });
    expect(d.subscriptionPct, 50);
    expect(d.overagePolicy, OveragePolicy.payg);
    expect(d.configured, isTrue);
  });

  test('a percentage outside 1..100 falls back rather than showing a lie', () {
    // The server refuses these, so seeing one means a row written before
    // the rule existed — or by something else. The screen shows the
    // default rather than a value no member could ever have.
    for (final bad in [0, -5, 101, 1000]) {
      expect(
        NewMemberDefaults.fromRules({
          'new_member_defaults': {'subscription_pct': bad},
        }).subscriptionPct,
        100,
        reason: '$bad is not a subscription a member can hold',
      );
    }
  });

  test('a number written as text is still a number', () {
    expect(
      NewMemberDefaults.fromRules(const {
        'new_member_defaults': {'subscription_pct': '50'},
      }).subscriptionPct,
      50,
    );
  });

  test('an unknown overage policy reads as blocked', () {
    expect(
      NewMemberDefaults.fromRules(const {
        'new_member_defaults': {'overage_policy': 'something_new'},
      }).overagePolicy,
      OveragePolicy.blocked,
      reason: 'an older client must survive a newer server, and blocked '
          'is the safe reading — it books nothing it should not',
    );
  });

  test('a malformed value does not break the screen', () {
    expect(
      NewMemberDefaults.fromRules(const {'new_member_defaults': 'nonsense'}),
      const NewMemberDefaults(),
    );
  });

  test('toValue writes what the server reads back', () {
    const d = NewMemberDefaults(
      subscriptionPct: 25,
      overagePolicy: OveragePolicy.package,
      configured: true,
    );
    expect(d.toValue(), {'subscription_pct': 25, 'overage_policy': 'package'});
    expect(
      NewMemberDefaults.fromRules({'new_member_defaults': d.toValue()}),
      d,
      reason: 'a round trip through the wire must not change the meaning',
    );
  });
}
