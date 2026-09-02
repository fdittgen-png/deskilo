// SPDX-License-Identifier: 0BSD
//
// #828 — the repartition arithmetic: every method's weights, the exact
// sum, the leftover cents, zero weights, negative amounts.
import 'package:deskilo/features/money/domain/expense_repartition.dart';
import 'package:flutter_test/flutter_test.dart';

RepartitionMember _m(String id,
        {int pct = 100, num days = 0, num custom = 0}) =>
    (id: id, name: id, subscriptionPct: pct, usageDays: days, customWeight: custom);

int _sum(List<RepartitionShare> shares) =>
    shares.fold(0, (s, x) => s + x.amountCents);

void main() {
  test('equal shares add up exactly; the leftover cents go one each to the '
      'first members', () {
    final shares = distributeExpense(
      amountCents: 10000,
      members: [_m('a'), _m('b'), _m('c')],
      method: RepartitionMethod.equal,
    );
    expect(shares.map((s) => s.amountCents), [3334, 3333, 3333]);
    expect(_sum(shares), 10000);
  });

  test('pro rata of the subscription percentage', () {
    final shares = distributeExpense(
      amountCents: 9000,
      members: [_m('a', pct: 100), _m('b', pct: 50), _m('c', pct: 30)],
      method: RepartitionMethod.subscription,
    );
    expect(shares.map((s) => s.amountCents), [5000, 2500, 1500]);
    expect(_sum(shares), 9000);
  });

  test('pro rata of usage days leaves out whoever used nothing; the '
      'largest fraction takes the odd cent', () {
    final shares = distributeExpense(
      amountCents: 1001,
      members: [_m('a', days: 1), _m('b', days: 2), _m('c', days: 0)],
      method: RepartitionMethod.usage,
    );
    expect(shares.map((s) => s.memberId), ['a', 'b']);
    // Exact: 333.67 and 667.33 — b's floor is 667, a's fraction .67 wins
    // the leftover cent.
    expect(shares.map((s) => s.amountCents), [334, 667]);
    expect(_sum(shares), 1001);
  });

  test('a custom key, and a reversal splits the same way but negative', () {
    final shares = distributeExpense(
      amountCents: -700,
      members: [_m('a', custom: 3), _m('b', custom: 4)],
      method: RepartitionMethod.custom,
    );
    expect(shares.map((s) => s.amountCents), [-300, -400]);
    expect(_sum(shares), -700);
  });

  test('nothing to split: no members with weight, or a zero amount', () {
    expect(
        distributeExpense(
            amountCents: 500,
            members: [_m('a', days: 0)],
            method: RepartitionMethod.usage),
        isEmpty);
    expect(
        distributeExpense(
            amountCents: 0, members: [_m('a')], method: RepartitionMethod.equal),
        isEmpty);
  });

  test('the method round-trips by name', () {
    expect(RepartitionMethod.fromWire('usage'), RepartitionMethod.usage);
    expect(RepartitionMethod.fromWire('nope'), RepartitionMethod.equal);
  });
}
