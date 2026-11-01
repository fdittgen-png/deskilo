// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A member's purchase is counted once: linking a received supplier invoice
// to it later adds evidence (a source) to the same document and does not add
// a second purchase to the books -- one expense posting, one reimbursement.
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
  List<PurchaseSource> sources = const [],
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
  sources: sources,
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

PurchaseLine _line() => const PurchaseLine(
  lineNo: 1,
  description: 'line 1',
  grossCents: 1200,
  netCents: 1000,
  taxCents: 200,
  taxRatePercent: 20,
  recoverableTaxCents: 200,
);

List<String> _lines(Posting p) => [
  for (final l in p.lines)
    '${l.accountCode}:${l.debit.minor != 0 ? 'D${l.debit.minor}' : 'C${l.credit.minor}'}',
];

List<Posting> _post(List<PurchaseDetail> purchases) => purchasePostingsOf(
  purchases: purchases,
  book: _book(),
  groupOf: (p) => 'standard',
);

PurchaseDetail _receipt(List<PurchaseSource> sources) => _doc(
  'R-M1',
  PurchaseKind.memberReceipt,
  [_line()],
  creditor: CreditorKind.member,
  sources: sources,
);

void main() {
  const photo = PurchaseSource(kind: 'attachment', id: 'a-1', role: 'evidence');
  const linked = PurchaseSource(kind: 'inbox', id: 'in-1', role: 'evidence');

  test('the member receipt posts once, with or without the supplier invoice '
      'linked later', () {
    final before = _post([
      _receipt(const [photo]),
    ]);
    final after = _post([
      _receipt(const [photo, linked]),
    ]);

    expect(after.map((p) => (p.documentNumber, p.kind)), [
      ('R-M1', PostingKind.memberReceipt),
    ]);
    expect(after.length, before.length);
    expect(_lines(after.single), _lines(before.single));
    expect(_lines(after.single), ['606:D1000', '44566:D200', '411:C1200']);
    expect(after.single.balanced, isTrue);
  });

  test('the evidence is not a second document: no supplier bill appears '
      'beside the receipt', () {
    final after = _post([
      _receipt(const [photo, linked]),
    ]);
    expect(after.where((p) => p.kind == PostingKind.supplierBill), isEmpty);
    expect(
      after.where((p) => p.kind == PostingKind.memberReceipt),
      hasLength(1),
    );
  });
}
