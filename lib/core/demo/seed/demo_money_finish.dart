// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3601 -- the last steps of the Demo's money, in one place: the year of
// invoices, their VAT, the register's order and the plan prices the live
// statement charges.
import '../data/money_repository.dart';
import 'demo_money_seed.dart' show alignDemoBandsWithPlans;
import 'demo_year_seed.dart' show applyDemoVat, seedDemoYearOfMoney;

/// #3601 — the register of a month reads with the other members' invoices
/// first: the owner is a paying member and keeps every invoice of her own,
/// but a visitor's first impression of the register is not "the owner billing
/// herself". The seed issues a month's invoices on one day; the members'
/// invoices are issued an hour after the owner's, so the register (newest
/// first) lists them first. No date, amount or figure moves.
void _orderDemoRegister(FakeMoneyRepository money, {String owner = 'member-1'}) {
  for (var i = 0; i < money.invoices.length; i++) {
    final invoice = money.invoices[i];
    if (invoice.memberId == owner) continue;
    final day = invoice.issuedAt;
    // Only a day's start: an invoice already given an hour keeps it.
    if (day.hour == 0 && day.minute == 0) {
      money.invoices[i] = invoice.copyWith(
        issuedAt: day.add(const Duration(hours: 1)),
      );
    }
  }
}

/// The last steps of the Demo's money: the year of invoices, their VAT, the
/// register's order and the plan prices the live statement charges (#3601).
void finishDemoMoney(FakeMoneyRepository money, DateTime now) {
  seedDemoYearOfMoney(money, now);
  applyDemoVat(money);
  _orderDemoRegister(money);
  alignDemoBandsWithPlans(money, now);
}
