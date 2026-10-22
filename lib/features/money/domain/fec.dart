// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:meta/meta.dart';

import '../../../core/time/date_text.dart';
import '../../../core/time/workspace_time.dart';
import 'expense_repartition.dart';
import 'fec_accounts.dart';
import 'fec_writer.dart';
import 'invoice.dart';
import 'ledger_entry.dart';
import 'vat_tax_point.dart';
export 'fec_accounts.dart';

/// Journal codes and labels. Two journals are enough for an invoicing-only
/// export: sales, and cash.

/// The 18 columns of the FEC, in the order the arrêté du 29 juillet 2013
/// fixes them (BIC/IS variant). Order is not negotiable: the DGFiP's own
/// reader positions by column.
@visibleForTesting
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
  final stamp = ymd(fiscalYearEnd);
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
///    twice would inflate the bank;
///  * journal **OD** (#2355) — when [taxPoints] (the tax-point engine's
///    ledger, `vat_tax_point.dart`) dates an invoice's VAT elsewhere than
///    its issue day, the sale books that VAT on the pending account
///    (44574) and each tax point moves its share to 44571 on its own
///    date, so the collected-VAT account carries exactly what the
///    declaration and the VAT report declare. Without [taxPoints] every
///    VAT is due on the issue day, as before.
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
  List<VatTaxPointAmount>? taxPoints,
  String vatPendingLabel = "TVA collectée en attente d'exigibilité",
  DateTime Function(DateTime instant) dayOf = WorkspaceTime.dateOf,
}) {
  final writer = FecWriter(
    invoices: invoices,
    matches: matches,
    company: company,
    accounts: accounts,
    lineText: lineText,
    customersLabel: customersLabel,
    revenueLabel: revenueLabel,
    bankLabel: bankLabel,
    vatLabel: vatLabel,
    ledger: ledger,
    memberNames: memberNames,
    repartitions: repartitions,
    expensesLabel: expensesLabel,
    taxPoints: taxPoints,
    vatPendingLabel: vatPendingLabel,
    dayOf: dayOf,
  )
    ..bookInvoices()
    ..bookExpenses()
    ..bookRepartitions();
  return writer.file(fecColumns);
}

/// #2365 — [rows] as an FEC file: the columns, then one line per row.
String fecText(Iterable<List<String>> rows) => [
  fecColumns.join('\t'),
  for (final row in rows) row.join('\t'),
].join('\r\n');
