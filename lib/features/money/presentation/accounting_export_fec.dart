// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The FEC of an accounting export run, the year archive's FEC and the
// books printed from the postings. The FEC is cut on the fiscal year of
// the book profile and named after its closing day; a year whose periods
// are not all closed is provisional, which the person is told and the
// archive's manifest states, never the file itself.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/features/enabled_feature_keys.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/time/date_text.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/app_snack.dart';
import '../application/generic_journal_export.dart';
import '../domain/accounting_format.dart';
import '../domain/archive_bundle.dart';
import '../domain/archive_fec.dart';
import '../domain/book_period.dart';
import '../domain/fec.dart';
import '../domain/fec_import_contract.dart';
import '../domain/fiscal_year.dart';
import '../providers/book_period_providers.dart';
import 'accounting_export_journal.dart';
import 'book_report_actions.dart';

/// Who the FEC is for: the space, the issuer's legal id, and whether the
/// space's books are a development copy.
typedef FecExportScope = ({
  String workspaceId,
  String legalId,
  bool development,
});

/// The formats of [country] the space may choose: the books printed from
/// the postings only where the space keeps a book.
List<AccountingFormat> exportFormatsOf(WidgetRef ref, String country) {
  final book = featureOn(
    ref.read(enabledFeatureKeysProvider),
    accountingBookKey,
    byDefault: false,
  );
  return [
    for (final f in formatsFor(country))
      if (book || !bookReportFormats.contains(f.id)) f,
  ];
}

/// The FEC and the books of one export run, for [scope]: the posted FEC
/// saved for its fiscal year, the year archive's FEC, the book reports.
class FecExportActions {
  const FecExportActions(this.context, this.ref, this.scope);

  final BuildContext context;
  final WidgetRef ref;
  final FecExportScope scope;

  /// The periods and the export log, or none when they cannot be read: the
  /// year then counts as open, which never makes a FEC final by mistake.
  Future<BookPeriodsOverview> _periods() async {
    try {
      return await ref.read(bookPeriodsProvider(scope.workspaceId).future);
    } on Exception catch (e, st) {
      TraceLogger.instance.warn('money', 'book periods unreadable: $e\n$st');
      return const BookPeriodsOverview();
    }
  }

  /// The FEC of the postings [posted]: refused with its reason, or saved
  /// through [save] under `<SIREN>FEC<closing>.txt` for its fiscal year;
  /// the person is told when that year is still open.
  Future<void> exportPosted(
    GenericJournal posted, {
    required Future<void> Function(
      String content,
      String fileName,
      FiscalYear year,
    )
    save,
  }) async {
    final year = posted is JournalPosted ? posted.year : null;
    await exportGenericJournal(
      context,
      () async => postedFecFileOf(posted),
      save: (content) async {
        final period = year!;
        await save(
          content,
          fecFileName(scope.legalId, period.to, development: scope.development),
          period,
        );
        final periods = await _periods();
        if (!context.mounted || fiscalYearClosed(periods, period)) return;
        AppSnack.info(context, context.l10n.fecProvisional);
      },
    );
  }

  /// The year's FEC and its period: the posted one when [posted] holds the
  /// postings, else the one [documents] writes for the calendar [year];
  /// null when the posted one was refused (the person was told why).
  Future<({String fec, FiscalYear period, Set<String> thirdParties})?> _yearFec(
    GenericJournal? posted,
    int year,
    YearDocumentFec documents,
  ) async {
    if (posted case final JournalPosted books) {
      final written = postedFecOf(books);
      if (written is JournalFile) {
        return (
          fec: written.content,
          period: books.year,
          thirdParties: thirdPartyAccountsOf(books),
        );
      }
      await exportGenericJournal(
        context,
        () async => written,
        save: (_) async {},
      );
      return null;
    }
    return (
      fec: documents.fec(),
      period: FiscalYear.calendar(year),
      thirdParties: documents.thirdParties,
    );
  }

  /// Adds the year's FEC to the archive [files] of a space in [country]
  /// (only France's archive carries one). A closed year's FEC is final,
  /// logged once, and must match what was logged; false when the archive
  /// must not be made (the person was told why).
  Future<bool> addYearFec(
    Map<String, List<int>> files, {
    required String country,
    required GenericJournal? posted,
    required int year,
    required YearDocumentFec documents,
  }) async {
    if (!archiveCarriesFec(country)) return true;
    final source = await _yearFec(posted, year, documents);
    if (source == null) return false;
    final (:fec, :period, :thirdParties) = source;
    final periods = await _periods();
    final plan = archiveFecPlan(
      fec: fec,
      fileName: fecFileName(
        scope.legalId,
        period.to,
        development: scope.development,
      ),
      year: period,
      closed: fiscalYearClosed(periods, period),
      exports: periods.exports,
      contract: checkFecImportContract(
        textBytes(fec),
        year: period,
        thirdPartyAccounts: thirdParties,
      ),
    );
    if (!context.mounted) return false;
    switch (plan) {
      case ArchiveFecChanged(:final logged):
        AppSnack.error(
          context,
          context.l10n.fecArchiveChanged(isoDay(logged.exportedAt)),
        );
        return false;
      case ArchiveFecWrite(:final members, :final logNow):
        addArchiveFec(files, country, members);
        if (logNow) {
          await ref
              .read(bookPeriodCommandProvider)
              .logExport(
                scope.workspaceId,
                formatId: archiveFecFormatId,
                year: year,
                content: fec,
                documents: 0,
                period: period,
              );
        }
        return true;
    }
  }

  /// The book report [kindId] of the postings [posted], headed by
  /// [letterhead] (the space's name, address and legal mentions), or why
  /// there is none.
  Future<void> bookReport(
    String kindId,
    GenericJournal? posted, {
    required Map<String, Object?> letterhead,
  }) async {
    if (posted case final JournalPosted books) {
      return BookReportPrint(
        context,
        ref,
      ).show(kindId: kindId, books: books, letterhead: letterhead);
    }
    await exportGenericJournal(
      context,
      () async => posted ?? const JournalNeedsLocalBook(),
      save: (_) async {},
    );
  }
}

/// The FEC an archive writes from the documents when no book is kept, and
/// the accounts its third-party lines are booked on.
typedef YearDocumentFec = ({String Function() fec, Set<String> thirdParties});
