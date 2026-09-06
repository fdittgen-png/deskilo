// SPDX-License-Identifier: 0BSD
//
// #922 — the two references Chorus Pro will not accept a deposit without.
//
// Factur-X was sound; what the document did not carry were BT-13 (the
// numéro d'engagement) and BT-10 (the code service exécutant). The app
// accepted the deposit, the portal refused it, and nothing had warned.
import 'dart:io';

import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_cii.dart';
import 'package:deskilo/features/money/domain/invoice_ubl.dart' show buildInvoiceUbl;
import 'package:deskilo/features/money/domain/invoice_ubl_check.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

const _seller = InvoiceParty(
  name: 'COWORKONTI', street: '4 avenue de Castelnau', city: 'Pézenas',
  postalCode: '34120', country: 'FR', legalId: '10825191900016',
  vatRegime: 'not_subject', taxExemptionReason: 'Hors champ',
);
const _mairie = InvoiceParty(
  name: 'Mairie de Pézenas', street: '6 rue Massillon', city: 'Pézenas',
  postalCode: '34120', country: 'FR', legalId: '21340199100014',
  reference: 'SERVICE-42', orderReference: 'ENG-2026-0009',
);
const _member = InvoiceParty(name: 'Ana Martin', city: 'Pézenas', country: 'FR');

Invoice _invoice(InvoiceParty buyer) => Invoice(
      id: 'inv-1', workspaceId: 'ws-1', memberId: 'm-1', number: 'INV-2026-0012',
      issuedAt: DateTime(2026, 9, 6), period: '2026-09', title: 'INV-2026-0012',
      lines: const [InvoiceLine(kind: 'service', label: 'Salle', amountCents: 10000)],
      totalCents: 10000, currency: 'EUR', memberName: buyer.name, memberAddress: '',
      workspaceName: 'COWORKONTI', workspaceAddress: '', issuerName: '', signature: 'sig',
      sellerParty: _seller, buyerParty: buyer,
    );

void main() {
  group('the frozen party', () {
    test('reads both references from the snapshot, and nothing when absent', () {
      final p = InvoiceParty.fromSnapshot({'name': 'x', 'reference': 'S', 'order': 'E'});
      expect((p.reference, p.orderReference), ('S', 'E'));
      final none = InvoiceParty.fromSnapshot({'name': 'x'});
      expect((none.reference, none.orderReference), ('', ''));
    });
  });

  group('UBL', () {
    test('carries BT-10 after the currency and BT-13 before any billing '
        'reference — the schema order a validator enforces', () {
      final xml = buildInvoiceUbl(invoice: _invoice(_mairie), seller: _seller,
          buyer: _mairie, lineText: (l) => l.label);
      final doc = XmlDocument.parse(xml);
      expect(doc.findAllElements('cbc:BuyerReference').single.innerText, 'SERVICE-42');
      expect(doc.findAllElements('cac:OrderReference').single
          .findElements('cbc:ID').single.innerText, 'ENG-2026-0009');
      expect(xml.indexOf('cbc:DocumentCurrencyCode'), lessThan(xml.indexOf('cbc:BuyerReference')));
      expect(xml.indexOf('cbc:BuyerReference'), lessThan(xml.indexOf('cac:OrderReference')));
      expect(xml.indexOf('cac:OrderReference'), lessThan(xml.indexOf('cac:AccountingSupplierParty')));
    });

    test('and says nothing for a member — a coworker is not a mairie', () {
      final xml = buildInvoiceUbl(invoice: _invoice(_member), seller: _seller,
          buyer: _member, lineText: (l) => l.label);
      expect(xml, isNot(contains('BuyerReference')));
      expect(xml, isNot(contains('OrderReference')));
    });
  });

  group('CII / Factur-X', () {
    test('BT-10 leads the trade agreement, BT-13 follows the parties', () {
      final xml = buildInvoiceCii(invoice: _invoice(_mairie), seller: _seller,
          buyer: _mairie, lineText: (l) => l.label);
      final doc = XmlDocument.parse(xml);
      final agreement = doc.findAllElements('ram:ApplicableHeaderTradeAgreement').single;
      expect(agreement.childElements.first.name.qualified, 'ram:BuyerReference');
      expect(agreement.childElements.first.innerText, 'SERVICE-42');
      expect(agreement.findElements('ram:BuyerOrderReferencedDocument').single
          .findElements('ram:IssuerAssignedID').single.innerText, 'ENG-2026-0009');
      expect(xml.indexOf('ram:BuyerTradeParty'), lessThan(xml.indexOf('ram:BuyerOrderReferencedDocument')));
    });
  });

  group('the pre-flight check', () {
    test('warns — does not refuse — for a government destination with '
        'neither reference: the norm does not require them, the portal does', () {
      final r = checkEInvoiceReadiness(invoice: _invoice(_member), seller: _seller,
          buyer: _member, destination: 'government');
      expect(r.gaps, contains(EInvoiceGap.missingPublicSectorReferences));
      expect(EInvoiceGap.missingPublicSectorReferences.isBlocking, isFalse);
      expect(r.ready, isTrue, reason: 'still exportable; the issuer is told');
    });

    test('one reference is enough, and a customer destination asks for none', () {
      expect(checkEInvoiceReadiness(invoice: _invoice(_mairie), seller: _seller,
              buyer: _mairie, destination: 'government').gaps,
          isNot(contains(EInvoiceGap.missingPublicSectorReferences)));
      expect(checkEInvoiceReadiness(invoice: _invoice(_member), seller: _seller,
              buyer: _member, destination: 'customer').gaps,
          isNot(contains(EInvoiceGap.missingPublicSectorReferences)));
    });
  });

  group('the SQL twin (migration 0163)', () {
    final sql = File('supabase/migrations/0163_chorus_pro_references.sql').readAsStringSync();
    test('both references are frozen under the buyer, trimmed and bounded', () {
      expect(sql, contains("''reference'', left(btrim(coalesce(p_buyer_reference"));
      expect(sql, contains("''order'', left(btrim(coalesce(p_purchase_order"));
      expect(sql, contains(', 120)'));
    });
    test('the 7-argument overload is dropped so the old call cannot be ambiguous', () {
      expect(sql, contains('drop function if exists public.create_invoice(uuid, uuid, text, uuid, boolean, text, boolean)'));
      expect(sql, contains('p_purchase_order text DEFAULT'));
    });
  });
}
