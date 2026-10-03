// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1870 — the posting preview: how an invoice or a payment WOULD post on
// the issuer's chart, exactly, and what blocks it. Expected values are
// written by hand (GST 5 % + QST 9.975 % on CAD 1000.00 = 1149.75).
import 'package:deskilo/features/money/domain/accounting_amount.dart';
import 'package:deskilo/features/money/domain/accounting_tax.dart';
import 'package:deskilo/features/money/domain/book_chart.dart';
import 'package:deskilo/features/money/domain/posting_preview.dart';
import 'package:flutter_test/flutter_test.dart';

const site = 'site-1';

BookAccount acct(String id, String code, AccountType type, {String s = site}) =>
    BookAccount(
      id: id,
      workspaceId: 'w',
      issuerSiteId: s,
      code: code,
      name: code,
      type: type,
      isPosting: true,
      origin: AccountOrigin.manual,
      revision: 1,
    );

BookMapping map(BookRole role, String accountId, String from) => BookMapping(
  id: 'm-$accountId-$from',
  workspaceId: 'w',
  issuerSiteId: site,
  role: role,
  accountId: accountId,
  effectiveFrom: DateTime.parse(from),
  revision: 1,
);

final accounts = [
  acct('a1', '0411', AccountType.asset),
  acct('a2', '706', AccountType.income),
  acct('a3', '512', AccountType.asset),
  acct('a4', '44571', AccountType.liability),
];
final mappings = [
  map(BookRole.customers, 'a1', '2026-01-01'),
  map(BookRole.revenue, 'a2', '2026-01-01'),
  map(BookRole.bank, 'a3', '2026-01-01'),
  map(BookRole.vatOutput, 'a4', '2026-01-01'),
];
final day = DateTime.utc(2026, 6, 1);

AccountingAmount cad(String v) => AccountingAmount.parse('CAD', v);
AccountingAmount eur(String v) => AccountingAmount.parse('EUR', v);

TaxComponent tax(
  AccountingAmount basis,
  String scheme,
  String auth,
  String rate,
) => projectTax(
  basis: basis,
  scheme: scheme,
  authority: auth,
  treatment: TaxTreatment.taxed,
  ratePercent: rate,
  rateVersion: 'v1',
  policy: RoundingPolicy.halfUp,
);

PostingPreview invoice(
  AccountingAmount net,
  List<TaxComponent> taxes, {
  List<BookMapping>? maps,
}) => previewInvoicePosting(
  net: net,
  taxes: taxes,
  issuerSiteId: site,
  day: day,
  accounts: accounts,
  mappings: maps ?? mappings,
);

void main() {
  test('GST + QST invoice posts 1149.75 / 1000.00 / 149.75, exactly', () {
    final net = cad('1000.00');
    final p = invoice(net, [
      tax(net, 'GST', 'CA', '5'),
      tax(net, 'QST', 'CA-QC', '9.975'),
    ]);
    expect(p.postable, isTrue);
    expect(p.balanced, isTrue);
    expect(p.lines.map((l) => l.accountCode), ['0411', '706', '44571']);
    expect(p.lines[0].debit, cad('1149.75'));
    expect(p.lines[1].credit, cad('1000.00'));
    expect(p.lines[2].credit, cad('149.75'));
    expect(p.totalDebit, cad('1149.75'));
  });

  test(
    'the mapping in force on the day governs; earlier ones are not used',
    () {
      final later = [...mappings, map(BookRole.revenue, 'a5', '2026-09-01')];
      final withA5 = [...accounts, acct('a5', '7061', AccountType.income)];
      final net = eur('10.00');
      final p = previewInvoicePosting(
        net: net,
        taxes: const [],
        issuerSiteId: site,
        day: day,
        accounts: withA5,
        mappings: later,
      );
      expect(p.lines.map((l) => l.accountCode), ['0411', '706']);
      expect(p.lines, hasLength(2), reason: 'no tax line for a zero tax');
    },
  );

  test('zero-rated and reverse charge add no tax line', () {
    final net = eur('100.00');
    final zero = projectTax(
      basis: net,
      scheme: 'VAT',
      authority: 'FR',
      treatment: TaxTreatment.reverseCharge,
      rateVersion: 'v1',
      policy: RoundingPolicy.halfUp,
    );
    final p = invoice(net, [zero]);
    expect(p.balanced, isTrue);
    expect(p.lines, hasLength(2));
  });

  test('a credit note mirrors the sides', () {
    final net = eur('-100.00');
    final p = invoice(net, [tax(net, 'VAT', 'FR', '20')]);
    expect(p.balanced, isTrue);
    expect(p.lines[0].credit, eur('120.00'));
    expect(p.lines[1].debit, eur('100.00'));
    expect(p.lines[2].debit, eur('20.00'));
  });

  test('payment: bank debited, customers credited; refund mirrors', () {
    final p = previewPaymentPosting(
      payment: eur('42.10'),
      issuerSiteId: site,
      day: day,
      accounts: accounts,
      mappings: mappings,
    );
    expect(p.lines.map((l) => l.accountCode), ['512', '0411']);
    expect(p.lines[0].debit, eur('42.10'));
    expect(p.lines[1].credit, eur('42.10'));
    final refund = previewPaymentPosting(
      payment: eur('-42.10'),
      issuerSiteId: site,
      day: day,
      accounts: accounts,
      mappings: mappings,
    );
    expect(refund.lines[0].credit, eur('42.10'));
    expect(refund.balanced, isTrue);
  });

  test('an unmapped role blocks; nothing is guessed', () {
    final p = invoice(
      eur('10.00'),
      const [],
      maps: [
        for (final m in mappings)
          if (m.role != BookRole.revenue) m,
      ],
    );
    expect(p.postable, isFalse);
    expect(p.lines, isEmpty);
    expect(p.blockers.single.block, PostingBlock.unmappedRole);
    expect(p.blockers.single.subject, 'revenue');
  });

  test('a mapping that points at a wrong-type account blocks', () {
    final p = invoice(
      eur('10.00'),
      const [],
      maps: [
        for (final m in mappings)
          if (m.role == BookRole.revenue)
            map(BookRole.revenue, 'a3', '2026-01-01')
          else
            m,
      ],
    );
    expect(p.blockers.single.block, PostingBlock.badAccount);
  });

  test('an unreviewed currency cannot become an amount to preview', () {
    final p = previewPaymentPosting(
      payment: AccountingAmount.parse('EUR', '1.00'),
      issuerSiteId: site,
      day: day,
      accounts: accounts,
      mappings: mappings,
    );
    expect(p.postable, isTrue);
    expect(
      () => AccountingAmount.parse('XXQ', '1.00'),
      throwsA(isA<AccountingException>()),
      reason: 'an unreviewed currency cannot even become an amount',
    );
  });

  test('an unclassified tax and a mixed currency block', () {
    final net = eur('100.00');
    final unknown = TaxComponent(
      scheme: 'VAT',
      authority: 'FR',
      treatment: TaxTreatment.unknown,
      ratePercent: ExactDecimal.parse('0'),
      rateVersion: 'v1',
      basis: net,
      amount: eur('0.00'),
    );
    expect(
      invoice(net, [unknown]).blockers.single.block,
      PostingBlock.unclassifiedTax,
    );
    final foreign = tax(cad('10.00'), 'GST', 'CA', '5');
    expect(
      invoice(net, [foreign]).blockers.single.block,
      PostingBlock.currencyMismatch,
    );
  });

  test('a gross past the exact range blocks instead of wrapping', () {
    final net = AccountingAmount('EUR', maxSafeMinor);
    final p = invoice(net, [tax(eur('1.00'), 'VAT', 'FR', '20')]);
    expect(p.postable, isFalse);
    expect(p.blockers.map((b) => b.block), contains(PostingBlock.outOfRange));
  });
}
