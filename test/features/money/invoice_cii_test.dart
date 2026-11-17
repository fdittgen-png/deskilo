// SPDX-License-Identifier: AGPL-3.0-or-later
//
// EN 16931 as CII (0073) — the syntax Factur-X embeds in the PDF. Same
// semantics as the UBL builder, different grammar, and every group is an
// XSD *sequence*: an element out of order is rejected before a single
// business rule is read.
import 'package:deskilo/core/jurisdiction/installed_invoice_rules.dart';
import 'package:deskilo/core/jurisdiction/installed_payment_slips.dart';
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/domain/invoice_line_text.dart';
import 'package:deskilo/features/money/presentation/invoice_documents.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import '../../helpers/mock_providers.dart';
Invoice _invoice({String replacesNumber = ''}) => Invoice(
      id: 'inv-1',
      workspaceId: 'ws-1',
      memberId: 'member-1',
      number: 'INV-2026-0001',
      issuedAt: DateTime(2026, 7, 26),
      period: '2026-07',
      title: '2026-07',
      lines: const [
        InvoiceLine(kind: 'subscription', label: '50', amountCents: 15000),
        InvoiceLine(
            kind: 'overage', label: '', quantity: 2, amountCents: 1600),
        InvoiceLine(kind: 'payment', label: 'PayPal', amountCents: -10000),
      ],
      totalCents: 6600,
      currency: 'EUR',
      memberName: 'Ana Martin',
      memberAddress: '1 Rue Test',
      workspaceName: 'Test Space',
      workspaceAddress: '2 Place du Marché',
      issuerName: 'Flo',
      signature: 'f' * 64,
      replacesNumber: replacesNumber,
    );

const _sellerO = InvoiceParty(
  name: 'Test Space',
  street: '2 Place du Marché',
  city: 'Pézenas',
  postalCode: '34120',
  country: 'FR',
  legalId: '812345678',
  taxExemptionReason: 'Services outside the scope of VAT',
);

const _buyer = InvoiceParty(
  name: 'Ana Martin',
  street: '1 Rue Test',
  city: 'Pézenas',
  postalCode: '34120',
  country: 'FR',
);

/// #3500 — the same frozen clauses on two documents; applicability and
/// registration schemes come from each document's own supplied country.
Invoice _frozen(String country) => _invoice().copyWith(
  sellerParty: _sellerO.copyWith(country: country, legalId: '10825191900016'),
  buyerParty: _buyer.copyWith(country: country, legalId: '901234567'),
  documentLanguage: 'en', formatLocale: 'en_US',
  dueOn: DateTime(2026, 8, 25),
  legalSnapshot: {
    'seller_kind': 'business', 'seller_country': country, 'buyer_country': country,
    'buyer_capacity': 'business',
    'clauses': {
      'payment_terms': 'Frozen payment terms',
      'recovery_indemnity': 'Frozen recovery indemnity',
      'late_penalty': 'Frozen late-payment penalty',
      'escompte': 'Frozen early-payment discount',
    },
  },
);

List<(String, String)> _notes(XmlDocument doc) => [
  for (final note in doc.findAllElements('ram:IncludedNote'))
    (note.findElements('ram:SubjectCode').single.innerText,
     note.findElements('ram:Content').single.innerText),
];

List<String?> _schemes(XmlDocument doc) => [
  for (final org in doc.findAllElements('ram:SpecifiedLegalOrganization'))
    org.findElements('ram:ID').single.getAttribute('schemeID'),
];

XmlDocument _doc({
  Invoice? invoice,
  InvoiceParty seller = _sellerO,
  InvoiceParty buyer = _buyer,
  String iban = '',
}) =>
    XmlDocument.parse(buildInvoiceCii(EInvoiceInput(paymentReferenceRules: installedPaymentReferenceRules, nationalRules: installedNationalInvoiceRules, invoice: invoice ?? _invoice(),
      seller: seller,
      buyer: buyer,
      iban: iban,
      lineText: (line) => invoiceLineText(const ReportStrings(), line), reference: ActiveTaxReference.current)));

/// A direct child of `rsm:ExchangedDocument` — the invoice head. Scoped on
/// purpose: `ram:ID` also names the guideline and both parties.
String _head(XmlDocument doc, String name) => doc
    .findAllElements('rsm:ExchangedDocument')
    .single
    .findElements('ram:$name')
    .single
    .innerText;

/// The child element names of the first [parent], in document order.
List<String> _order(XmlDocument doc, String parent) => doc
    .findAllElements('ram:$parent')
    .first
    .childElements
    .map((e) => e.name.local)
    .toList();

void main() {
  test('FR writes its frozen CIUS notes and registration schemes; DE writes neither', () {
    final fr = _frozen('FR');
    final de = _frozen('DE');
    final french = _doc(invoice: fr, seller: fr.sellerParty!, buyer: fr.buyerParty!);
    final german = _doc(invoice: de, seller: de.sellerParty!, buyer: de.buyerParty!);
    expect(_notes(french), [
      ('PMT', 'Frozen recovery indemnity'),
      ('PMD', 'Frozen late-payment penalty'),
      ('AAB', 'Frozen early-payment discount'),
    ]);
    expect(_schemes(french), ['0009', '0002']);
    expect(_notes(german), isEmpty);
    expect(_schemes(german), [null, null]);
  });

  testWidgets('the real Factur-X consumer renders frozen FR and DE documents '
      'identically after selecting another business/country', (tester) async {
    Workspace business(String id, String country, String kind) => Workspace(
      id: id, name: country, countryCode: country, currencyCode: 'EUR',
      timezone: 'UTC', inviteCode: 'INVITE1234', defaultLocale: country.toLowerCase(),
      invoiceLegal: {'seller_kind': kind, 'late_penalty': 'Changed live penalty'},
    );
    final workspaces = FakeWorkspaceRepository(workspaces: [
      business('ws-1', 'FR', 'business'), business('ws-2', 'DE', 'association'),
    ]);
    final container = ProviderContainer(overrides: standardTestOverrides(
      auth: FakeAuthRepository.signedIn(), workspace: workspaces,
    ));
    addTearDown(container.dispose);
    late String Function(Invoice) render;
    await tester.pumpWidget(UncontrolledProviderScope(container: container,
      child: MaterialApp(localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Consumer(builder: (context, ref, child) {
          ref.watch(currentWorkspaceProvider);
          render = (invoice) => facturXmlOf(context, ref, invoice,
            seller: invoice.sellerParty!, buyer: invoice.buyerParty!, iban: '',
            reference: ActiveTaxReference.current);
          return const SizedBox.shrink();
        }),
      ),
    ));
    await tester.pumpAndSettle();
    final fr = _frozen('FR'), de = _frozen('DE');
    expect(container.read(currentWorkspaceProvider).requireValue!.countryCode, 'FR');
    final before = [render(fr), render(de)];
    await container.read(activeWorkspaceIdProvider.notifier).select('ws-2');
    await tester.pumpAndSettle();
    expect(container.read(currentWorkspaceProvider).requireValue!.countryCode, 'DE');
    final after = [render(fr), render(de)];
    expect(after, before, reason: 'every XML byte follows the frozen document');
    expect(_notes(XmlDocument.parse(after.first)), hasLength(3));
    expect(_schemes(XmlDocument.parse(after.first)), ['0009', '0002']);
    expect(_notes(XmlDocument.parse(after.last)), isEmpty);
    expect(_schemes(XmlDocument.parse(after.last)), [null, null]);
    expect(after.first, contains('Frozen payment terms'));
    expect(after.first, isNot(contains('Changed live penalty')));
  });

  test('the document declares the EN 16931 guideline and the invoice head',
      () {
    final doc = _doc();

    expect(
      doc
          .findAllElements('ram:GuidelineSpecifiedDocumentContextParameter')
          .single
          .findElements('ram:ID')
          .single
          .innerText,
      'urn:cen.eu:en16931:2017',
      reason: 'Factur-X EN 16931 profile, not a downgraded BASIC',
    );
    expect(_head(doc, 'ID'), 'INV-2026-0001');
    expect(_head(doc, 'TypeCode'), '380');
    expect(
      doc.findAllElements('udt:DateTimeString').first.innerText,
      '20260726',
      reason: 'CII dates are format 102 — YYYYMMDD',
    );
    expect(
      doc.findAllElements('udt:DateTimeString').first.getAttribute('format'),
      '102',
    );
  });

  test('the solde maps to prepaid + due, and payments never become lines',
      () {
    final doc = _doc();

    expect(doc.findAllElements('ram:IncludedSupplyChainTradeLineItem'),
        hasLength(2));
    final totals = doc
        .findAllElements('ram:SpecifiedTradeSettlementHeaderMonetarySummation')
        .single;
    String total(String name) =>
        totals.findElements('ram:$name').single.innerText;
    expect(total('LineTotalAmount'), '166.00');
    expect(total('TaxBasisTotalAmount'), '166.00');
    expect(total('GrandTotalAmount'), '166.00');
    expect(total('TotalPrepaidAmount'), '100.00');
    expect(total('DuePayableAmount'), '66.00');
  });

  test('POSTCODE comes first in a CII address — the sequence is not the '
      'human order', () {
    final order = _order(_doc(), 'PostalTradeAddress');

    expect(order, ['PostcodeCode', 'LineOne', 'CityName', 'CountryID']);
  });

  test('a category-O seller is identified by its legal organisation and '
      'carries NO tax registration (BR-O-02/BR-CO-26)', () {
    final doc = _doc();
    final seller = doc.findAllElements('ram:SellerTradeParty').single;

    expect(
      seller
          .findAllElements('ram:SpecifiedLegalOrganization')
          .single
          .findElements('ram:ID')
          .single
          .innerText,
      '812345678',
    );
    expect(seller.findAllElements('ram:SpecifiedTaxRegistration'), isEmpty);

    final tax = doc.findAllElements('ram:ApplicableTradeTax').last;
    expect(tax.findElements('ram:CategoryCode').single.innerText, 'O');
    expect(tax.findElements('ram:ExemptionReasonCode').single.innerText,
        'VATEX-EU-O');
    expect(tax.findElements('ram:RateApplicablePercent'), isEmpty,
        reason: 'BR-O-05: category O carries no rate');
    // The header tax group follows the norm's own element order.
    expect(_order(_doc(), 'ApplicableTradeTax'), [
      'TypeCode',
      'CategoryCode',
    ], reason: 'the LINE-level group is the first one in the document');
  });

  test('an exempt seller carries its VAT id, the zero rate and the reason',
      () {
    final doc = _doc(
      seller: _sellerO.copyWith(
        vatRegime: 'exempt',
        vatId: 'FR12812345678',
        taxExemptionReason: 'Franchise en base de TVA',
      ),
    );

    expect(
      doc
          .findAllElements('ram:SellerTradeParty')
          .single
          .findAllElements('ram:SpecifiedTaxRegistration')
          .single
          .findElements('ram:ID')
          .single
          .innerText,
      'FR12812345678',
    );
    final tax = doc.findAllElements('ram:ApplicableTradeTax').last;
    expect(tax.findElements('ram:CategoryCode').single.innerText, 'E');
    expect(tax.findElements('ram:RateApplicablePercent').single.innerText,
        '0');
    expect(tax.findElements('ram:ExemptionReasonCode').single.innerText,
        'VATEX-FR-FRANCHISE');
    expect(tax.findElements('ram:ExemptionReason').single.innerText,
        contains('Franchise'));
  });

  test('the invoiced month rides as a billing period', () {
    final period = _doc().findAllElements('ram:BillingSpecifiedPeriod').single;

    expect(
      period.findAllElements('udt:DateTimeString').map((e) => e.innerText),
      ['20260701', '20260731'],
    );
  });

  test('an IBAN becomes credit-transfer payment means', () {
    final means = _doc(iban: 'FR76 3000 4000 0312 3456 7890 143')
        .findAllElements('ram:SpecifiedTradeSettlementPaymentMeans')
        .single;

    expect(means.findElements('ram:TypeCode').single.innerText, '30');
    expect(
      means
          .findAllElements('ram:PayeePartyCreditorFinancialAccount')
          .single
          .findElements('ram:IBANID')
          .single
          .innerText,
      'FR7630004000031234567890143',
    );
  });

  test('a replacement is corrective (384) and names the document it '
      'replaces', () {
    final doc = _doc(invoice: _invoice(replacesNumber: 'INV-2026-0000'));

    expect(_head(doc, 'TypeCode'), '384');
    expect(
      doc
          .findAllElements('ram:InvoiceReferencedDocument')
          .single
          .findElements('ram:IssuerAssignedID')
          .single
          .innerText,
      'INV-2026-0000',
    );
  });

  test('the settlement group keeps the norm\'s element order', () {
    final order = _order(_doc(iban: 'FR7630004000031234567890143'),
        'ApplicableHeaderTradeSettlement');

    expect(order, [
      // BT-83 (#2380): CII places the payment reference before the currency.
      'PaymentReference',
      'InvoiceCurrencyCode',
      'SpecifiedTradeSettlementPaymentMeans',
      'ApplicableTradeTax',
      'BillingSpecifiedPeriod',
      'SpecifiedTradeSettlementHeaderMonetarySummation',
    ]);
  });
}
