// SPDX-License-Identifier: 0BSD
//
// #947 — VAT groups: the group implies the EN 16931 category and the
// outside-base rule; a bare percentage maps to a group by the same rule
// the database back-filled; the catalogue proposes the legal groups per
// country; a not-subject line beside taxed lines is refused (BR-O-11).
import 'dart:io';

import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_ubl_check.dart';
import 'package:deskilo/features/money/domain/vat_catalogue.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every group carries its category and base rule; the wire round-trips', () {
    expect(VatGroup.standard.category, 'S');
    expect(VatGroup.zero.category, 'Z');
    expect(VatGroup.exempt.category, 'E');
    expect(VatGroup.notSubject.category, 'O');
    expect((VatGroup.deposit.category, VatGroup.deposit.outsideBase), ('O', true));
    expect((VatGroup.excise.category, VatGroup.excise.outsideBase), ('S', false));
    for (final g in VatGroup.values) {
      expect(VatGroup.fromWire(g.wire), g);
    }
    expect(VatGroup.fromWire('lottery'), VatGroup.standard);
  });

  test('a bare percentage falls in the group the database back-fills', () {
    expect(vatGroupForPercent(20), VatGroup.standard);
    expect(vatGroupForPercent(19), VatGroup.standard);
    expect(vatGroupForPercent(10), VatGroup.intermediate);
    expect(vatGroupForPercent(7), VatGroup.reduced);
    expect(vatGroupForPercent(5.5), VatGroup.reduced);
    expect(vatGroupForPercent(2.1), VatGroup.superReduced);
    expect(vatGroupForPercent(0), VatGroup.zero);
    expect(vatGroupForPercent(0, category: 'E'), VatGroup.exempt);
    expect(vatGroupForPercent(0, category: 'O'), VatGroup.notSubject);
  });

  test('a rate carries its group through the wire, and reads as standard '
      'when an older row has none', () {
    const deposit = VatRate(label: 'Consigne', percent: 0, category: 'O', groupKey: 'deposit', outsideBase: true, exemptionReason: 'hors champ');
    final back = VatRate.fromRow({...deposit.toJson(), 'id': 'r1'});
    expect((back.group, back.outsideBase, back.exemptionReason), (VatGroup.deposit, true, 'hors champ'));
    expect(VatRate.fromRow(const {'id': 'r2', 'label': 'x', 'percent': 20}).group, VatGroup.standard);
  });

  test('the catalogue proposes the legal groups with examples: France knows '
      'press and the deposit, Germany taxes the Pfand with the goods', () {
    final fr = vatGroupExamples('FR');
    expect(fr.map((e) => e.group), containsAll([VatGroup.superReduced, VatGroup.deposit, VatGroup.excise, VatGroup.notSubject]));
    final de = vatGroupExamples('DE');
    expect(de.map((e) => e.group), isNot(contains(VatGroup.deposit)));
    expect(de.first.example, contains('Pfand'));
    expect(vatGroupExamples('XX'), isNotEmpty);
  });

  test('BR-O-11: a not-subject line beside taxed lines blocks the e-invoice; '
      'an all-O association document does not', () {
    Invoice inv(List<InvoiceVatTotal> totals) => Invoice(
          id: 'i', workspaceId: 'w', memberId: 'm', number: 'INV-1', issuedAt: DateTime(2026, 9, 6),
          period: '2026-09', title: '', lines: const [InvoiceLine(kind: 'service', label: 'x', amountCents: 1000)],
          totalCents: 1000, currency: 'EUR', memberName: 'A', memberAddress: '', workspaceName: 'W',
          workspaceAddress: '', issuerName: 'F', signature: 'f' * 64, vatTotals: totals,
        );
    const seller = InvoiceParty(name: 'W', country: 'FR', legalId: '123456789', vatId: 'FR12123456789', vatRegime: 'vat_registered');
    const buyer = InvoiceParty(name: 'B', country: 'FR');
    final mixed = checkEInvoiceReadiness(
      invoice: inv(const [InvoiceVatTotal(percent: 20, category: 'S', netCents: 800, vatCents: 160, grossCents: 960), InvoiceVatTotal(percent: 0, category: 'O', netCents: 40, vatCents: 0, grossCents: 40)]),
      seller: seller, buyer: buyer,
    );
    expect(mixed.blocking, contains(EInvoiceGap.mixedNotSubjectLines));
    final association = checkEInvoiceReadiness(
      invoice: inv(const [InvoiceVatTotal(percent: 0, category: 'O', netCents: 1000, vatCents: 0, grossCents: 1000)]),
      seller: seller.copyWith(vatRegime: 'not_subject', vatId: '', taxExemptionReason: 'art. 293 B'), buyer: buyer,
    );
    expect(association.gaps, isNot(contains(EInvoiceGap.mixedNotSubjectLines)));
  });

  test('the SQL twin (0170): groups constrained, back-filled by percentage, '
      'set_vat_rates accepting the three keys', () {
    final sql = File('supabase/migrations/0170_vat_groups.sql').readAsStringSync();
    expect(sql, contains("check (group_key in ('standard','intermediate','reduced','super_reduced','zero','exempt','not_subject','deposit','excise'))"));
    expect(sql, contains("when percent >= 15 then 'standard'"));
    expect(sql, contains("group_key = coalesce(nullif(v_rate->>''group_key'', ''''), group_key)"));
    for (final a in ['A', 'B', 'C']) {
      expect(sql, contains("raise exception '0170: anchor $a missing'"));
    }
  });
}
