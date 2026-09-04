// SPDX-License-Identifier: 0BSD
//
// #870 — what the recurring position is CALLED is a tax question, not a
// wording preference. On a French association's invoice "abonnement"
// reads as a commercial supply and is the wording that argues the
// association into the VAT-liable trading sector; a non-profit collects
// a "participation". The owner of the pilot association asked for this
// in as many words, and the risk is real, so the choice is pinned here.
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_legal.dart';
import 'package:deskilo/features/money/presentation/invoice_line_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an association collects a participation, a company a subscription',
      () {
    expect(subscriptionLabel(null, 100, association: true),
        'Participation 100%');
    expect(subscriptionLabel(null, 50, association: false),
        'Subscription 50%');
  });

  test('the invoice line follows the same rule, and only for the '
      'subscription position', () {
    const line = InvoiceLine(
        kind: 'subscription', label: '100', amountCents: 10000);
    expect(invoiceLineText(null, line, association: true),
        'Participation 100%');
    expect(invoiceLineText(null, line, association: false),
        'Subscription 100%');

    // A position that is not the recurring one is untouched by the rule.
    const overage = InvoiceLine(
        kind: 'overage', label: '', quantity: 2, amountCents: 500);
    expect(invoiceLineText(null, overage, association: true),
        invoiceLineText(null, overage, association: false));
  });

  test('the seller kind is what decides it', () {
    expect(
      const InvoiceLegal(sellerKind: 'association').isAssociation,
      isTrue,
    );
    expect(const InvoiceLegal(sellerKind: 'company').isAssociation, isFalse);
    // An unset seller kind must not silently claim non-profit status.
    expect(const InvoiceLegal().isAssociation, isFalse);
  });

  test('defaulting to a subscription is the safe direction', () {
    // Omitting the flag must never turn a company's subscription into a
    // participation: the harm runs one way.
    const line = InvoiceLine(
        kind: 'subscription', label: '100', amountCents: 10000);
    expect(invoiceLineText(null, line), 'Subscription 100%');
  });
}
