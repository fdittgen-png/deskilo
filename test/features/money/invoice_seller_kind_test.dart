// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3875 — the word of the recurring line (participation or subscription) is
// the seller kind the invoice was ISSUED under: the snapshot's when the
// invoice has one, the live business's only for an invoice without.
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/domain/invoice_line_text.dart';
import 'package:deskilo/features/money/domain/report_data.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter_test/flutter_test.dart';

final _words = ReportStrings(
  participation: (pct) => 'PARTICIPATION $pct',
  participationMonth: (month, pct) => 'PARTICIPATION $month $pct',
  subscription: (pct) => 'SUBSCRIPTION $pct',
  subscriptionMonth: (month, pct) => 'SUBSCRIPTION $month $pct',
);

Workspace _business(String kind) => Workspace(
  id: 'ws-1',
  name: 'Espace',
  countryCode: 'FR',
  currencyCode: 'EUR',
  timezone: 'Europe/Paris',
  inviteCode: 'CODE123456',
  invoiceLegal: {'seller_kind': kind},
);

Invoice _invoice({String? frozenKind, int cents = 12000}) => Invoice(
  id: 'inv-1',
  workspaceId: 'ws-1',
  memberId: 'm1',
  number: 'F-2026-0001',
  issuedAt: DateTime(2026, 9),
  title: '2026-09',
  period: '2026-09',
  // Not const: each invoice owns its line objects, as a parsed row does.
  lines: [InvoiceLine(kind: 'subscription', label: '100', amountCents: cents)],
  totalCents: 12000,
  currency: 'EUR',
  memberName: 'Ana Martin',
  memberAddress: '',
  workspaceName: 'Espace',
  workspaceAddress: '',
  issuerName: 'Espace',
  signature: 'sig',
  legalSnapshot: frozenKind == null
      ? null
      : {
          'schema': 1,
          'seller_kind': frozenKind,
          'seller_country': 'FR',
          'buyer_country': 'FR',
          'buyer_capacity': 'business',
          'clauses': <String, Object?>{},
        },
);

String _printed(Invoice invoice, String liveKind) {
  final data = invoiceReportData(
    _words,
    invoice,
    proforma: false,
    copy: false,
    workspace: _business(liveKind),
    reference: ActiveTaxReference.current,
  );
  return ((data['lines']! as List).single as Map)['label']! as String;
}

void main() {
  group('the seller kind of an invoice', () {
    test('the snapshot wins over the live value, both ways', () {
      expect(
        _invoice(frozenKind: 'association').sellerKindOr('company'),
        'association',
      );
      expect(
        _invoice(frozenKind: 'company').sellerKindOr('association'),
        'company',
      );
      expect(
        _invoice(frozenKind: 'association').sellerIsAssociationOr(false),
        isTrue,
      );
      expect(
        _invoice(frozenKind: 'company').sellerIsAssociationOr(true),
        isFalse,
      );
    });

    test('an invoice without a snapshot follows the live value', () {
      expect(_invoice().sellerKindOr('association'), 'association');
      expect(_invoice().sellerIsAssociationOr(true), isTrue);
      expect(_invoice().sellerIsAssociationOr(false), isFalse);
    });
  });

  group('the recurring line of an issued invoice', () {
    test('report data: frozen association, business now a company', () {
      expect(
        _printed(_invoice(frozenKind: 'association'), 'company'),
        startsWith('PARTICIPATION'),
      );
    });

    test('report data: frozen company, business now an association', () {
      expect(
        _printed(_invoice(frozenKind: 'company'), 'association'),
        startsWith('SUBSCRIPTION'),
      );
    });

    test('report data: no snapshot follows the business as before', () {
      expect(_printed(_invoice(), 'association'), startsWith('PARTICIPATION'));
      expect(_printed(_invoice(), 'company'), startsWith('SUBSCRIPTION'));
    });

    test(
      'the line text of one invoice (e-invoice, PDF) reads its snapshot',
      () {
        final frozen = _invoice(frozenKind: 'association');
        expect(
          invoiceLineTextFor(
            _words,
            frozen,
            frozen.lines.single,
            liveAssociation: false,
          ),
          startsWith('PARTICIPATION'),
        );
      },
    );

    test('a book of several invoices words each by its own kind', () {
      final a = _invoice(frozenKind: 'association');
      final c = _invoice(frozenKind: 'company');
      final text = invoiceLineTextOfBooks(_words, [
        a,
        c,
      ], liveAssociation: false);
      expect(text(a.lines.single), startsWith('PARTICIPATION'));
      expect(text(c.lines.single), startsWith('SUBSCRIPTION'));
    });
  });
}
