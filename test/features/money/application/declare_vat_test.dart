// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1449 — the basis decides WHICH DOCUMENTS a VAT period declares, not
// only how much. The count printed on the form is counted on the same
// date as the money, and the rule used to live inside a closure on the
// declarations screen.
import 'package:deskilo/features/money/application/declare_vat.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:flutter_test/flutter_test.dart';

Invoice _invoice({
  required String id,
  required DateTime issuedAt,
  bool voided = false,
}) =>
    Invoice(
      id: id,
      workspaceId: 'ws-1',
      memberId: 'm-1',
      number: id.toUpperCase(),
      issuedAt: issuedAt,
      period: '2026-09',
      title: 'Invoice',
      lines: const [
        InvoiceLine(label: 'Desk', amountCents: 12000, vatPercent: 20),
      ],
      totalCents: 12000,
      currency: 'EUR',
      memberName: 'Ada',
      memberAddress: '',
      workspaceName: 'Space',
      workspaceAddress: '',
      issuerName: '',
      signature: '',
      voidedAt: voided ? DateTime.utc(2026, 10, 1) : null,
    );

InvoiceMatch _paidOn(String invoiceId, DateTime day) => InvoiceMatch(
      invoiceId: invoiceId,
      paidCents: 12000,
      resolution: 'paid',
      matchedAt: day,
    );

final _start = DateTime.utc(2026, 9);
final _end = DateTime.utc(2026, 9, 30);

VatDeclarationDraft _draft(
  List<Invoice> invoices, {
  Map<String, InvoiceMatch> matches = const {},
  bool onPaymentBasis = false,
}) =>
    vatDeclarationDraft(
      invoices: invoices,
      matches: matches,
      periodStart: _start,
      periodEnd: _end,
      onPaymentBasis: onPaymentBasis,
    );

void main() {
  test('on the accrual basis the period holds what it ISSUED', () {
    final draft = _draft([
      _invoice(id: 'a', issuedAt: DateTime.utc(2026, 9, 10)),
      _invoice(id: 'b', issuedAt: DateTime.utc(2026, 10, 2)),
    ]);
    expect(draft.invoiceCount, 1, reason: 'b was issued in October');
    expect(draft.totalVatCents, 2000);
  });

  test('on the cash basis it holds what was PAID inside it', () {
    final issuedInAugust = _invoice(id: 'a', issuedAt: DateTime.utc(2026, 8, 3));
    final draft = _draft(
      [issuedInAugust],
      matches: {'a': _paidOn('a', DateTime.utc(2026, 9, 12))},
      onPaymentBasis: true,
    );
    expect(draft.invoiceCount, 1,
        reason: 'the payment landed in September, so September declares it');
    expect(draft.totalVatCents, 2000);
  });

  test('an invoice paid AFTER the period is not in it, though it was issued '
      'inside it', () {
    final draft = _draft(
      [_invoice(id: 'a', issuedAt: DateTime.utc(2026, 9, 10))],
      matches: {'a': _paidOn('a', DateTime.utc(2026, 10, 4))},
      onPaymentBasis: true,
    );
    expect(draft.invoiceCount, 0);
    expect(draft.totalVatCents, 0);
  });

  test('an unpaid invoice is behind nothing on the cash basis', () {
    expect(
      _draft(
        [_invoice(id: 'a', issuedAt: DateTime.utc(2026, 9, 10))],
        onPaymentBasis: true,
      ).invoiceCount,
      0,
    );
  });

  test('a voided invoice is declared by neither basis', () {
    expect(
      _draft([
        _invoice(id: 'a', issuedAt: DateTime.utc(2026, 9, 10), voided: true),
      ]).invoiceCount,
      0,
    );
  });

  test('the last day of the period is inside it', () {
    expect(
      _draft([_invoice(id: 'a', issuedAt: DateTime.utc(2026, 9, 30, 23))])
          .invoiceCount,
      1,
      reason: 'a period that ends at midnight loses its last day',
    );
  });
}
