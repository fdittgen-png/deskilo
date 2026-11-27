// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4492 — ONE price in the Demo's Leipzig space: the fee band a plan reads
// (the members' "plan fee" column, the live statement) is the fee that plan
// is invoiced every month. The store's default bands (150 / 250) stood beside
// invoices of 95 / 190 before.
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/core/demo/seed/demo_second_space_money_seed.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a plan is invoiced the fee of its band', () {
    final money = FakeMoneyRepository();
    seedLeipzigMoney(money, DateTime(2026, 5, 13));
    int band(int pct) => money.feeBands
        .firstWhere((b) => b.fromPct < pct && pct <= b.toPct)
        .feeCents;
    int invoiced(String member) => money.invoices
        .firstWhere((i) => i.id == 'de-inv-$member-2026-05')
        .totalCents;
    // Mehmet and Ada hold a 50 % plan, Lena a full one.
    expect(band(50), invoiced('de-member-mehmet'));
    expect(band(50), invoiced('member-1'));
    expect(band(100), invoiced('de-member-lena'));
  });
}
