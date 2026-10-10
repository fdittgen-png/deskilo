// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #895 — intra-EU B2B is the customer's tax. A VAT-registered seller
// invoicing a business in ANOTHER member state charges nothing: the
// document states category AE, carries the reverse-charge mention and
// names the customer's VAT identifier. Mirrors create_invoice (0157).
// #2354 — only for a general service: a desk is taxed where it stands.

import 'package:deskilo/features/money/domain/report_strings.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_cii.dart';
import 'package:deskilo/features/money/domain/invoice_legal.dart';
import 'package:deskilo/features/money/domain/invoice_ubl.dart' show buildInvoiceUbl;
import 'package:deskilo/features/money/domain/invoice_ubl_check.dart';
import 'package:deskilo/core/vat/supply_class.dart';
import 'package:deskilo/core/vat/vat_treatment.dart';
import 'package:deskilo/features/money/domain/vat_compliance.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deskilo/features/money/domain/report_data.dart';

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
    // #2354 — the place of supply decides, line by line; the cases the
    // SQL twin runs are pinned by place_of_supply_test.
    String category({
      VatTreatment treatment = VatTreatment.auto,
      SupplyClass supply = SupplyClass.general,
      bool registered = true,
      String seller = 'FR',
      String buyer = 'DE',
      String capacity = 'business',
      bool reverseChargeOn = true,
    }) =>
        supplyVatCategory(
          treatment: treatment,
          supply: supply,
          sellerVatRegistered: registered,
          sellerCountry: seller,
          buyerCountry: buyer,
          buyerCapacity: capacity,
          reverseChargeOn: reverseChargeOn,
        );

    test('a desk is taxed where the building stands, for every customer',
        () {
      expect(category(supply: SupplyClass.property), '');
      expect(category(supply: SupplyClass.property, buyer: 'US'), '');
      expect(category(supply: SupplyClass.property, capacity: 'consumer'), '');
    });

    test('a general service: AE for an EU business abroad, G outside', () {
      expect(category(), 'AE');
      expect(category(buyer: 'fr'), '', reason: 'at home the tax is ours');
      expect(category(capacity: 'consumer'), '',
          reason: 'a consumer pays the seller\'s VAT (art. 45)');
      expect(category(capacity: 'unknown'), '',
          reason: 'a VAT number alone is not a business');
      expect(category(buyer: 'CH'), 'G');
      expect(category(registered: false), '',
          reason: 'a seller who charges no VAT reverses nothing');
      expect(category(reverseChargeOn: false), '');
    });

    test('an explicit treatment decides every line', () {
      for (final supply in SupplyClass.values) {
        expect(category(treatment: VatTreatment.domestic, supply: supply), '');
        expect(category(treatment: VatTreatment.reverseCharge, supply: supply),
            'AE');
        expect(category(treatment: VatTreatment.export, supply: supply), 'G');
        expect(category(treatment: VatTreatment.exempt, supply: supply), 'E');
      }
    });

    test('the member states, Greece under both its codes', () {
      expect(isEuCountry('el'), isTrue);
      expect(isEuCountry('GR'), isTrue);
      expect(euCountryCode(' el '), 'GR');
      expect(euMemberStates, isNot(contains('EL')));
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
      final data = legalMentionData(const ReportStrings(), workspace,
          seller: _seller, buyer: const InvoiceParty(country: 'DE'),
          reverseCharged: true);
      expect(data['exemption_reason'], contains('Autoliquidation'));
      // Without the reverse charge a VAT-charging seller states no
      // exemption at all; the workspace's own text is what a document
      // with no frozen seller falls back to.
      final ordinary = legalMentionData(const ReportStrings(), workspace, seller: _seller);
      expect(ordinary['exemption_reason'], '');
      expect(legalMentionData(const ReportStrings(), workspace)['exemption_reason'],
          'Ma mention à moi');
    });

    test('a desk for a German business prints no reverse-charge text', () {
      // #2354 — the server issues it at the French rate, category S; the
      // document then states no mention at all.
      final invoice = _invoice(vat: const [_s20]);
      const workspace = Workspace(
        id: 'ws-1', name: 'Demo SARL', countryCode: 'FR', currencyCode: 'EUR',
        timezone: 'Europe/Paris', inviteCode: 'CODE',
        vatRegime: 'vat_registered',
      );
      final data = invoiceReportData(const ReportStrings(), invoice,
          proforma: false, copy: false, workspace: workspace);
      expect(data['exemption_reason'], '');
      expect('$data', isNot(contains('Autoliquidation')));
      expect('$data', isNot(contains('196')));
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

}
