// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/widgets.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/app_snack.dart';
import '../domain/accounting_source_queries.dart';
import '../domain/accounting_source_snapshot.dart';
import '../domain/export_year.dart';
import '../domain/invoice.dart';

/// The books of one fiscal year as the accounting export holds them: the
/// ledger and repartitions come from ONE server response for the year
/// (#2365, `accounting_source_snapshot_v1`), cut on the workspace's own
/// calendar, so a 2026 file carries no 2024 expense and no row from a
/// second read. [loaded] is the invoice list the person exports from; the
/// source must agree with it, otherwise the export stops (null) instead of
/// mixing two moments, and the caller says so to the person.
@visibleForTesting
Future<ExportSourceBooks?> exportYearBooks(
  AccountingSourceQueries source,
  String workspaceId,
  int year,
  List<Invoice> invoices, {
  required List<Invoice> loaded,
}) async {
  final AccountingSourceSnapshot books;
  try {
    books = (await source.fetchAccountingSource(
      workspaceId: workspaceId,
      year: year,
    ))
      ..requireInvoicesHeld([
        for (final i in loaded)
          (id: i.id, number: i.number, totalCents: i.totalCents),
      ]);
  } on AccountingSourceException catch (e, st) {
    TraceLogger.instance.warn('money', 'accounting source refused: $e\n$st');
    return null;
  }
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
    bookProfiles: books.bookProfiles,
    revisions: books.revisions,
  );
}

/// [exportYearBooks] for the export screen: a refused source is said to the
/// person here, after the await, and nothing is exported.
Future<ExportSourceBooks?> exportYearBooksOrSay(
  BuildContext context,
  AccountingSourceQueries source,
  String workspaceId,
  int year,
  List<Invoice> invoices, {
  required List<Invoice> loaded,
}) async {
  final books = await exportYearBooks(
    source,
    workspaceId,
    year,
    invoices,
    loaded: loaded,
  );
  if (books == null && context.mounted) {
    AppSnack.error(context, context.l10n.accountingSourceRefused);
  }
  return books;
}

/// A development workspace's books are marked as such (#936).
void noteDevelopmentBooks(BuildContext context, {required bool development}) {
  if (!development) return;
  AppSnack.info(context, context.l10n.accountingExportDevelopment);
}
