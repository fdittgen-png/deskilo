// SPDX-License-Identifier: 0BSD
import 'expense_repartition.dart';
import 'invoice.dart';
import 'ledger_entry.dart';
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
    this.expenses = '606000',
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

  /// #936 — what the workspace spends: reimbursed expenses and shared
  /// costs. 606 "achats non stockés" by default; the accountant's chart
  /// wins at export time like the others.
  final String expenses;
}

/// Journal codes and labels. Two journals are enough for an invoicing-only
/// export: sales, and cash.
const _salesJournal = 'VE';
const _salesJournalLabel = 'Ventes';
const _bankJournal = 'BQ';
const _bankJournalLabel = 'Banque';
// #936 — purchases: what the workspace paid or owes, not what it sold.
const _purchasesJournal = 'HA';
const _purchasesJournalLabel = 'Achats';

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
String fecFileName(String legalId, DateTime fiscalYearEnd,
    {bool development = false}) {
  final siren = legalId.replaceAll(RegExp('[^0-9]'), '');
  final stamp = '${fiscalYearEnd.year}'
      '${fiscalYearEnd.month.toString().padLeft(2, '0')}'
      '${fiscalYearEnd.day.toString().padLeft(2, '0')}';
  // #936 — a development workspace's books must never pass for the real
  // ones: the name says so before anyone opens the file.
  return '${development ? 'DEV-' : ''}${siren.isEmpty ? 'FEC' : siren}FEC$stamp.txt';
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
  // #936 — the purchases side: reimbursed expenses and shared costs,
  // which no journal carried before.
  List<LedgerEntry> ledger = const [],
  Map<String, String> memberNames = const {},
  List<ExpenseRepartition> repartitions = const [],
  String expensesLabel = 'Achats et charges',
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
  // #927 — an entry number is derived from the DOCUMENT it books, never
  // from a per-file counter. A counter restarts at 1 on every export, so
  // a January-to-June file and a full-year file both contained a
  // VE0001 — and they were different entries. EcritureNum exists to
  // identify an entry uniquely and irreversibly (art. A47 A-1 du LPF);
  // a number that changes with the range of the export cannot. Built
  // from the invoice number (unique per workspace) plus, for the bank
  // side, which of the invoice's cash movements it is, the number is
  // the same in every file that carries the entry. Continuity of the
  // series is #925's persisted sequence; this removes the collision.

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
    // #936 — a credit note is a sale reversed, and it was absent: its
    // lines are negative, so the "charges" below were zero and the
    // invoice was skipped. Booked as revenue debited / customer credited,
    // lettered with the invoice it corrects when it names one.
    if (invoice.isCreditNote) {
      final entry = '$_salesJournal-${invoice.number}';
      final label = 'Avoir ${invoice.number}'
          '${invoice.replacesNumber.isEmpty ? '' : ' sur ${invoice.replacesNumber}'}';
      final letter = invoice.replacesNumber.isEmpty
          ? invoice.number
          : invoice.replacesNumber;
      final total = -invoice.totalCents;
      final zeroCategory =
          vatRegimeFromWire(invoice.sellerParty?.vatRegime ?? company.vatRegime)
              .taxCategoryCode;
      // The breakdown is built from what an invoice CHARGES; a credit note
      // charges nothing, so it comes back empty and the whole note is one
      // revenue reversal. When it does carry slices (mixed documents),
      // each slice is reversed on its own.
      final slices = invoice.vatBreakdown(zeroCategory: zeroCategory)
          .where((s) => s.netCents != 0 || s.vatCents != 0)
          .toList();
      if (slices.isEmpty) {
        write(
          journal: _salesJournal, journalLabel: _salesJournalLabel,
          number: entry, date: invoice.issuedAt,
          account: accounts.revenue, accountLabel: revenueLabel,
          auxNumber: '', auxLabel: '',
          pieceRef: invoice.number, pieceDate: invoice.issuedAt,
          label: label, debitCents: total, creditCents: 0,
          letter: letter, validDate: invoice.issuedAt,
        );
      }
      for (final slice in slices) {
        write(
          journal: _salesJournal, journalLabel: _salesJournalLabel,
          number: entry, date: invoice.issuedAt,
          account: accounts.revenue, accountLabel: revenueLabel,
          auxNumber: '', auxLabel: '',
          pieceRef: invoice.number, pieceDate: invoice.issuedAt,
          label: label, debitCents: -slice.netCents, creditCents: 0,
          letter: letter, validDate: invoice.issuedAt,
        );
        if (slice.vatCents < 0) {
          write(
            journal: _salesJournal, journalLabel: _salesJournalLabel,
            number: entry, date: invoice.issuedAt,
            account: accounts.vat, accountLabel: vatLabel,
            auxNumber: '', auxLabel: '',
            pieceRef: invoice.number, pieceDate: invoice.issuedAt,
            label: label, debitCents: -slice.vatCents, creditCents: 0,
            letter: letter, validDate: invoice.issuedAt,
          );
        }
      }
      write(
        journal: _salesJournal, journalLabel: _salesJournalLabel,
        number: entry, date: invoice.issuedAt,
        account: accounts.customers, accountLabel: customersLabel,
        auxNumber: invoice.memberId, auxLabel: invoice.memberName,
        pieceRef: invoice.number, pieceDate: invoice.issuedAt,
        label: label, debitCents: 0, creditCents: total,
        letter: letter, validDate: invoice.issuedAt,
      );
      continue;
    }
    final charges = invoice.lines
        .where((line) => line.amountCents > 0)
        .fold(0, (sum, line) => sum + line.amountCents);
    if (charges == 0) continue;
    final entry = '$_salesJournal-${invoice.number}';
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
    var creditOrdinal = 0;
    for (final line in invoice.lines.where((l) => l.amountCents < 0)) {
      // The invoice's lines are frozen, so the ordinal is stable.
      creditOrdinal++;
      final cashEntry = '$_bankJournal-${invoice.number}-C$creditOrdinal';
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
      // One settling match per invoice (0067): the suffix is enough.
      final cashEntry = '$_bankJournal-${invoice.number}-P';
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
  // #936 — the purchases journal. A reimbursed expense is money the
  // workspace owes a member: expenses debited, the member's customer
  // account credited (it nets against what they are invoiced). A shared
  // cost the workspace paid and split is the expense itself, paid from
  // the bank; its shares reach the sales journal as invoice lines and
  // are not repeated here.
  for (final entry in [...ledger]..sort((a, b) => a.on.compareTo(b.on))) {
    if (entry.kind != LedgerKind.credit ||
        entry.category != LedgerCategory.expense) {
      continue;
    }
    final number = '$_purchasesJournal-${entry.id}';
    final label = entry.description.isEmpty
        ? 'Remboursement de frais'
        : 'Remboursement ${entry.description}';
    write(
      journal: _purchasesJournal, journalLabel: _purchasesJournalLabel,
      number: number, date: entry.on,
      account: accounts.expenses, accountLabel: expensesLabel,
      auxNumber: '', auxLabel: '',
      pieceRef: entry.id, pieceDate: entry.on,
      label: label, debitCents: entry.amountCents, creditCents: 0,
      letter: '', validDate: entry.on,
    );
    write(
      journal: _purchasesJournal, journalLabel: _purchasesJournalLabel,
      number: number, date: entry.on,
      account: accounts.customers, accountLabel: customersLabel,
      auxNumber: entry.memberId, auxLabel: memberNames[entry.memberId] ?? '',
      pieceRef: entry.id, pieceDate: entry.on,
      label: label, debitCents: 0, creditCents: entry.amountCents,
      letter: '', validDate: entry.on,
    );
  }
  for (final r in [...repartitions]
    ..sort((a, b) => (a.appliedAt ?? a.createdAt).compareTo(b.appliedAt ?? b.createdAt))) {
    if (r.status != 'confirmed' || r.amountCents <= 0) continue;
    final on = r.appliedAt ?? r.createdAt;
    final number = '$_purchasesJournal-R-${r.id}';
    write(
      journal: _purchasesJournal, journalLabel: _purchasesJournalLabel,
      number: number, date: on,
      account: accounts.expenses, accountLabel: expensesLabel,
      auxNumber: '', auxLabel: '',
      pieceRef: r.id, pieceDate: on,
      label: r.title, debitCents: r.amountCents, creditCents: 0,
      letter: '', validDate: on,
    );
    write(
      journal: _purchasesJournal, journalLabel: _purchasesJournalLabel,
      number: number, date: on,
      account: accounts.bank, accountLabel: bankLabel,
      auxNumber: '', auxLabel: '',
      pieceRef: r.id, pieceDate: on,
      label: r.title, debitCents: 0, creditCents: r.amountCents,
      letter: '', validDate: on,
    );
  }
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
