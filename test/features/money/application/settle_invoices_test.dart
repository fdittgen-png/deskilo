// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1449 — which invoices may be regrouped, as a rule rather than five
// conditions inside a builder.
//
// Each exclusion is a reason, and together they are the difference
// between a regrouping that is honest and one that quietly swallows a
// document somebody is in the middle of. They lived in `_candidates` on
// the sheet, where the only way to check them was to pump it and count
// rows.
import 'package:deskilo/features/money/application/settle_invoices.dart';
import 'package:deskilo/features/money/domain/billing_rules.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:flutter_test/flutter_test.dart';

Invoice _invoice({
  String id = 'i',
  String memberId = 'm-1',
  bool voided = false,
  String? settledBy,
  InvoiceKind kind = InvoiceKind.usage,
}) =>
    Invoice(
      id: id,
      workspaceId: 'ws-1',
      memberId: memberId,
      number: id.toUpperCase(),
      issuedAt: DateTime.utc(2026, 9, 1),
      period: '2026-09',
      title: 'Invoice',
      lines: const [],
      totalCents: 1000,
      currency: 'EUR',
      memberName: 'Ada',
      memberAddress: '',
      workspaceName: 'Space',
      workspaceAddress: '',
      issuerName: '',
      signature: '',
      voidedAt: voided ? DateTime.utc(2026, 9, 2) : null,
      settledByInvoiceId: settledBy,
      kind: kind,
    );

({Invoice invoice, dynamic pendingMatch}) _open(
  Invoice invoice, {
  Object? match,
}) =>
    (invoice: invoice, pendingMatch: match);

void main() {
  test('an ordinary open invoice of the member may be regrouped', () {
    expect(
      settlementCandidates([_open(_invoice(id: 'a'))], 'm-1').map((i) => i.id),
      ['a'],
    );
  });

  test('somebody else\'s invoice never joins', () {
    expect(
      settlementCandidates([_open(_invoice(memberId: 'm-2'))], 'm-1'),
      isEmpty,
    );
  });

  test('a voided invoice is not a debt', () {
    expect(settlementCandidates([_open(_invoice(voided: true))], 'm-1'),
        isEmpty);
  });

  test('one already settled is already in a regrouping', () {
    expect(
      settlementCandidates([_open(_invoice(settledBy: 'other'))], 'm-1'),
      isEmpty,
      reason: 'joining it to a second one would point two documents at '
          'the same debt',
    );
  });

  test('a settlement does not regroup settlements', () {
    expect(
      settlementCandidates(
          [_open(_invoice(kind: InvoiceKind.settlement))], 'm-1'),
      isEmpty,
    );
  });

  test('one with a payment awaiting a decision is left alone', () {
    expect(
      settlementCandidates([_open(_invoice(), match: Object())], 'm-1'),
      isEmpty,
      reason: 'somebody is in the middle of deciding about that money',
    );
  });

  group('two is the minimum', () {
    test('because regrouping one invoice is that invoice', () {
      expect(isRegrouping([_invoice(id: 'a')]), isFalse,
          reason: 'a settlement of one is a second number pointing at the '
              'first');
      expect(isRegrouping([]), isFalse);
    });

    test('and two is a regrouping', () {
      expect(isRegrouping([_invoice(id: 'a'), _invoice(id: 'b')]), isTrue);
    });
  });
}
