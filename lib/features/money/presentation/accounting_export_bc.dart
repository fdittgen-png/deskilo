// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2374 -- the Business Central General Journal workbook of one accounting
// export run: the local book's postings of the fiscal year (the run's one
// postings read), saved as a workbook and logged with its digest.
import '../application/generic_journal_export.dart';
import '../domain/bc_journal_xlsx.dart';
import '../providers/book_period_providers.dart';
import 'accounting_export_journal.dart';
import 'accounting_export_run.dart';
import 'invoice_pdf_actions.dart';
import 'posting_kind_labels.dart';

extension BcAccountingExports on AccountingExportRun {
  /// The journal workbook, saved and logged under [stem].
  Future<void> bcJournalExport({required String stem}) async {
    await exportGenericJournal(
      context,
      () async {
        final read = posted ?? const JournalNeedsLocalBook();
        if (read is! JournalPosted) return read;
        final result = buildBcJournalXlsx(
          read.postings,
          vatProductGroups: bcDefaultVatGroups(read.postings),
          description: (p) =>
              '${p.documentNumber} ${postingKindLabel(l10n, p.kind)}',
        );
        return switch (result) {
          BcJournalFile(:final bytes) => JournalBytes(bytes),
          BcJournalUnmapped(:final taxKeys) => throw StateError(
            'every rate group is mapped by default: $taxKeys',
          ),
        };
      },
      save: (_) async {},
      saveBytes: (bytes) async {
        final handedOut = await savePdfToDownloads(
          context,
          ref,
          bytes: bytes,
          fileName: named(stem),
        );
        // A download that did not happen is no access to the books.
        if (!handedOut) return;
        await ref
            .read(bookPeriodCommandProvider)
            .logExportBytes(
              workspace.id,
              formatId: format.id,
              year: year,
              bytes: bytes,
              rows: exported.length,
              documents: exported.length,
            );
      },
    );
  }
}
