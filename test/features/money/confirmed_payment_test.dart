// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-d -- after a confirmation, the payment the invoice page matches:
// the newest payment of exactly the confirmed amount, of the same customer,
// that no match has consumed -- never another customer's, never on an
// invoice in another currency than the account's; and what the gesture
// ended in, read from the match the server now has.
import 'package:deskilo/features/money/application/confirmed_payment.dart';
import 'package:deskilo/features/money/application/payment_candidates.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter_test/flutter_test.dart';

LedgerEntry _entry(
  String id,
  int amount, {
  String member = 'kalo',
  LedgerKind kind = LedgerKind.credit,
  LedgerCategory category = LedgerCategory.payment,
  int day = 1,
}) => LedgerEntry(
  id: id,
  memberId: member,
  kind: kind,
  category: category,
  amountCents: amount,
  description: '',
  period: '2026-11',
  createdAt: DateTime(2026, 11, day),
);

PaymentUse _used(Map<String, int> cents) => PaymentUse(usedCents: cents);

String? _pick(
  List<LedgerEntry> ledger, {
  PaymentUse use = PaymentUse.none,
  String invoiceCurrency = 'CHF',
}) => confirmedPaymentFor(
  ledger,
  customerId: 'kalo',
  amountCents: 42000,
  invoiceCurrency: invoiceCurrency,
  accountCurrency: 'CHF',
  use: use,
);

void main() {
  test('the newest free payment of exactly the amount', () {
    final ledger = [
      _entry('old', 42000),
      _entry('new', 42000, day: 9),
      _entry('other', 41999, day: 10),
      _entry('charge', 42000, kind: LedgerKind.charge, day: 10),
      _entry('adjust', 42000, category: LedgerCategory.adjustment, day: 10),
    ];
    expect(_pick(ledger), 'new');
    expect(_pick(ledger, use: _used({'new': 42000})), 'old');
    expect(_pick(ledger, use: _used({'new': 42000, 'old': 42000})), isNull);
  });

  test('a payment partly used is free for what is left of it only', () {
    final ledger = [_entry('part', 50000)];
    expect(_pick(ledger), isNull, reason: '50000 is not 42000');
    expect(_pick(ledger, use: _used({'part': 8000})), 'part');
    expect(_pick(ledger, use: _used({'part': 50000})), isNull);
    expect(_pick(ledger, use: _used({'part': 9000})), isNull);
  });

  test('never another customer\'s payment, never across currencies', () {
    final ledger = [_entry('theirs', 42000, member: 'nord', day: 9)];
    expect(_pick(ledger), isNull);
    expect(_pick([_entry('mine', 42000)], invoiceCurrency: 'EUR'), isNull);
  });

  test('the outcome is read from the match the server now has', () {
    InvoiceMatch match({required String status}) => InvoiceMatch(
      invoiceId: 'i',
      paidCents: 42000,
      resolution: 'exact',
      status: status,
      matchedAt: DateTime(2026, 11, 10),
    );
    expect(outcomeOfMatch(null), ConfirmOutcome.confirmedOnly);
    expect(
      outcomeOfMatch(match(status: 'pending')),
      ConfirmOutcome.awaitsApproval,
    );
    expect(outcomeOfMatch(match(status: 'confirmed')), ConfirmOutcome.matched);
  });
}
