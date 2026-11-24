// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4162 (X1.A) -- the readers of a line that carries the commercial contract:
// a printed document states its exact quantity, unit and entered price, never
// the legacy integer or a divided total; a legacy line prints as it always
// did.
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/domain/report_data.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter_test/flutter_test.dart';

final _words = ReportStrings(
  participation: (pct) => 'P $pct',
  participationMonth: (month, pct) => 'P $month $pct',
  subscription: (pct) => 'S $pct',
  subscriptionMonth: (month, pct) => 'S $month $pct',
);

const _workspace = Workspace(
  id: 'ws-1',
  name: 'Espace',
  countryCode: 'FR',
  currencyCode: 'EUR',
  timezone: 'Europe/Paris',
  inviteCode: 'CODE123456',
);

const _seller = InvoiceParty(
  name: 'Espace',
  street: '4 rue X',
  city: 'Paris',
  postalCode: '75001',
  country: 'FR',
  legalId: '10825191900016',
);

Map<String, Object?> _commercial(String quantity) => <String, Object?>{
  'kind': 'service',
  'label': 'Consulting',
  'quantity': 1,
  'amount_cents': 14520,
  'commercial': {
    'version': 1,
    'line_id': 'L-1',
    'quantity': quantity,
    'unit': {'code': 'hour', 'un_ece_code': 'HUR', 'label': 'h'},
    'unit_price': {
      'amount': '80',
      'currency': 'EUR',
      'basis': 'net',
      'base_quantity': '1',
    },
    'supply': 'general',
    'tax_facts': <String, Object?>{},
    'amounts': {
      'currency': 'EUR',
      'net_minor': '12000',
      'tax_minor': '2520',
      'gross_minor': '14520',
    },
  },
};

Invoice _invoice(List<InvoiceLine> lines) => Invoice(
  id: 'inv-1',
  workspaceId: 'ws-1',
  memberId: 'm1',
  number: 'F-2026-0001',
  issuedAt: DateTime(2026, 9),
  title: 'T',
  lines: lines,
  totalCents: 14520,
  currency: 'EUR',
  memberName: 'Ana',
  memberAddress: '',
  workspaceName: 'Espace',
  workspaceAddress: '',
  issuerName: 'Flo',
  signature: 'f' * 64,
  sellerParty: _seller,
);

Map<String, Object?> _lineOf(Invoice invoice) {
  final data = invoiceReportData(
    _words,
    invoice,
    proforma: false,
    copy: false,
    workspace: _workspace,
    reference: ActiveTaxReference.current,
  );
  return (data['lines']! as List).single as Map<String, Object?>;
}

void main() {
  test('a commercial line prints its exact quantity, unit and entered price', () {
    final line = _lineOf(_invoice([invoiceLineFromSnapshot(_commercial('1.5'))]));
    expect(line['qty'], '1.5 h');
    expect(line['unit_price'], '80');
  });

  test('a commercial line prints the net the server froze, never a split of its gross', () {
    // #4162 (X1.B) -- the snapshot names no rate, so a split of the gross
    // would print the whole 145.20 as net; the frozen net is 120.00.
    final line = _lineOf(_invoice([invoiceLineFromSnapshot(_commercial('1.5'))]));
    expect(line['net'], contains('120'));
    expect(line['net'], isNot(contains('145')));
  });

  test('a legacy line prints as it always did', () {
    final line = _lineOf(
      _invoice([
        const InvoiceLine(kind: 'service', label: 'Coffee', quantity: 3, amountCents: 900),
      ]),
    );
    expect(line['qty'], '3');
    expect(line['unit_price'], isNot('80'));
  });

  test('a line this reader cannot interpret prints no default quantity', () {
    final unsupported = _commercial('0.75');
    (unsupported['commercial']! as Map)['version'] = 9;
    final line = _lineOf(_invoice([invoiceLineFromSnapshot(unsupported)]));
    expect(line['qty'], '0.75');
    expect(line['unit_price'], '');
    final unreadable = _commercial('many');
    (unreadable['commercial']! as Map)['version'] = 9;
    expect(_lineOf(_invoice([invoiceLineFromSnapshot(unreadable)]))['qty'], '');
  });
}
