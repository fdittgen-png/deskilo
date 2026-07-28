// SPDX-License-Identifier: 0BSD
import 'invoice.dart';
import 'vat_regime.dart';

/// The accounts a FEC cannot be written without. Defaults follow the
/// French *plan comptable général*; an accountant using a different chart
/// corrects them at export time — which is also the moment the exporter
/// shows what it is about to book, rather than inventing it silently.
class FecAccounts {
  const FecAccounts({
    this.customers = '411000',
    this.revenue = '706000',
    this.bank = '512000',
    this.vat = '445710',
  });

  /// PCG 411 — Clients (the receivable).
  final String customers;

  /// PCG 706 — Prestations de services (what a coworking sells).
  final String revenue;

  /// PCG 512 — Banques (where the money lands).
  final String bank;

  /// PCG 44571 — TVA collectée. Only used when the invoice carries VAT
  /// (0072); a workspace that charges none never books to it.
  final String vat;
}

/// Journal codes and labels. Two journals are enough for an invoicing-only
/// export: sales, and cash.
const _salesJournal = 'VE';
const _salesJournalLabel = 'Ventes';
const _bankJournal = 'BQ';
const _bankJournalLabel = 'Banque';

/// The 18 columns of the FEC, in the order the arrêté du 29 juillet 2013
/// fixes them (BIC/IS variant). Order is not negotiable: the DGFiP's own
/// reader positions by column.
const List<String> fecColumns = [
  'JournalCode',
  'JournalLib',
  'EcritureNum',
  'EcritureDate',
  'CompteNum',
  'CompteLib',
  'CompAuxNum',
  'CompAuxLib',
  'PieceRef',
  'PieceDate',
  'EcritureLib',
  'Debit',
  'Credit',
  'EcritureLet',
  'DateLet',
  'ValidDate',
  'Montantdevise',
  'Idevise',
];

/// The mandated file name: `<SIREN>FEC<YYYYMMDD>.txt`, where the date is
/// the CLOSE of the fiscal year. Not a suggestion — an auditor's tooling
/// keys off it.
String fecFileName(String legalId, DateTime fiscalYearEnd) {
  final siren = legalId.replaceAll(RegExp('[^0-9]'), '');
  final stamp = '${fiscalYearEnd.year}'
      '${fiscalYearEnd.month.toString().padLeft(2, '0')}'
      '${fiscalYearEnd.day.toString().padLeft(2, '0')}';
  return '${siren.isEmpty ? 'FEC' : siren}FEC$stamp.txt';
}

/// **FEC** — *Fichier des Écritures Comptables*, the file French law
/// requires a business to hand over in an audit (art. L47 A-I du LPF).
/// Unlike SAF-T it is not XML: a tab-separated flat file, one line per
/// accounting entry, with the column names as its first line.
///
/// What gets booked, per non-voided invoice:
///  * journal **VE** — the receivable at the invoice's CHARGES total (its
///    gross, debit customers), against the revenue NET of tax and the
///    collected VAT (credit revenue + credit 44571), one pair per rate.
///    Without VAT the tax line is absent and the entry is the plain two
///    lines it always was;
///  * journal **BQ** — every credit the invoice netted (the month's
///    payments, snapshotted on the document), debit bank / credit
///    customers, lettered with the invoice number;
///  * journal **BQ** — the payment that MATCHED the invoice, when the
///    invoice still had a balance to settle. Skipped when the solde was
///    already zero: that money is the credit lines above, and booking it
///    twice would inflate the bank.
///
/// Cancelled invoices are absent. One that was voided before payment was
/// never booked, so there is nothing to reverse — and its replacement
/// carries the corrected figures.
///
/// Amounts use the comma decimal separator and dates the `YYYYMMDD` form,
/// as the arrêté specifies.
String buildFecFile({
  required List<Invoice> invoices,
  required Map<String, InvoiceMatch> matches,
  required InvoiceParty company,
  required FecAccounts accounts,
  required String Function(InvoiceLine line) lineText,
  /// Label of the customers account, e.g. 'Clients'.
  String customersLabel = 'Clients',
  String revenueLabel = 'Prestations de services',
  String bankLabel = 'Banques',
  String vatLabel = 'TVA collectée',
}) {
  String money(int cents) =>
      (cents / 100).toStringAsFixed(2).replaceAll('.', ',');
  String stamp(DateTime date) => '${date.year}'
      '${date.month.toString().padLeft(2, '0')}'
      '${date.day.toString().padLeft(2, '0')}';
  // A tab is the separator, so a tab inside a label would shift columns.
  String clean(String text) =>
      text.replaceAll(RegExp(r'[\t\r\n]+'), ' ').trim();

  final rows = <List<String>>[];
  var salesCount = 0;
  var bankCount = 0;

  void write({
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
  }) {
    rows.add([
      journal,
      journalLabel,
      number,
      stamp(date),
      account,
      clean(accountLabel),
      auxNumber,
      clean(auxLabel),
      clean(pieceRef),
      stamp(pieceDate),
      clean(label),
      money(debitCents),
      money(creditCents),
      letter,
      // No automatic reconciliation date: the lettering is the app's, the
      // date belongs to whoever reconciles the bank.
      '',
      stamp(validDate),
      '',
      '',
    ]);
  }

  final ordered = [
    for (final invoice in invoices)
      if (!invoice.isVoided) invoice,
  ]..sort((a, b) => a.issuedAt.compareTo(b.issuedAt));

  for (final invoice in ordered) {
    final charges = invoice.lines
        .where((line) => line.amountCents > 0)
        .fold(0, (sum, line) => sum + line.amountCents);
    if (charges == 0) continue;
    salesCount++;
    final entry = '$_salesJournal${salesCount.toString().padLeft(4, '0')}';
    final label = 'Facture ${invoice.number}'
        '${invoice.period == null ? '' : ' ${invoice.period}'}';
    // The receivable…
    write(
      journal: _salesJournal,
      journalLabel: _salesJournalLabel,
      number: entry,
      date: invoice.issuedAt,
      account: accounts.customers,
      accountLabel: customersLabel,
      auxNumber: invoice.memberId,
      auxLabel: invoice.memberName,
      pieceRef: invoice.number,
      pieceDate: invoice.issuedAt,
      label: label,
      debitCents: charges,
      creditCents: 0,
      letter: invoice.number,
      validDate: invoice.issuedAt,
    );
    // …and what earned it, rate by rate: the revenue is what was sold
    // net, the VAT is money collected for the state.
    final zeroCategory =
        vatRegimeFromWire(invoice.sellerParty?.vatRegime ?? company.vatRegime)
            .taxCategoryCode;
    final breakdown = invoice.vatBreakdown(zeroCategory: zeroCategory);
    final manyRates = breakdown.length > 1;
    for (final total in breakdown) {
      // With several rates the entry label says which one, so a human
      // reading the journal can tell the lines apart.
      final rateLabel = manyRates || total.percent > 0
          ? '$label ${_percent(total.percent)} %'
          : label;
      write(
        journal: _salesJournal,
        journalLabel: _salesJournalLabel,
        number: entry,
        date: invoice.issuedAt,
        account: accounts.revenue,
        accountLabel: revenueLabel,
        auxNumber: '',
        auxLabel: '',
        pieceRef: invoice.number,
        pieceDate: invoice.issuedAt,
        label: rateLabel,
        debitCents: 0,
        creditCents: total.netCents,
        letter: invoice.number,
        validDate: invoice.issuedAt,
      );
      if (total.vatCents > 0) {
        write(
          journal: _salesJournal,
          journalLabel: _salesJournalLabel,
          number: entry,
          date: invoice.issuedAt,
          account: accounts.vat,
          accountLabel: vatLabel,
          auxNumber: '',
          auxLabel: '',
          pieceRef: invoice.number,
          pieceDate: invoice.issuedAt,
          label: rateLabel,
          debitCents: 0,
          creditCents: total.vatCents,
          letter: invoice.number,
          validDate: invoice.issuedAt,
        );
      }
    }

    // The credits the invoice netted: money that had already arrived.
    for (final line in invoice.lines.where((l) => l.amountCents < 0)) {
      bankCount++;
      final cashEntry = '$_bankJournal${bankCount.toString().padLeft(4, '0')}';
      final amount = -line.amountCents;
      final cashLabel = lineText(line);
      write(
        journal: _bankJournal,
        journalLabel: _bankJournalLabel,
        number: cashEntry,
        date: invoice.issuedAt,
        account: accounts.bank,
        accountLabel: bankLabel,
        auxNumber: '',
        auxLabel: '',
        pieceRef: invoice.number,
        pieceDate: invoice.issuedAt,
        label: cashLabel,
        debitCents: amount,
        creditCents: 0,
        letter: invoice.number,
        validDate: invoice.issuedAt,
      );
      write(
        journal: _bankJournal,
        journalLabel: _bankJournalLabel,
        number: cashEntry,
        date: invoice.issuedAt,
        account: accounts.customers,
        accountLabel: customersLabel,
        auxNumber: invoice.memberId,
        auxLabel: invoice.memberName,
        pieceRef: invoice.number,
        pieceDate: invoice.issuedAt,
        label: cashLabel,
        debitCents: 0,
        creditCents: amount,
        letter: invoice.number,
        validDate: invoice.issuedAt,
      );
    }

    // The payment that settled what was left. Only when something WAS
    // left: a solde of zero was already covered by the credits above.
    final match = matches[invoice.id];
    if (match != null && !match.pending && invoice.totalCents > 0) {
      bankCount++;
      final cashEntry = '$_bankJournal${bankCount.toString().padLeft(4, '0')}';
      final label = 'Règlement ${invoice.number}';
      write(
        journal: _bankJournal,
        journalLabel: _bankJournalLabel,
        number: cashEntry,
        date: match.matchedAt,
        account: accounts.bank,
        accountLabel: bankLabel,
        auxNumber: '',
        auxLabel: '',
        pieceRef: invoice.number,
        pieceDate: invoice.issuedAt,
        label: label,
        debitCents: match.paidCents,
        creditCents: 0,
        letter: invoice.number,
        validDate: match.matchedAt,
      );
      write(
        journal: _bankJournal,
        journalLabel: _bankJournalLabel,
        number: cashEntry,
        date: match.matchedAt,
        account: accounts.customers,
        accountLabel: customersLabel,
        auxNumber: invoice.memberId,
        auxLabel: invoice.memberName,
        pieceRef: invoice.number,
        pieceDate: invoice.issuedAt,
        label: label,
        debitCents: 0,
        creditCents: match.paidCents,
        letter: invoice.number,
        validDate: match.matchedAt,
      );
    }
  }

  // CRLF: the file goes to accounting software that mostly runs on
  // Windows, and the arrêté does not forbid it.
  return [
    fecColumns.join('\t'),
    for (final row in rows) row.join('\t'),
  ].join('\r\n');
}

/// '20' or '5,5' — a rate as it reads in a French journal, where the
/// comma is the decimal separator.
String _percent(double percent) => percent == percent.roundToDouble()
    ? percent.toStringAsFixed(0)
    : percent.toString().replaceAll('.', ',');
