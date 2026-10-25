// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2365 — everything one accounting export reads, read once. The books of
// the year are ONE `accounting_source_snapshot_v1` response: the ledger,
// the repartitions, the payment matches and instalments, the book profiles
// and the revisions, all of one statement. A posted format of an issuer
// keeping a local book then reads its postings once (`compute_postings`).
// No format reads anything else for the period: what the file says, it
// says about one moment.
import '../../../core/trace/trace_logger.dart';
import '../domain/accounting_format.dart';
import '../domain/accounting_source_queries.dart';
import '../domain/accounting_source_snapshot.dart';
import '../domain/accounting_view.dart';
import '../domain/archive_bundle.dart';
import '../domain/export_year.dart';
import '../domain/invoice.dart';
import 'generic_journal_export.dart';

/// The books of one fiscal year as the accounting export holds them: ONE
/// server response for the year, cut on the workspace's own calendar, so a
/// 2026 file carries no 2024 expense and no row from a second read. The
/// payment state of each invoice is the snapshot's, settlements made
/// transparent (#831). [loaded] is the invoice list the person exports
/// from; the source must agree with it, otherwise the export stops (null)
/// instead of mixing two moments, and the caller says so to the person.
Future<ExportSourceBooks?> exportYearBooks(
  AccountingSourceQueries source,
  String workspaceId,
  int year,
  List<Invoice> invoices, {
  required List<Invoice> loaded,
}) async {
  final AccountingSourceSnapshot books;
  try {
    books =
        (await source.fetchAccountingSource(
          workspaceId: workspaceId,
          year: year,
        ))..requireInvoicesHeld([
          for (final i in loaded)
            (id: i.id, number: i.number, totalCents: i.totalCents),
        ]);
  } on AccountingSourceException catch (e, st) {
    TraceLogger.instance.warn('money', 'accounting source refused: $e\n$st');
    return null;
  }
  final view = accountingView(invoices, books.matches);
  // The invoices are the person's own list, cut here; the ledger and the
  // repartitions are already cut by the server on the workspace calendar and
  // are not cut a second time on the device's.
  final cut = exportYearScope(
    year,
    invoices: view.invoices,
    ledger: const [],
    repartitions: const [],
  );
  return (
    invoices: cut.invoices,
    matches: view.matches,
    instalments: books.instalments,
    ledger: books.ledger,
    repartitions: books.repartitions,
    bookProfiles: books.bookProfiles,
    revisions: books.revisions,
  );
}

/// What one export run holds: the year's [books] and, for a posted format,
/// its [posted] journal (null for a format written from the documents).
typedef AccountingExportInput = ({
  ExportSourceBooks books,
  GenericJournal? posted,
});

/// The formats written from the posting engine when the issuer keeps a
/// local book (the archive for its FEC); the generic journal has no other
/// source.
const Set<String> _postedWhenLocalBook = {
  'fec',
  'saft',
  'bundle',
  ...bookReportFormats,
};

/// The posted formats that name the accounts and the parties: the FEC,
/// and #2376 the books printed from the postings.
const Set<String> _postedFec = {'fec', 'bundle', ...bookReportFormats};
const String _postedOnlyFormat = 'generic_journal_csv';

/// #2376 — the day of the latest document the person exports, on the same
/// clock the export year is taken from: the posted formats read the fiscal
/// year that holds it.
DateTime? _latestDay(List<Invoice> invoices) {
  if (invoices.isEmpty) return null;
  final last = invoices
      .map((i) => i.issuedAt)
      .reduce((a, b) => a.isAfter(b) ? a : b);
  return DateTime(last.year, last.month, last.day);
}

class AccountingExportSource {
  const AccountingExportSource(this._source, this._journal);

  final AccountingSourceQueries _source;

  /// The posting reader, made only when a posted format asks for it.
  final GenericJournalExport Function() _journal;

  /// The input of [formatId]'s export of [year] from [invoices] (the list
  /// the person holds) in a workspace of [country]: the one snapshot, then
  /// for a posted format the one postings read. Null when the source was
  /// refused.
  Future<AccountingExportInput?> read({
    required String formatId,
    required String workspaceId,
    required String country,
    required int year,
    required List<Invoice> invoices,
  }) async {
    final books = await exportYearBooks(
      _source,
      workspaceId,
      year,
      invoices,
      loaded: invoices,
    );
    if (books == null) return null;
    final posted =
        formatId == _postedOnlyFormat ||
        (_postedWhenLocalBook.contains(formatId) &&
            (formatId != 'bundle' || archiveCarriesFec(country)) &&
            localBookOf(books.bookProfiles, year) != null);
    return (
      books: books,
      posted: posted
          ? await _journal().read(
              workspaceId,
              books.bookProfiles,
              year,
              named: _postedFec.contains(formatId),
              asOf: _latestDay(invoices),
            )
          : null,
    );
  }
}
