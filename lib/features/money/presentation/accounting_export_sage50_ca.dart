// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2373 -- the Sage 50 Canada general-journal text file of one accounting
// export run: the local book's postings of the fiscal year (the run's one
// postings read), the tax lines split into GST / HST / QST by the tax
// reference.
import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart';

import '../application/generic_journal_export.dart';
import '../domain/sage50_ca_journal.dart';
import 'accounting_export_journal.dart';
import 'accounting_export_run.dart';
import 'posting_kind_labels.dart';

extension Sage50CaAccountingExports on AccountingExportRun {
  /// The journal file, saved and logged under [stem].
  Future<void> sage50CaJournalExport({required String stem}) async {
    await exportGenericJournal(
      context,
      () async {
        final read = posted ?? const JournalNeedsLocalBook();
        if (read is! JournalPosted) return read;
        final result = buildSage50CaJournal(
          read.postings,
          comment: (p) => '${p.documentNumber} ${postingKindLabel(l10n, p.kind)}',
          split: sage50CaTaxSplit(taxReference, country: country),
        );
        return switch (result) {
          Sage50CaFile(:final content) => JournalFile(content),
          Sage50CaRefused(:final sourceTooLong, :final unusableAccounts) =>
            JournalInterchangeRefused([
              for (final n in sourceTooLong)
                InterchangeProblem(InterchangeBlock.sourceTooLong, n),
              for (final a in unusableAccounts)
                InterchangeProblem(InterchangeBlock.unusableAccount, a),
            ]),
        };
      },
      save: (content) => save(content, named(stem)),
    );
  }
}
