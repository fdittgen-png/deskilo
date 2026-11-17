// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A posting of a document in another currency than the book's, written in
// the book's currency at the document's recorded rate. Each line is
// converted once, rounded half up, and keeps the amount it was converted
// from; the cents the rounding leaves go to the largest line of the side
// that is short, so the entry stays balanced. The server's engine
// (`compute_postings`, `posting_at_rate`) converts by the same rule.
import 'accounting_amount.dart';
import 'posting.dart';

/// [p] in [rate]'s quote currency; every line carries its original amount.
/// A refusal when [rate] is not from [p]'s currency.
Posting postingAtRate(Posting p, FxRate rate) {
  final converted = [
    for (final l in p.lines)
      _line(
        l,
        convert(l.debit, rate, RoundingPolicy.halfUp),
        convert(l.credit, rate, RoundingPolicy.halfUp),
        l.debit.minor != 0 ? l.debit : l.credit,
      ),
  ];
  if (converted.isNotEmpty) _balance(converted, rate.quote.toUpperCase());
  return Posting(
    journal: p.journal,
    date: p.date,
    kind: p.kind,
    documentId: p.documentId,
    documentNumber: p.documentNumber,
    lines: converted,
  );
}

PostingLine _line(
  PostingLine l,
  AccountingAmount debit,
  AccountingAmount credit,
  AccountingAmount? original,
) => PostingLine(
  role: l.role,
  qualifier: l.qualifier,
  accountCode: l.accountCode,
  debit: debit,
  credit: credit,
  original: original,
);

/// Gives the rounding gap of [lines] to the largest line of the short side
/// (the first of equal ones).
void _balance(List<PostingLine> lines, String currency) {
  var gap = 0;
  for (final l in lines) {
    gap += l.debit.minor - l.credit.minor;
  }
  if (gap == 0) return;
  // Debits ahead: the largest credit takes the cents; credits ahead: the
  // largest debit does.
  final toCredit = gap > 0;
  int side(PostingLine l) => toCredit ? l.credit.minor : l.debit.minor;
  var best = -1;
  for (var i = 0; i < lines.length; i++) {
    if (side(lines[i]) == 0) continue;
    if (best < 0 || side(lines[i]) > side(lines[best])) best = i;
  }
  if (best < 0) return;
  final l = lines[best];
  final cents = AccountingAmount(currency, gap.abs());
  lines[best] = toCredit
      ? _line(l, l.debit, l.credit + cents, l.original)
      : _line(l, l.debit + cents, l.credit, l.original);
}
