// SPDX-License-Identifier: AGPL-3.0-or-later
import '../domain/accounting_source_queries.dart';
import '../domain/accounting_source_snapshot.dart';
import '../domain/export_year.dart';
import '../domain/invoice.dart';

/// The books of one fiscal year as the accounting export holds them: the
/// ledger and repartitions come from ONE server response for the year
/// (#2365, `accounting_source_snapshot_v1`), cut on the workspace's own
/// calendar, so a 2026 file carries no 2024 expense and no row from a
/// second read. [loaded] is the invoice list the person exports from; the
/// source must agree with it, otherwise the export stops
/// ([AccountingSourceException]) instead of mixing two moments.
Future<ExportYearBooks> exportYearBooks(
  AccountingSourceQueries source,
  String workspaceId,
  int year,
  List<Invoice> invoices, {
  required List<Invoice> loaded,
}) async {
  final books = await source.fetchAccountingSource(
    workspaceId: workspaceId,
    year: year,
  );
  books.requireInvoicesHeld([
    for (final i in loaded) (id: i.id, number: i.number, totalCents: i.totalCents),
  ]);
  // The invoices are the person's own list, cut here; the ledger and the
  // repartitions are already cut by the server on the workspace calendar and
  // are not cut a second time on the device's.
  final cut = exportYearScope(
    year,
    invoices: invoices,
    ledger: const [],
    repartitions: const [],
  );
  return (
    invoices: cut.invoices,
    ledger: books.ledger,
    repartitions: books.repartitions,
  );
}
