// SPDX-License-Identifier: AGPL-3.0-or-later
import 'expense_repartition.dart';
import 'invoice.dart';
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
