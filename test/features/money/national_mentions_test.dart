// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2356 — what a member state's own law adds to an invoice (the Italian
// stamp duty, the Spanish correcting invoice, the French category of the
// operation), the EU small-enterprise scheme's EX number, and the rates
// that moved carried as dated versions.
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/report_data.dart';
import 'package:deskilo/features/money/domain/report_strings.dart';
import 'package:deskilo/features/money/domain/vat_catalogue.dart';
import 'package:deskilo/features/money/domain/vat_compliance.dart';
import 'package:deskilo/features/money/domain/vat_regime.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> _mentions(
  String country, {
  VatRegime regime = VatRegime.vatRegistered,
  String currency = 'EUR',
  int untaxed = 0,
  bool correction = false,
  String rectifies = '',
}) => nationalInvoiceMentions(
  sellerCountry: country,
  regime: regime,
  currency: currency,
  untaxedCents: untaxed,
  correction: correction,
  rectifies: rectifies,
);

void main() {
  test('Italy: the stamp duty above € 77.47 not subject to VAT, in euros', () {
    expect(_mentions('IT', untaxed: 7747), isEmpty);
    expect(_mentions('IT', untaxed: 7748).single, contains('642/1972'));
    expect(_mentions('IT', untaxed: 50000, currency: 'USD'), isEmpty);
  });

  test('Spain: a correcting invoice says so and names what it rectifies', () {
    expect(_mentions('ES'), isEmpty);
    expect(
      _mentions('ES', correction: true, rectifies: 'F-2026-0007').single,
      'Factura rectificativa (art. 15 del RD 1619/2012) de la factura '
      'F-2026-0007.',
    );
  });

  test('France: a VAT-registered seller states the category of the '
      'operation; an association outside the scope does not', () {
    expect(_mentions('FR').single, contains('prestation de services'));
    expect(_mentions('FR', regime: VatRegime.notSubject), isEmpty);
    expect(_mentions('DE'), isEmpty);
  });

  test('the EX number of the EU small-enterprise scheme', () {
    expect(looksLikeEuVatId('ATU12345678EX'), isTrue);
    expect(looksLikeEuVatId('ATU1234EX'), isFalse);
    final mention = defaultExemptionMention(
      'DE',
      VatRegime.exempt,
      vatId: 'ATU12345678EX',
    );
    expect(mention, contains('art. 284'));
    expect(mention, contains('ATU12345678EX'));
    expect(
      defaultExemptionMention('DE', VatRegime.exempt),
      'Steuerbefreiung für Kleinunternehmer, § 19 UStG.',
    );
  });

  test('the Italian stamp duty reaches the printed special mentions', () {
    final invoice = Invoice.fromRow({
      'id': 'i',
      'workspace_id': 'w',
      'member_id': 'm',
      'number': 'FT-1',
      'issued_at': '2026-10-01T09:00:00Z',
      'period': '2026-09',
      'title': '2026-09',
      'lines': [
        {
          'kind': 'subscription',
          'label': '',
          'amount_cents': 12000,
          'vat_percent': 0,
          'vat_category': 'E',
        },
      ],
      'total_cents': 12000,
      'currency': 'EUR',
      'member_name': 'B',
      'member_address': '',
      'workspace_name': 'W',
      'workspace_address': '',
      'issuer_name': 'F',
      'signature': 'f' * 64,
      'parties': {
        'seller': {
          'name': 'W',
          'country': 'IT',
          'vat_regime': 'exempt',
          'vat_id': 'IT12345678901',
        },
        'buyer': {'name': 'B', 'country': 'IT'},
      },
      'vat_totals': [
        {
          'percent': 0,
          'category': 'E',
          'gross_cents': 12000,
          'net_cents': 12000,
          'vat_cents': 0,
        },
      ],
    });
    final data = invoiceReportData(
      const ReportStrings(),
      invoice,
      proforma: false,
      copy: false,
    );
    expect('${data['special_mentions']}', contains('Imposta di bollo'));
  });

  test('the rates that moved are dated versions', () {
    expect(vatCatalogueFor('EE').first.validFrom, '2025-07-01');
    expect(vatCatalogueFor('FI').first.validFrom, '2024-09-01');
    expect(vatCatalogueFor('RO').first.validFrom, '2025-08-01');
    expect(vatCatalogueFor('SK').first.validFrom, '2025-01-01');
    expect(vatCatalogueFor('CH').first.validFrom, '2024-01-01');
    expect(vatCatalogueFor('FR').first.validFrom, '1900-01-01');
    expect(vatCatalogueFor('EE').first.isDated, isTrue);
  });
}
