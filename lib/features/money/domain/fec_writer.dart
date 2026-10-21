// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/money/money_text.dart';
import '../../../core/text/number_text.dart';
import '../../../core/time/date_text.dart';
import '../../../core/time/workspace_time.dart';
import 'expense_repartition.dart';
import 'fec_accounts.dart';
import 'fec_lettering.dart';
import 'invoice.dart';
import 'invoice_line_cash.dart';
import 'ledger_entry.dart';
import 'vat_regime.dart';
import 'vat_tax_point.dart';

const _salesJournal = 'VE';
const _salesJournalLabel = 'Ventes';
const _bankJournal = fecBankJournal;
const _bankJournalLabel = fecBankJournalLabel;
// #936 — purchases: what the workspace paid or owes, not what it sold.
const _purchasesJournal = 'HA';
const _purchasesJournalLabel = 'Achats';
// #2355 — the VAT moving from pending to due on its tax point.
const _miscJournal = 'OD';
const _miscJournalLabel = 'Opérations diverses';

/// Writes the FEC rows: the sales journal, the bank journal, the purchases
/// journal and the tax-point entries, then sorts them as the arrêté reads.
class FecWriter {
  FecWriter({
    required this.invoices,
    required this.matches,
    required this.company,
    required this.accounts,
    required this.lineText,
    this.customersLabel = 'Clients',
    this.revenueLabel = 'Prestations de services',
    this.bankLabel = 'Banques',
    this.vatLabel = 'TVA collectée',
    this.ledger = const [],
    this.memberNames = const {},
    this.repartitions = const [],
    this.expensesLabel = 'Achats et charges',
    this.taxPoints,
    this.vatPendingLabel = "TVA collectée en attente d'exigibilité",
    this.dayOf = WorkspaceTime.dateOf,
  });

  final List<Invoice> invoices;
  final Map<String, InvoiceMatch> matches;
  final InvoiceParty company;
  final FecAccounts accounts;
  final String Function(InvoiceLine line) lineText;
  final String customersLabel;
  final String revenueLabel;
  final String bankLabel;
  final String vatLabel;
  final List<LedgerEntry> ledger;
  final Map<String, String> memberNames;
  final List<ExpenseRepartition> repartitions;
  final String expensesLabel;
  final List<VatTaxPointAmount>? taxPoints;
  final String vatPendingLabel;
  final DateTime Function(DateTime instant) dayOf;

  final rows = <List<String>>[];

  String clean(String text) =>
      text.replaceAll(RegExp(r'[\t\r\n]+'), ' ').trim();


  // #1077 — two decimals is CORRECT here: the FEC is a French tax
  // filing format and the French tax authority denominates it in euro.
  // Not a hardcoded-euro bug; do not "fix" it. Dates are YYYYMMDD (`ymd`).
  // A tab is the separator, so a tab inside a label would shift columns.
  // #927 — an entry number comes from the DOCUMENT it books (EcritureNum).
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
      ymd(date),
      account,
      clean(accountLabel),
      auxNumber,
      clean(auxLabel),
      clean(pieceRef),
      ymd(pieceDate),
      clean(label),
      minorToText(debitCents, 'EUR', decimalSeparator: ','),
      minorToText(creditCents, 'EUR', decimalSeparator: ','),
      letter,
      // DateLet: filled from the lettering group (`withLetteringDates`).
      '',
      ymd(validDate),
      '',
      '',
    ]);
  }

  late final VatTaxPointIndex? index = switch (taxPoints) {
    final points? => VatTaxPointIndex(points),
    null => null,
  };
  bool deferred(Invoice invoice, int booked) {
    final tax = index;
    return tax != null &&
        booked != 0 &&
        tax.vatAwayFrom(invoice.id, dayOf(invoice.issuedAt), booked);
  }

  /// One OD entry per tax point day: the VAT due that day leaves the
  /// pending account for the collected one (the reverse for a credit
  /// note).
  void releaseVat(Invoice invoice, String label) {
    var ordinal = 0;
    for (final MapEntry(key: day, value: vat)
        in index!.byDay(invoice.id, (a) => a.vatCents).entries) {
      if (vat == 0) continue;
      final number = '$_miscJournal-${invoice.number}-T${++ordinal}';
      for (final (account, accountLabel, debit) in [
        (accounts.vatPending, vatPendingLabel, vat > 0),
        (accounts.vat, vatLabel, vat < 0),
      ]) {
        write(
          journal: _miscJournal, journalLabel: _miscJournalLabel,
          number: number, date: day,
          account: account, accountLabel: accountLabel,
          auxNumber: '', auxLabel: '',
          pieceRef: invoice.number, pieceDate: invoice.issuedAt,
          label: label,
          debitCents: debit ? vat.abs() : 0, creditCents: debit ? 0 : vat.abs(),
          letter: '', validDate: day,
        );
      }
    }
  }

  late final ordered = [
    for (final invoice in invoices)
      if (!invoice.isVoided) invoice,
  ]..sort((a, b) => a.issuedAt.compareTo(b.issuedAt));

  /// The sales and bank journals, document by document.
  void bookInvoices() {
    for (final invoice in ordered) {
      if (invoice.isCreditNote) {
        bookCreditNote(invoice);
      } else {
        bookSale(invoice);
      }
    }
  }

  /// #936 — a credit note is a sale reversed, and it was absent: its
  /// lines are negative, so the "charges" in [bookSale] were zero and the
  /// invoice was skipped. Booked as revenue debited / customer credited,
  /// lettered with the invoice it corrects when it names one.
  void bookCreditNote(Invoice invoice) {
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
    final pending = deferred(invoice, [
      for (final s in slices)
        if (s.vatCents < 0) s.vatCents,
    ].fold(0, (a, b) => a + b));
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
          account: pending ? accounts.vatPending : accounts.vat,
          accountLabel: pending ? vatPendingLabel : vatLabel,
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
    if (pending) releaseVat(invoice, label);
    bookFecRefund(write, invoice, matches[invoice.id], accounts, customersLabel, bankLabel);
  }

  /// An invoice: the receivable, its revenue and VAT rate by rate, the
  /// credits it netted and the payment that settled the rest.
  void bookSale(Invoice invoice) {
    final charges = invoice.lines
        .where((line) => line.amountCents > 0)
        .fold(0, (sum, line) => sum + line.amountCents);
    if (charges == 0) return;
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
    final pending = deferred(invoice, [
      for (final total in breakdown)
        if (total.vatCents > 0) total.vatCents,
    ].fold(0, (a, b) => a + b));
    for (final total in breakdown) {
      // With several rates the entry label says which one, so a human
      // reading the journal can tell the lines apart: '20' or '5,5', as
      // a rate reads in a French journal.
      final rateLabel = manyRates || total.percent > 0
          ? '$label ${percentText(total.percent, decimalSeparator: ',')} %'
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
          account: pending ? accounts.vatPending : accounts.vat,
          accountLabel: pending ? vatPendingLabel : vatLabel,
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

    if (pending) releaseVat(invoice, label);

    bookCredits(invoice);
    final match = matches[invoice.id];
    bookSettlement(invoice, match);
    bookFecWriteOff(write, invoice, match, accounts, customersLabel, dayOf);
  }

  void bookCredits(Invoice invoice) {
    // The credits the invoice netted: money that had already arrived.
    var creditOrdinal = 0;
    for (final line in invoice.lines.where((l) => l.isMoneyIn)) {
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

  }

  void bookSettlement(Invoice invoice, InvoiceMatch? match) {
    // The payment that settled what was left. Only when something WAS
    // left: a solde of zero was already covered by the credits above.
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

  /// The purchases journal: reimbursed expenses.
  void bookExpenses() {
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
      letter: '', validDate: entry.createdAt,
    );
    write(
      journal: _purchasesJournal, journalLabel: _purchasesJournalLabel,
      number: number, date: entry.on,
      account: accounts.customers, accountLabel: customersLabel,
      auxNumber: entry.memberId, auxLabel: memberNames[entry.memberId] ?? '',
      pieceRef: entry.id, pieceDate: entry.on,
      label: label, debitCents: 0, creditCents: entry.amountCents,
      letter: '', validDate: entry.createdAt,
    );
  }
  }

  /// The purchases journal: shared costs the workspace paid and split.
  void bookRepartitions() {
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
      letter: '', validDate: r.createdAt,
    );
    write(
      journal: _purchasesJournal, journalLabel: _purchasesJournalLabel,
      number: number, date: on,
      account: accounts.bank, accountLabel: bankLabel,
      auxNumber: '', auxLabel: '',
      pieceRef: r.id, pieceDate: on,
      label: r.title, debitCents: 0, creditCents: r.amountCents,
      letter: '', validDate: r.createdAt,
    );
  }
  }

  String file(List<String> columns) {
  // Chronological, then by journal and entry number.
  //
  // The rows are BUILT document by document — an invoice's sale, then
  // the cash that settled it — so a July payment for a June invoice was
  // written before the July invoices that follow it. Every entry was
  // correct and the file read as though the books had been kept out of
  // order, which is the first thing an auditor notices and the last
  // thing you want them asking about.
  //
  // A STABLE sort on the date alone, and the tiebreak matters. Ordering
  // by journal code within a day puts BQ before VE — the bank entry
  // ahead of the sale that created it, which is backwards in the one
  // direction an accountant reads. Insertion order is document by
  // document, so within a day it is already causal: the invoice, then
  // the cash that settled it. `List.sort` is not stable, hence the
  // index.
  //
  // `EcritureDate` is column index 3. Sorting cannot change what #927
  // fixed: an entry's number comes from the document it books, never
  // from its position in the file.
  final indexed = [
    for (final (i, row) in withLetteringDates(rows).indexed) (row: row, at: i),
  ]..sort((a, b) {
      final byDate = a.row[3].compareTo(b.row[3]);
      return byDate != 0 ? byDate : a.at.compareTo(b.at);
    });
  final sorted = [for (final e in indexed) e.row];
  return [
    columns.join('\t'),
    for (final row in sorted) row.join('\t'),
  ].join('\r\n');
  }
}
