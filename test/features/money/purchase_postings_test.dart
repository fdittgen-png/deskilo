// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2365 — the purchase side of the posting rules, worked by hand: a supplier
// bill of 180.00 (120.00 at 20 % fully recoverable, 60.00 at 20 % with 5.00
// of its 10.00 tax recoverable), paid 180.00 on 2 April; a supplier credit
// note of 30.00; a member's receipt of 12.00 credited to the member's
// account and reimbursed on 20 March (0524); a draft bill (nothing until
// approved).
import 'package:deskilo/features/money/domain/book_chart.dart';
import 'package:deskilo/features/money/domain/posting.dart';
import 'package:deskilo/features/money/domain/posting_rules.dart';
import 'package:deskilo/features/money/domain/posting_rules_purchases.dart';
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:flutter_test/flutter_test.dart';

BookAccount _account(String code, AccountType type) => BookAccount(
  id: 'acc-$code',
  workspaceId: 'ws',
  issuerSiteId: 'site',
  code: code,
  name: code,
  type: type,
  isPosting: true,
  origin: AccountOrigin.manual,
  revision: 1,
);

BookMapping _map(BookRole role, String code) => BookMapping(
  id: role.wire,
  workspaceId: 'ws',
  issuerSiteId: 'site',
  role: role,
  accountId: 'acc-$code',
  effectiveFrom: DateTime(2020),
  revision: 1,
);

PostingBook _book({bool suppliers = true}) => PostingBook(
  accounts: [
    _account('401', AccountType.liability),
    _account('411', AccountType.asset),
    _account('512', AccountType.asset),
    _account('606', AccountType.expense),
    _account('44566', AccountType.asset),
  ],
  mappings: [
    if (suppliers) _map(BookRole.suppliers, '401'),
    _map(BookRole.customers, '411'),
    _map(BookRole.bank, '512'),
    _map(BookRole.expenses, '606'),
    _map(BookRole.vatInput, '44566'),
  ],
  issuerSiteId: 'site',
);

PurchaseDetail _doc(
  String id,
  PurchaseKind kind,
  List<PurchaseLine> lines, {
  PurchaseState state = PurchaseState.approved,
  CreditorKind creditor = CreditorKind.supplier,
  List<SettlementAllocation> paid = const [],
}) => PurchaseDetail(
  summary: PurchaseSummary(
    id: id,
    kind: kind,
    state: state,
    category: 'supplies',
    reference: id,
    currency: 'EUR',
    originalDate: DateTime(2026, 3, 10),
  ),
  revision: 1,
  lines: lines,
  sources: const [],
  obligations: [
    PurchaseObligation(
      id: 'o-$id',
      purchaseId: id,
      creditorKind: creditor,
      creditorId: 'c',
      amountCents: 0,
      currency: 'EUR',
      appliedCents: 0,
      remainingCents: 0,
      allocations: paid,
    ),
  ],
);

PurchaseLine _l(int no, int net, int tax, int recoverable) => PurchaseLine(
  lineNo: no,
  description: 'line $no',
  grossCents: net + tax,
  netCents: net,
  taxCents: tax,
  taxRatePercent: 20,
  recoverableTaxCents: recoverable,
);

List<String> _lines(Posting p) => [
  for (final l in p.lines)
    '${l.accountCode}:${l.debit.minor != 0 ? 'D${l.debit.minor}' : 'C${l.credit.minor}'}',
];

void main() {
  final postings = purchasePostingsOf(
    purchases: [
      _doc(
        'B-1',
        PurchaseKind.bill,
        [_l(1, 10000, 2000, 2000), _l(2, 5000, 1000, 500)],
        paid: [
          SettlementAllocation(
            id: 'pay',
            isReversal: false,
            amountCents: 18000,
            method: 'transfer',
            reference: 'SEPA',
            paidOn: DateTime(2026, 4, 2),
          ),
          const SettlementAllocation(
            id: 'credit',
            isReversal: false,
            isCredit: true,
            amountCents: 3000,
            method: '',
            reference: '',
          ),
        ],
      ),
      _doc('CN-S1', PurchaseKind.creditNote, [_l(1, 2500, 500, 500)]),
      _doc(
        'R-M1',
        PurchaseKind.memberReceipt,
        [_l(1, 1000, 200, 200)],
        creditor: CreditorKind.member,
        paid: [
          SettlementAllocation(
            id: 'back',
            isReversal: false,
            amountCents: 1200,
            method: 'transfer',
            reference: 'refund',
            paidOn: DateTime(2026, 3, 20),
          ),
        ],
      ),
      _doc('B-DRAFT', PurchaseKind.bill, [
        _l(1, 100, 20, 20),
      ], state: PurchaseState.draft),
    ],
    book: _book(),
    groupOf: (p) => p >= 20 ? 'standard' : 'reduced',
  );

  Posting only(String number, PostingKind kind) =>
      postings.singleWhere((p) => p.documentNumber == number && p.kind == kind);

  test('only the approved documents and the money paid post', () {
    expect(postings.map((p) => (p.documentNumber, p.kind)), [
      ('B-1', PostingKind.supplierBill),
      ('B-1', PostingKind.supplierPayment),
      ('CN-S1', PostingKind.supplierCreditNote),
      ('R-M1', PostingKind.memberReceipt),
      ('R-M1', PostingKind.reimbursement),
    ]);
    expect(postings.every((p) => p.balanced), isTrue);
  });

  test('the bill: the cost with what cannot be recovered, the recoverable tax apart', () {
    final bill = postings.first;
    expect(bill.journal, PostingJournal.purchases);
    expect(bill.date, DateTime(2026, 3, 10));
    expect(_lines(bill), [
      '606:D10000',
      '44566:D2000',
      '606:D5500',
      '44566:D500',
      '401:C18000',
    ]);
    expect(bill.lines[1].qualifier, 'standard');
  });

  test('the payment is money out on the day it was paid; a credit is not', () {
    final pay = postings[1];
    expect(pay.journal, PostingJournal.bank);
    expect(pay.date, DateTime(2026, 4, 2));
    expect(_lines(pay), ['401:D18000', '512:C18000']);
  });

  test('a supplier credit note mirrors a bill', () {
    expect(_lines(only('CN-S1', PostingKind.supplierCreditNote)), [
      '606:C2500',
      '44566:C500',
      '401:D3000',
    ]);
  });

  test('a member receipt credits the member\'s account, and the money '
      'paid back debits it (0524)', () {
    expect(_lines(only('R-M1', PostingKind.memberReceipt)), [
      '606:D1000',
      '44566:D200',
      '411:C1200',
    ]);
    final back = only('R-M1', PostingKind.reimbursement);
    expect(
      (back.journal, back.date),
      (PostingJournal.bank, DateTime(2026, 3, 20)),
    );
    expect(_lines(back), ['411:D1200', '512:C1200']);
  });

  test('a missing suppliers mapping blocks with its name', () {
    final book = _book(suppliers: false);
    purchasePostingsOf(
      purchases: [
        _doc('B-2', PurchaseKind.bill, [_l(1, 100, 20, 20)]),
      ],
      book: book,
      groupOf: (_) => 'standard',
    );
    expect(book.blockers.map((b) => (b.block, b.subject)), [
      (PostingBlock.unmappedRole, 'suppliers'),
    ]);
  });

  test(
    'a taxed line whose deductible share is not qualified blocks its bill',
    () {
      final book = _book();
      final out = purchasePostingsOf(
        purchases: [
          _doc('B-3', PurchaseKind.bill, const [
            PurchaseLine(
              lineNo: 1,
              description: 'x',
              grossCents: 120,
              netCents: 100,
              taxCents: 20,
              taxRatePercent: 20,
            ),
          ]),
        ],
        book: book,
        groupOf: (_) => 'standard',
      );
      expect(out.where((p) => p.kind == PostingKind.supplierBill), isEmpty);
      expect(book.blockers.map((b) => (b.block, b.subject)), [
        (PostingBlock.unclassifiedTax, 'B-3'),
      ]);
    },
  );
}
