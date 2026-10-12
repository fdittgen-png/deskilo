// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2354 — the recapitulative statement (EU sales list) sums, per month and
// customer VAT number, only what was reverse-charged (category AE) on
// issued, not voided documents; desks at domestic VAT never appear.
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/recapitulative_statement.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:flutter_test/flutter_test.dart';

Invoice _invoice(
  String id,
  DateTime issued, {
  List<InvoiceVatTotal> vat = const [],
  String vatId = 'DE 123 456 789',
  String country = 'DE',
  bool voided = false,
}) => Invoice(
  id: id,
  workspaceId: 'ws-1',
  memberId: 'member-1',
  number: 'INV-$id',
  issuedAt: issued,
  period: '2026-09',
  title: 'INV-$id',
  lines: const [],
  totalCents: 0,
  currency: 'EUR',
  memberName: 'Kunde',
  memberAddress: '',
  workspaceName: 'Demo',
  workspaceAddress: '',
  issuerName: '',
  signature: '',
  vatTotals: vat,
  voidedAt: voided ? issued : null,
  buyerParty: InvoiceParty(
    name: 'Kunde',
    company: 'Kunde GmbH',
    country: country,
    vatId: vatId,
  ),
);

const _ae1500 = InvoiceVatTotal(
  percent: 0,
  category: 'AE',
  grossCents: 1500,
  netCents: 1500,
  vatCents: 0,
);
const _s3500 = InvoiceVatTotal(
  percent: 20,
  category: 'S',
  grossCents: 3500,
  netCents: 2917,
  vatCents: 583,
);

void main() {
  final from = DateTime(2026, 9);
  final to = DateTime(2026, 10);

  test('only reverse-charged amounts, per month and customer number', () {
    final lines = recapitulativeStatement(
      [
        _invoice('1', DateTime(2026, 9, 3), vat: const [_s3500, _ae1500]),
        _invoice(
          '2',
          DateTime(2026, 9, 20),
          vat: const [_ae1500],
          vatId: 'DE123456789',
        ),
        _invoice('3', DateTime(2026, 9, 21), vat: const [_s3500]),
        _invoice(
          '4',
          DateTime(2026, 9, 22),
          vat: const [_ae1500],
          voided: true,
        ),
        _invoice('5', DateTime(2026, 10), vat: const [_ae1500]),
      ],
      from: from,
      to: to,
    );
    expect(lines, hasLength(1));
    expect(lines.single.period, '2026-09');
    expect(lines.single.country, 'DE');
    expect(lines.single.vatNumber, '123456789');
    expect(lines.single.customer, 'Kunde GmbH');
    expect(lines.single.netCents, 3000);
    expect(lines.single.invoices, 2);
  });

  test('Greece is EL in the list, whatever the country code says', () {
    final lines = recapitulativeStatement(
      [
        _invoice(
          '1',
          DateTime(2026, 9, 3),
          vat: const [_ae1500],
          vatId: '094014201',
          country: 'GR',
        ),
      ],
      from: from,
      to: to,
    );
    expect(lines.single.country, 'EL');
  });

  test('the CSV has fixed headers and a dotted amount', () {
    final csv = recapitulativeCsv(const [
      RecapitulativeLine(
        period: '2026-09',
        country: 'DE',
        vatNumber: '123456789',
        customer: 'Kunde, GmbH',
        netCents: -1505,
        invoices: 1,
      ),
    ]);
    expect(
      csv,
      'period,country,vat_number,customer,amount,documents\r\n'
      '2026-09,DE,123456789,"Kunde, GmbH",-15.05,1\r\n',
    );
  });
}
