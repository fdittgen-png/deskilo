// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import 'accounting_source_snapshot.dart';
import 'expense_repartition.dart';
import 'ledger_entry.dart';

/// #2365 — the books of ONE fiscal year. The export screen and the year
/// archive hold the workspace's whole ledger and every repartition; a
/// file for 2026 that carries a 2024 expense, or a DATEV file whose
/// Belegdatum has no year to say it is from 2024, is wrong money in the
/// wrong period. The same dates the exporters write are the ones cut on.
typedef ExportYearBooks = ({
  List<Invoice> invoices,
  List<LedgerEntry> ledger,
  List<ExpenseRepartition> repartitions,
});

/// [ExportYearBooks] plus the payment matches (settlements transparent,
/// #831) and instalments, the book-profile versions of the same source
/// response (#2365) and the revisions it was read with (#2564): what the
/// export screen holds after the one read, and what its files state.
typedef ExportSourceBooks = ({
  List<Invoice> invoices,
  Map<String, InvoiceMatch> matches,
  Map<String, List<TaxPointPayment>> instalments,
  List<LedgerEntry> ledger,
  List<ExpenseRepartition> repartitions,
  List<BookProfile> bookProfiles,
  AccountingSourceRevisions revisions,

  /// The approved purchase documents of the same snapshot (#2587).
  List<SourcePurchase> purchases,
});

ExportYearBooks exportYearScope(
  int year, {
  required List<Invoice> invoices,
  required List<LedgerEntry> ledger,
  required List<ExpenseRepartition> repartitions,
}) => (
  invoices: [
    for (final i in invoices)
      if (i.issuedAt.year == year) i,
  ],
  ledger: [
    for (final e in ledger)
      if (e.on.year == year) e,
  ],
  repartitions: [
    for (final r in repartitions)
      if ((r.appliedAt ?? r.createdAt).year == year) r,
  ],
);
