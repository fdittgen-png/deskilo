// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2365 — the FEC of an issuer that keeps a local book: the posting engine's
// entries (`compute_postings`), one row per line, on the book's own chart.
// Nothing is derived around the engine: the journals, the accounts, the
// pending tax and the purchases are what the engine booked.
//
//   * JournalCode is the posting's journal (VE, BQ, HA, OD).
//   * EcritureNum comes from the DOCUMENT it books (#927), never from a
//     per-file counter: `<journal>-<document>`, and `-2`, `-3`... for a
//     second entry of the same document in the same journal.
//   * A receivable or payable line (customers, suppliers) is lettered with
//     its document when that document's lines on the account balance in the
//     file; DateLet is then the date of the last of them
//     ([withLetteringDates]). An open balance stays unlettered.
import '../../../core/money/money_text.dart';
import '../../../core/time/date_text.dart';
import 'accounting_amount.dart';
import 'book_chart.dart';
import 'fec.dart';
import 'fec_lettering.dart';
import 'posting.dart';

const _journalLabels = {
  PostingJournal.sales: 'Ventes',
  PostingJournal.bank: 'Banque',
  PostingJournal.purchases: 'Achats',
  PostingJournal.other: 'Opérations diverses',
};

// The FEC is a French file: its labels are French, as the arrêté reads them.
const _kindLabels = {
  PostingKind.invoice: 'Facture',
  PostingKind.creditNote: 'Avoir',
  PostingKind.receipt: 'Encaissement',
  PostingKind.refund: 'Remboursement',
  PostingKind.writeOff: 'Créance irrécouvrable',
  PostingKind.expense: 'Dépense',
  PostingKind.supplierBill: 'Facture fournisseur',
  PostingKind.supplierCreditNote: 'Avoir fournisseur',
  PostingKind.supplierPayment: 'Règlement fournisseur',
  PostingKind.vatRelease: 'TVA exigible',
  PostingKind.memberReceipt: 'Note de frais',
  PostingKind.reimbursement: 'Remboursement de frais',
};

const _lettered = {BookRole.customers, BookRole.suppliers};

/// The FEC file of [postings] (in the engine's order), the accounts named
/// by [accountNames] (code → name; the code where the chart has none).
String buildFecFromPostings(
  List<Posting> postings, {
  required Map<String, String> accountNames,
}) {
  String clean(String text) =>
      text.replaceAll(RegExp(r'[\t\r\n]+'), ' ').trim();
  String amount(AccountingAmount a) =>
      minorToText(a.minor, a.currency, decimalSeparator: ',');
  String reference(Posting p) => p.documentNumber.isNotEmpty
      ? p.documentNumber
      : p.documentId.substring(0, p.documentId.length.clamp(0, 8));

  final open = <String, int>{};
  for (final p in postings) {
    for (final l in p.lines) {
      if (!_lettered.contains(l.role)) continue;
      final key = '${l.accountCode}|${reference(p)}';
      open[key] = (open[key] ?? 0) + l.debit.minor - l.credit.minor;
    }
  }
  final seen = <String, int>{};
  final rows = <List<String>>[];
  for (final p in postings) {
    final ref = reference(p);
    final base = '${p.journal.code}-$ref';
    final n = seen[base] = (seen[base] ?? 0) + 1;
    final number = n == 1 ? base : '$base-$n';
    final label = '${_kindLabels[p.kind] ?? p.kind.wire} $ref';
    for (final l in p.lines) {
      final key = '${l.accountCode}|$ref';
      final letter = _lettered.contains(l.role) && open[key] == 0;
      rows.add([
        p.journal.code,
        _journalLabels[p.journal]!,
        number,
        ymd(p.date),
        l.accountCode,
        clean(accountNames[l.accountCode] ?? l.accountCode),
        '',
        '',
        clean(ref),
        ymd(p.date),
        clean(label),
        amount(l.debit),
        amount(l.credit),
        if (letter) ref else '',
        // DateLet: filled from the lettering group below.
        '',
        ymd(p.date),
        '',
        '',
      ]);
    }
  }
  return fecText(withLetteringDates(rows));
}
