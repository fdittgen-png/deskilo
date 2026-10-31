// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3152 — the acquisition tax in the books. A service bought from a
// supplier abroad (the expense's `vat.acquisition`, 0413) owes VAT on its
// amount as the base: the return files it as output (Ziffer 383) and its
// deductible share as input (400/405), both on the expense's tax point
// (`vat_input_amounts`, 0605). The entry, on that day:
//
//   Dr `vat_input:<group>`   the deductible share
//   Dr `expenses`            the share that is not deductible, if any
//   Cr `vat_output:<group>`  the tax owed
//
// so the VAT accounts reconcile to the return. The expense's amount itself
// books where it books (a member's receipt; nothing for a plain expense).
// The server engine (`compute_postings`, 0622) is held to this unit.
import 'accounting_amount.dart';
import 'book_chart.dart';
import 'posting.dart';
import 'posting_rules.dart';

/// One expense bought abroad, as the return reads it.
typedef VatAcquisition = ({
  String expenseId,
  DateTime day,
  num percent,
  String currency,
  int taxOwedCents,
  int deductibleCents,
});

/// The document number an acquisition entry carries: the expense names no
/// number, so the start of its id (the server writes the same).
String acquisitionNumber(String expenseId) =>
    expenseId.length <= 8 ? expenseId : expenseId.substring(0, 8);

/// The acquisition-tax entries of [acquisitions] on [book]; [groupOf] names
/// the rate group of a rate (the tax reference's `rate` rows, category S).
List<Posting> acquisitionPostingsOf({
  required List<VatAcquisition> acquisitions,
  required PostingBook book,
  required String Function(num percent) groupOf,
}) => [
  for (final a in acquisitions)
    if (a.taxOwedCents != 0) _entry(a, book, groupOf(a.percent)),
];

Posting _entry(VatAcquisition a, PostingBook book, String group) {
  final qualifier = group.isEmpty ? null : group;
  AccountingAmount amount(int minor) => AccountingAmount(a.currency, minor);
  return Posting(
    journal: PostingJournal.purchases,
    date: a.day,
    kind: PostingKind.acquisitionTax,
    documentId: a.expenseId,
    documentNumber: acquisitionNumber(a.expenseId),
    lines: [
      ?postingLine(
        BookRole.vatInput,
        book.code(BookRole.vatInput, a.day, qualifier: qualifier),
        amount(a.deductibleCents),
        debitSide: true,
        qualifier: qualifier,
      ),
      ?postingLine(
        BookRole.expenses,
        book.code(BookRole.expenses, a.day),
        amount(a.taxOwedCents - a.deductibleCents),
        debitSide: true,
      ),
      ?postingLine(
        BookRole.vatOutput,
        book.code(BookRole.vatOutput, a.day, qualifier: qualifier),
        amount(a.taxOwedCents),
        debitSide: false,
        qualifier: qualifier,
      ),
    ],
  );
}
