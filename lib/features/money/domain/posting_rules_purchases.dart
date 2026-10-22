// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2365 — the purchase side of the posting rules: a supplier's bill and its
// payments, held to the server engine (`compute_postings`).
//
//   * supplier bill (approved, a supplier's): per line, Dr `expenses` the
//     net plus the tax that cannot be recovered, Dr `vat_input:<group>` the
//     recoverable tax / Cr `suppliers` the gross. A supplier's credit note
//     mirrors it.
//   * supplier payment (a paid allocation on the supplier's payable, not
//     reversed): Dr `suppliers` / Cr `bank` on the day it was paid. A credit
//     note applied to the payable and an offset move no money and book
//     nothing here.
//   * a taxed line whose deductible share is not qualified yet blocks its
//     bill (unclassifiedTax, named by the reference): never guessed.
//
// A member's receipt is not posted here: its expense is the credit the
// invoice nets (posting_rules.dart), so it is never booked twice.

import 'accounting_amount.dart';
import 'book_chart.dart';
import 'posting.dart';
import 'posting_rules.dart';
import 'purchase.dart';

/// The postings of [purchases] on [book]. [groupOf] names the rate group of
/// a line's tax rate.
List<Posting> purchasePostingsOf({
  required List<PurchaseDetail> purchases,
  required PostingBook book,
  required String Function(double percent) groupOf,
}) => [
  for (final d in purchases)
    if (d.summary.state == PurchaseState.approved &&
        d.summary.kind != PurchaseKind.memberReceipt &&
        d.obligations.any((o) => o.creditorKind == CreditorKind.supplier)) ...[
      ?_bill(d, book, groupOf),
      ..._payments(d, book),
    ],
];

AccountingAmount _amount(PurchaseDetail d, int minor) =>
    AccountingAmount(d.summary.currency, minor);

Posting? _bill(
  PurchaseDetail d,
  PostingBook book,
  String Function(double) groupOf,
) {
  final day = d.summary.originalDate ?? d.summary.receivedOn;
  if (day == null) return null;
  // A taxed line whose deductible share is not qualified yet is never
  // guessed: the bill waits, named.
  if (d.lines.any(
    (l) => (l.taxCents ?? 0) != 0 && l.recoverableTaxCents == null,
  )) {
    book.block(PostingBlock.unclassifiedTax, d.summary.reference);
    return null;
  }
  // A credit note mirrors its bill: the same lines, the other side.
  final sign = d.summary.kind == PurchaseKind.creditNote ? -1 : 1;
  final lines = <PostingLine>[];
  var gross = 0;
  for (final l in d.lines) {
    final tax = l.taxCents ?? 0;
    final recoverable = l.recoverableTaxCents ?? 0;
    final net = l.netCents ?? l.grossCents - tax;
    gross += l.grossCents;
    final group = l.taxRatePercent == null ? null : groupOf(l.taxRatePercent!);
    lines.addAll([
      ?postingLine(
        BookRole.expenses,
        book.code(BookRole.expenses, day),
        _amount(d, sign * (net + tax - recoverable)),
        debitSide: true,
      ),
      if (recoverable != 0)
        ?postingLine(
          BookRole.vatInput,
          book.code(BookRole.vatInput, day, qualifier: group),
          _amount(d, sign * recoverable),
          debitSide: true,
          qualifier: group,
        ),
    ]);
  }
  final suppliers = postingLine(
    BookRole.suppliers,
    book.code(BookRole.suppliers, day),
    _amount(d, sign * gross),
    debitSide: false,
  );
  if (suppliers != null) lines.add(suppliers);
  return Posting(
    journal: PostingJournal.purchases,
    date: day,
    kind: sign < 0 ? PostingKind.supplierCreditNote : PostingKind.supplierBill,
    documentId: d.summary.id,
    documentNumber: d.summary.reference,
    lines: lines,
  );
}

List<Posting> _payments(PurchaseDetail d, PostingBook book) => [
  for (final o in d.obligations)
    if (o.creditorKind == CreditorKind.supplier)
      for (final a in o.allocations)
        if (a.paidOn case final day?
            when !a.isReversal && !a.isOffset && !a.isCredit && !a.reversed)
          Posting(
            journal: PostingJournal.bank,
            date: day,
            kind: PostingKind.supplierPayment,
            documentId: d.summary.id,
            documentNumber: d.summary.reference,
            lines: [
              ?postingLine(
                BookRole.suppliers,
                book.code(BookRole.suppliers, day),
                _amount(d, a.amountCents),
                debitSide: true,
              ),
              ?postingLine(
                BookRole.bank,
                book.code(BookRole.bank, day),
                _amount(d, a.amountCents),
                debitSide: false,
              ),
            ],
          ),
];
