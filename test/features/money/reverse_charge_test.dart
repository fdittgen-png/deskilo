// SPDX-License-Identifier: 0BSD
//
// #895 — intra-EU B2B is the customer's tax. A VAT-registered seller
// invoicing a business in ANOTHER member state charges nothing: the
// document states category AE, carries the reverse-charge mention and
// names the customer's VAT identifier. Mirrors create_invoice (0157).
import 'dart:io';

import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_cii.dart';
import 'package:deskilo/features/money/domain/invoice_legal.dart';
import 'package:deskilo/features/money/domain/invoice_ubl.dart' show buildInvoiceUbl;
import 'package:deskilo/features/money/domain/invoice_ubl_check.dart';
import 'package:deskilo/features/money/domain/vat_compliance.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:deskilo/features/money/domain/vat_regime.dart';
import 'package:deskilo/features/money/presentation/invoice_actions.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:flutter_test/flutter_test.dart';

const _seller = InvoiceParty(
  name: 'Demo SARL',
  street: '4 avenue de Castelnau',
  city: 'Pézenas',
  postalCode: '34120',
  country: 'FR',
  vatId: 'FR12345678901',
  legalId: '680 357 910',
  vatRegime: 'vat_registered',
);

Invoice _invoice({required List<InvoiceVatTotal> vat, String buyerVat = 'DE123456789'}) =>
    Invoice(
      id: 'inv-1',
      workspaceId: 'ws-1',
      memberId: 'member-1',
      number: 'INV-2026-0100',
      issuedAt: DateTime(2026, 9, 5),
      period: '2026-09',
      title: 'INV-2026-0100',
      lines: const [
        InvoiceLine(kind: 'service', label: 'Salle', amountCents: 12000),
      ],
      totalCents: 12000,
      currency: 'EUR',
      memberName: 'Kunde GmbH',
      memberAddress: '',
      workspaceName: 'Demo SARL',
      workspaceAddress: '',
      issuerName: '',
      signature: '',
      vatTotals: vat,
      sellerParty: _seller,
      buyerParty: InvoiceParty(
          name: 'Kunde GmbH', country: 'DE', vatId: buyerVat),
    );

const _ae = InvoiceVatTotal(
    percent: 0, category: 'AE', grossCents: 12000, netCents: 12000, vatCents: 0);
const _s20 = InvoiceVatTotal(
    percent: 20, category: 'S', grossCents: 12000, netCents: 10000, vatCents: 2000);

void main() {
  group('the rule', () {
    bool applies({
      VatRegime regime = VatRegime.vatRegistered,
      String seller = 'FR',
      String buyer = 'DE',
      String buyerVat = 'DE123456789',
      bool optedOut = false,
    }) =>
        reverseChargeApplies(
          sellerRegime: regime,
          sellerCountry: seller,
          buyerCountry: buyer,
          buyerVatId: buyerVat,
          optedOut: optedOut,
        );

    test('a VAT-registered seller, an EU business abroad, a VAT id', () {
      expect(applies(), isTrue);
      expect(applies(buyer: 'fr'), isFalse, reason: 'at home the tax is ours');
      expect(applies(buyerVat: ''), isFalse,
          reason: 'no VAT id means a consumer, who pays the tax');
      expect(applies(buyer: 'CH'), isFalse, reason: 'outside the Union');
      expect(applies(regime: VatRegime.exempt), isFalse,
          reason: 'a seller who charges no VAT reverses nothing');
      expect(applies(optedOut: true), isFalse);
    });

    test('the member states, Greece under both its codes', () {
      expect(isEuCountry('el'), isTrue);
      expect(isEuCountry('GR'), isTrue);
      expect(isEuCountry('NO'), isFalse);
    });

    test('the mention speaks the seller\'s language and cites art. 196', () {
      expect(reverseChargeMention('FR'), contains('Autoliquidation'));
      expect(reverseChargeMention('DE'), contains('Steuerschuldnerschaft'));
      expect(reverseChargeMention('PL'), contains('Reverse charge'));
      for (final country in ['FR', 'DE', 'ES', 'IT', 'NL', 'PT', 'PL']) {
        expect(reverseChargeMention(country), contains('196'), reason: country);
      }
    });

    test('the switch survives the workspace round trip, default on', () {
      expect(const InvoiceLegal().reverseCharge, isTrue);
      final off = InvoiceLegal.fromJson(
          const InvoiceLegal(reverseChargeOptIn: false).toJson());
      expect(off.reverseCharge, isFalse);
    });
  });

  group('the document', () {
    test('says the tax is the customer\'s', () {
      expect(_invoice(vat: const [_ae]).isReverseCharged, isTrue);
      expect(_invoice(vat: const [_s20]).isReverseCharged, isFalse);
    });

    test('prints the mention instead of the seller\'s own text', () {
      const workspace = Workspace(
        id: 'ws-1', name: 'Demo SARL', countryCode: 'FR', currencyCode: 'EUR',
        timezone: 'Europe/Paris', inviteCode: 'CODE',
        vatRegime: 'vat_registered', taxExemptionReason: 'Ma mention à moi',
      );
      final data = legalMentionData(null, workspace,
          seller: _seller, buyer: const InvoiceParty(country: 'DE'),
          reverseCharged: true);
      expect(data['exemption_reason'], contains('Autoliquidation'));
      // Without the reverse charge a VAT-charging seller states no
      // exemption at all; the workspace's own text is what a document
      // with no frozen seller falls back to.
      final ordinary = legalMentionData(null, workspace, seller: _seller);
      expect(ordinary['exemption_reason'], '');
      expect(legalMentionData(null, workspace)['exemption_reason'],
          'Ma mention à moi');
    });

    test('exports as category AE with VATEX-EU-AE, in CII and UBL', () {
      final invoice = _invoice(vat: const [_ae]);
      for (final xml in [
        buildInvoiceCii(
            invoice: invoice,
            seller: _seller,
            buyer: invoice.buyerParty!,
            lineText: (line) => line.label),
        buildInvoiceUbl(
            invoice: invoice,
            seller: _seller,
            buyer: invoice.buyerParty!,
            lineText: (line) => line.label),
      ]) {
        expect(xml, contains('AE'), reason: 'the category the norm wants');
        expect(xml, contains('VATEX-EU-AE'));
      }
    });

    test('refuses to leave without the customer\'s VAT id', () {
      final readiness = checkEInvoiceReadiness(
        invoice: _invoice(vat: const [_ae], buyerVat: ''),
        seller: _seller,
        buyer: const InvoiceParty(name: 'Kunde GmbH', country: 'DE'),
      );
      expect(readiness.gaps, contains(EInvoiceGap.missingBuyerVatId));
      expect(EInvoiceGap.missingBuyerVatId.isBlocking, isTrue);
    });
  });

  test('the SQL twin decides it the same way', () {
    final sql = File('supabase/migrations/0157_reverse_charge.sql')
        .readAsStringSync();
    expect(sql, contains("is_eu_country"));
    expect(sql, contains("''vat_registered''"));
    expect(sql, contains("invoice_legal->>''reverse_charge''"));
    expect(sql, contains("then ''AE''"),
        reason: 'the breakdown must name the category');
  });
}
