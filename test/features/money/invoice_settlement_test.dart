// SPDX-License-Identifier: 0BSD
//
// #804 — several open invoices regrouped into ONE the member pays.
//
// The sources are NOT voided and NOT replaced. They stay in the archive
// exactly as issued and each gains a pointer to the document that settled
// it, so the trail runs both ways: from a source to the demand that now
// covers it, and from the settlement to every position of every invoice
// inside it.
//
// The server half (migration 0143) was verified live in a rolled-back
// transaction, 13 assertions — including that the sources survive
// unvoided, that VAT is not restated, that a settlement cannot itself be
// settled, that another member's invoice cannot be folded in, and that
// the document's CONTENT is still immutable. These pin the client's half.
import 'package:deskilo/features/money/domain/billing_rules.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';

Map<String, dynamic> invoiceRow({
  String id = 'i1',
  String number = 'INV-2026-0001',
  String kind = 'full',
  String? settledBy,
  List<Map<String, dynamic>> settles = const [],
}) =>
    {
      'id': id,
      'workspace_id': 'ws-1',
      'member_id': 'm1',
      'number': number,
      'issued_at': '2026-09-01T10:00:00Z',
      'period': '2026-09',
      'title': '2026-09',
      'lines': const [],
      'total_cents': 5000,
      'currency': 'EUR',
      'member_name': 'Flo',
      'member_address': '',
      'workspace_name': 'Space',
      'workspace_address': '',
      'issuer_name': 'Owner',
      'signature': 'abc',
      'kind': kind,
      'settled_by_invoice_id': settledBy,
      'settles': settles,
    };

void main() {
  group('the trail is readable from the document', () {
    test('a settlement carries its sources AND their positions', () {
      final invoice = Invoice.fromRow(invoiceRow(
        kind: 'settlement',
        settles: [
          {
            'invoice_id': 'i-a',
            'number': 'INV-2026-0001',
            'period': '2026-08',
            'kind': 'subscription',
            'total_cents': 12000,
            'lines': [
              {
                'kind': 'subscription',
                'label': '100',
                'quantity': 1,
                'amount_cents': 12000,
                'vat_percent': 19.0,
              },
            ],
          },
          {
            'invoice_id': 'i-b',
            'number': 'INV-2026-0002',
            'period': '2026-08',
            'kind': 'usage',
            'total_cents': 3000,
            'lines': const [],
          },
        ],
      ));

      expect(invoice.kind, InvoiceKind.settlement);
      expect(invoice.settles, hasLength(2));
      final first = invoice.settles.first;
      expect(first.number, 'INV-2026-0001');
      expect(first.kind, InvoiceKind.subscription);
      expect(first.totalCents, 12000);
      // The POSITIONS of the original, not just its number — a trail that
      // stops at a reference is not a trail.
      expect(first.lines.single.amountCents, 12000);
      expect(first.lines.single.vatPercent, 19.0);
    });

    test('a settled invoice knows what now carries its balance', () {
      final invoice = Invoice.fromRow(invoiceRow(settledBy: 'i-settlement'));
      expect(invoice.settledByInvoiceId, 'i-settlement');
      // And it is NOT voided: the document stands exactly as issued.
      expect(invoice.isVoided, isFalse);
    });

    test('an ordinary invoice carries neither', () {
      final invoice = Invoice.fromRow(invoiceRow());
      expect(invoice.settledByInvoiceId, isNull);
      expect(invoice.settles, isEmpty);
    });

    test('a pre-0143 row parses with the columns absent', () {
      final row = invoiceRow()
        ..remove('settled_by_invoice_id')
        ..remove('settles');
      final invoice = Invoice.fromRow(row);
      expect(invoice.settledByInvoiceId, isNull);
      expect(invoice.settles, isEmpty);
    });
  });

  group('the write path', () {
    test('regrouping asks the server for exactly the chosen invoices',
        () async {
      final money = FakeMoneyRepository();
      final id = await money.settleInvoices(
        workspaceId: 'ws-1',
        memberId: 'm1',
        invoiceIds: ['i-a', 'i-b', 'i-c'],
      );
      expect(id, money.nextSettlementId);
      expect(money.settlements.single.memberId, 'm1');
      expect(money.settlements.single.invoiceIds, ['i-a', 'i-b', 'i-c']);
    });

    test('one invoice is not a regrouping', () async {
      // The word means nothing for a single document, and the server
      // raises 'settle at least two invoices' either way.
      final money = FakeMoneyRepository();
      await expectLater(
        money.settleInvoices(
          workspaceId: 'ws-1',
          memberId: 'm1',
          invoiceIds: ['i-a'],
        ),
        throwsStateError,
      );
      expect(money.settlements, isEmpty);
    });
  });
}
