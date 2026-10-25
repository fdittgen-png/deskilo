// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2494 — the detail sheet's decisions, as a table: who the document is
// billed to, the client beside the period, the issuer's notes and which
// trail sections apply.
import 'package:deskilo/features/money/application/invoice_detail_facts.dart';
import 'package:deskilo/features/money/domain/billing_rules.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_clock.dart';

Invoice _invoice({
  String memberName = 'Flo',
  String memberAddress = '1 rue A\n\n34120 Pézenas',
  InvoiceKind kind = InvoiceKind.full,
  String? maturityBasis,
  String? settledBy,
  List<SettledSource> settles = const [],
}) => Invoice(
  id: 'inv-1',
  workspaceId: 'ws-1',
  memberId: 'member-1',
  number: 'INV-1',
  issuedAt: kTestNow,
  period: kTestPeriod,
  title: kTestPeriod,
  lines: const [],
  totalCents: 25000,
  currency: 'EUR',
  memberName: memberName,
  memberAddress: memberAddress,
  workspaceName: 'Space',
  workspaceAddress: '',
  issuerName: 'Owner',
  signature: 'sig',
  kind: kind,
  maturityBasis: maturityBasis,
  settledByInvoiceId: settledBy,
  settles: settles,
);

InvoiceMatch _match(String status) => InvoiceMatch(
  invoiceId: 'inv-1',
  paidCents: 25000,
  resolution: 'exact',
  status: status,
  matchedAt: kTestNow,
);

void main() {
  test('billed to: the client and the address lines, empty parts dropped', () {
    expect(
      InvoiceDetailFacts.of(
        _invoice(),
        null,
        canIssue: false,
        showMemberName: false,
      ).billedTo,
      'Flo, 1 rue A, 34120 Pézenas',
    );
    expect(
      InvoiceDetailFacts.of(
        _invoice(memberName: ''),
        null,
        canIssue: false,
        showMemberName: true,
      ).billedTo,
      '1 rue A, 34120 Pézenas',
    );
  });

  final cases =
      <
        ({
          String name,
          Invoice invoice,
          InvoiceMatch? match,
          bool canIssue,
          bool showMemberName,
          String? hold,
          String? client,
          bool kindRow,
          String? held,
          bool maturity,
          bool trail,
          bool folded,
          bool standing,
        })
      >[
        (
          name: 'a plain invoice, read by its member',
          invoice: _invoice(),
          match: null,
          canIssue: false,
          showMemberName: false,
          hold: 'dispute',
          client: null,
          kindRow: false,
          held: null,
          maturity: false,
          trail: false,
          folded: false,
          standing: false,
        ),
        (
          name: 'the issuer sees the hold and a maturity to review',
          invoice: _invoice(maturityBasis: 'member_term'),
          match: _match('confirmed'),
          canIssue: true,
          showMemberName: true,
          hold: 'dispute',
          client: 'Flo',
          kindRow: false,
          held: 'dispute',
          maturity: true,
          trail: false,
          folded: false,
          standing: true,
        ),
        (
          name:
              'the document term needs no review; a pending match is not '
              'standing',
          invoice: _invoice(maturityBasis: 'document_term'),
          match: _match('pending'),
          canIssue: true,
          showMemberName: true,
          hold: null,
          client: 'Flo',
          kindRow: false,
          held: null,
          maturity: false,
          trail: false,
          folded: false,
          standing: false,
        ),
        (
          name: 'a settlement names what it carries',
          invoice: _invoice(
            kind: InvoiceKind.settlement,
            settles: const [
              SettledSource(invoiceId: 'a', number: 'A', totalCents: 100),
            ],
          ),
          match: null,
          canIssue: true,
          showMemberName: false,
          hold: null,
          client: null,
          kindRow: true,
          held: null,
          maturity: false,
          trail: true,
          folded: false,
          standing: false,
        ),
        (
          name: 'a settled invoice names its settlement',
          invoice: _invoice(settledBy: 'set-1'),
          match: null,
          canIssue: false,
          showMemberName: false,
          hold: null,
          client: null,
          kindRow: false,
          held: null,
          maturity: false,
          trail: false,
          folded: true,
          standing: false,
        ),
      ];
  for (final c in cases) {
    test(c.name, () {
      final facts = InvoiceDetailFacts.of(
        c.invoice,
        c.match,
        canIssue: c.canIssue,
        showMemberName: c.showMemberName,
        heldReason: c.hold,
      );
      expect(facts.client, c.client);
      expect(facts.showKindRow, c.kindRow);
      expect(facts.heldReason, c.held);
      expect(facts.showMaturityReview, c.maturity);
      expect(facts.showSettlementTrail, c.trail);
      expect(facts.showFolded, c.folded);
      expect(facts.standingMatch != null, c.standing);
    });
  }
}
