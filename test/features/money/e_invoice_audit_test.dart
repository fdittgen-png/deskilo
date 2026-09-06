// SPDX-License-Identifier: 0BSD
//
// #941 — what an audit of the e-invoice found missing, pinned:
// the legal registrations with their scheme (BT-30 / BT-47), the
// payment terms and due date (BT-20 / BT-9, BR-CO-25), and the
// readiness gap for a French business buyer without a SIREN.
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_cii.dart';
import 'package:deskilo/features/money/domain/invoice_ubl_check.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

const _seller = InvoiceParty(
  name: 'COWORKONTI', street: '4 avenue de Castelnau', city: 'Pézenas',
  postalCode: '34120', country: 'FR', legalId: '10825191900016',
  vatRegime: 'not_subject', taxExemptionReason: 'TVA non applicable, article 293 B du CGI',
);
const _kaloa = InvoiceParty(
  name: 'SASU KaloA', company: 'SASU KaloA', street: '209 rue Jean Bart',
  city: 'Labège', postalCode: '31670', country: 'FR',
);

Invoice _invoice() => Invoice(
      id: 'inv-1', workspaceId: 'ws-1', memberId: 'member-1', number: 'INV-2026-0057',
      issuedAt: DateTime(2026, 9, 6), period: '2026-09', title: '2026-09',
      lines: const [InvoiceLine(kind: 'subscription', label: '100', amountCents: 10000)],
      totalCents: 10000, currency: 'EUR', memberName: 'SASU KaloA',
      memberAddress: '', workspaceName: 'COWORKONTI', workspaceAddress: '',
      issuerName: 'Flo', signature: 'f' * 64, sellerParty: _seller,
    );

XmlDocument _xml({InvoiceParty buyer = _kaloa, DateTime? dueDate, String terms = ''}) =>
    XmlDocument.parse(buildInvoiceCii(
      invoice: _invoice(), seller: _seller, buyer: buyer,
      lineText: (l) => 'Abonnement 100 %', dueDate: dueDate, paymentTerms: terms,
    ));

Iterable<XmlElement> _els(XmlDocument doc, String name) =>
    doc.findAllElements(name, namespace: '*');

void main() {
  test('the seller\'s SIRET carries scheme 0009, a SIREN 0002, and a '
      'foreign or odd id none', () {
    expect(legalIdScheme('10825191900016', 'FR'), '0009');
    expect(legalIdScheme('108 251 919', 'FR'), '0002');
    expect(legalIdScheme('HRB 12345', 'DE'), '');
    expect(legalIdScheme('12345', 'FR'), '');
    final org = _els(_xml(), 'SpecifiedLegalOrganization').first;
    final id = org.findElements('ram:ID').first;
    expect((id.innerText, id.getAttribute('schemeID')), ('10825191900016', '0009'));
  });

  test('the BUYER\'s legal registration is emitted when known (BT-47) — '
      'it never was', () {
    final withSiren = _xml(buyer: _kaloa.copyWith(legalId: '901 234 567'));
    final buyerOrgs = _els(withSiren, 'BuyerTradeParty').first
        .findAllElements('SpecifiedLegalOrganization', namespace: '*');
    expect(buyerOrgs, hasLength(1));
    final id = buyerOrgs.first.findElements('ram:ID').first;
    expect((id.innerText, id.getAttribute('schemeID')), ('901234567', '0002'));
    expect(_els(_xml(), 'BuyerTradeParty').first
        .findAllElements('SpecifiedLegalOrganization', namespace: '*'), isEmpty);
  });

  test('payment terms and due date ride along (BT-20 / BT-9, BR-CO-25), '
      'between the period and the totals as CII orders them', () {
    final doc = _xml(dueDate: DateTime(2026, 10, 6), terms: 'Paiement à 30 jours.');
    final terms = _els(doc, 'SpecifiedTradePaymentTerms').single;
    expect(terms.findElements('ram:Description').single.innerText, 'Paiement à 30 jours.');
    expect(terms.findAllElements('udt:DateTimeString').single.innerText, '20261006');
    final settlement = _els(doc, 'ApplicableHeaderTradeSettlement').single;
    final names = settlement.childElements.map((e) => e.name.local).toList();
    expect(names.indexOf('SpecifiedTradePaymentTerms'),
        lessThan(names.indexOf('SpecifiedTradeSettlementHeaderMonetarySummation')));
    expect(names.indexOf('SpecifiedTradePaymentTerms'),
        greaterThan(names.indexOf('BillingSpecifiedPeriod')));
    expect(_els(_xml(), 'SpecifiedTradePaymentTerms'), isEmpty,
        reason: 'nothing known, nothing invented');
  });

  test('the association\'s category-O document still carries no VAT id '
      'and its exemption reason', () {
    final doc = _xml();
    expect(_els(doc, 'SellerTradeParty').first
        .findAllElements('SpecifiedTaxRegistration', namespace: '*'), isEmpty);
    expect(_els(doc, 'ExemptionReason').single.innerText, contains('293 B'));
    expect(_els(doc, 'CategoryCode').map((e) => e.innerText).toSet(), {'O'});
  });

  group('readiness', () {
    test('#972 — a French business buyer without a SIREN: ADVICE from a '
        'seller the reform does not bind (an association), a REFUSAL from a '
        'VAT-registered French seller; with one it is clean', () {
      final advice = checkEInvoiceReadiness(invoice: _invoice(), seller: _seller, buyer: _kaloa);
      expect(advice.blocking, isEmpty,
          reason: 'EN 16931 never required BT-47; the file is valid');
      expect(advice.warnings, contains(EInvoiceGap.buyerLegalIdAdvisable));
      expect(advice.ready, isTrue);

      final registered = _seller.copyWith(vatRegime: 'vat_registered', vatId: 'FR12345678901');
      final refusal = checkEInvoiceReadiness(
          invoice: _invoice(), seller: registered, buyer: _kaloa);
      expect(refusal.blocking, contains(EInvoiceGap.missingBuyerLegalId));
      expect(EInvoiceGap.missingBuyerLegalId.fixableInSettings, isFalse,
          reason: 'it is the member\'s data, not a workspace setting');

      final with_ = checkEInvoiceReadiness(
          invoice: _invoice(), seller: _seller, buyer: _kaloa.copyWith(legalId: '901234567'));
      expect(with_.gaps, isNot(contains(EInvoiceGap.missingBuyerLegalId)));
      expect(with_.gaps, isNot(contains(EInvoiceGap.buyerLegalIdAdvisable)));
    });

    test('a private person, or a foreign buyer, is not asked for a SIREN', () {
      final person = _kaloa.copyWith(company: '', name: 'Guilhem MARTIN');
      expect(checkEInvoiceReadiness(invoice: _invoice(), seller: _seller, buyer: person).gaps,
          isNot(contains(EInvoiceGap.missingBuyerLegalId)));
      final abroad = _kaloa.copyWith(country: 'DE');
      expect(checkEInvoiceReadiness(invoice: _invoice(), seller: _seller, buyer: abroad).gaps,
          isNot(contains(EInvoiceGap.missingBuyerLegalId)));
    });
  });
}
