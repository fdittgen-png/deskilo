// SPDX-License-Identifier: AGPL-3.0-or-later

import 'fec_accounts.dart';
import 'invoice.dart';
import 'invoice_line_cash.dart';

/// The bank journal's code and name.
const fecBankJournal = 'BQ';
const fecBankJournalLabel = 'Banque';

/// #2365 — `DateLet` (column index 14) is mandatory whenever `EcritureLet`
/// (index 13) is filled: it is the date the lettering was made, i.e. the
/// date of the last entry that took part in it. The builders write the
/// letter (the invoice number) on every row of an invoice's group; this
/// fills the date from the group itself, so the two can never disagree.
/// Dates are the `YYYYMMDD` text of `EcritureDate` (index 3), which sorts
/// as a date.
List<List<String>> withLetteringDates(List<List<String>> rows) {
  final last = <String, String>{};
  for (final row in rows) {
    final letter = row[13];
    if (letter.isEmpty) continue;
    final seen = last[letter];
    if (seen == null || row[3].compareTo(seen) > 0) last[letter] = row[3];
  }
  return [
    for (final row in rows)
      if (row[13].isEmpty)
        row
      else
        [...row.take(14), last[row[13]]!, ...row.skip(15)],
  ];
}

typedef FecWrite = void Function({
  required String journal,
  required String journalLabel,
  required String number,
  required DateTime date,
  required String account,
  required String accountLabel,
  required String auxNumber,
  required String auxLabel,
  required String pieceRef,
  required DateTime pieceDate,
  required String label,
  required int debitCents,
  required int creditCents,
  required String letter,
  required DateTime validDate,
});

/// #2365 — the refund of a credit note is money OUT, in the bank journal:
/// the receivable the note opened is cleared (customers debited, bank
/// credited), lettered with the note's own letter.
///
/// #927 — an entry number is derived from the DOCUMENT it books, never from
/// a per-file counter: a counter restarts at 1 on every export, so a
/// January-to-June file and a full-year file both contained a VE0001 and
/// they were different entries; EcritureNum identifies an entry uniquely
/// and irreversibly (art. A47 A-1 du LPF).
void bookFecRefund(
  FecWrite write,
  Invoice invoice,
  InvoiceMatch? match,
  FecAccounts accounts,
  String customersLabel,
  String bankLabel,
) {
  final refund = refundedCents(invoice, match);
  if (refund == 0) return;
  final on = match!.matchedAt;
  final text = 'Remboursement ${invoice.number}';
  final letter = invoice.replacesNumber.isEmpty
      ? invoice.number
      : invoice.replacesNumber;
  for (final (account, accountLabel, debit) in [
    (accounts.customers, customersLabel, true),
    (accounts.bank, bankLabel, false),
  ]) {
    write(
      journal: fecBankJournal,
      journalLabel: fecBankJournalLabel,
      number: '$fecBankJournal-${invoice.number}-R',
      date: on,
      account: account,
      accountLabel: accountLabel,
      auxNumber: debit ? invoice.memberId : '',
      auxLabel: debit ? invoice.memberName : '',
      pieceRef: invoice.number,
      pieceDate: invoice.issuedAt,
      label: text,
      debitCents: debit ? refund : 0,
      creditCents: debit ? 0 : refund,
      letter: letter,
      validDate: on,
    );
  }
}

/// #2365 — what the owner gave up of an invoice: the unpaid rest leaves the
/// receivable for the loss account (PCG 654), on the write-off day, lettered
/// with the invoice so its group closes. Booked gross: the VAT regularisation
/// has its own conditions and is the accountant's. A write-off still awaiting
/// validation books nothing.
void bookFecWriteOff(
  FecWrite write,
  Invoice invoice,
  InvoiceMatch? match,
  FecAccounts accounts,
  String customersLabel,
  DateTime Function(DateTime instant) dayOf,
) {
  final writtenOff = match?.writeoffAt;
  if (match == null || match.pending || writtenOff == null) return;
  final owed = invoice.totalCents - match.paidCents;
  if (owed <= 0) return;
  final entry = 'OD-${invoice.number}-W';
  final label = 'Créance irrécouvrable ${invoice.number}';
  final day = dayOf(writtenOff);
  for (final (account, accountLabel, aux, debit) in [
    (accounts.writeOff, 'Pertes sur créances irrécouvrables', false, true),
    (accounts.customers, customersLabel, true, false),
  ]) {
    write(
      journal: 'OD', journalLabel: 'Opérations diverses',
      number: entry, date: day,
      account: account, accountLabel: accountLabel,
      auxNumber: aux ? invoice.memberId : '',
      auxLabel: aux ? invoice.memberName : '',
      pieceRef: invoice.number, pieceDate: invoice.issuedAt,
      label: label, debitCents: debit ? owed : 0, creditCents: debit ? 0 : owed,
      letter: invoice.number, validDate: day,
    );
  }
}
