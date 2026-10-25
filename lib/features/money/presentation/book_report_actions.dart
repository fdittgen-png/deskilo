// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2376 — the book reports as user actions: the general ledger, the trial
// balance and the journals of the posted year, printed through the
// workspace template like every document (quick view / save / share).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/money_format.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/time/clock.dart';
import '../../../core/time/date_text.dart';
import '../../../core/ui/app_snack.dart';
import '../../../l10n/app_localizations.dart';
import '../application/generic_journal_export.dart';
import '../domain/book_reports.dart';
import '../domain/report_kind.dart';
import 'invoice_documents.dart';
import 'report_actions.dart';
import 'report_kind_labels.dart';
import 'report_layout_actions.dart';

/// The words of the book reports in [l10n].
@visibleForTesting
BookReportWords bookReportWordsOf(AppLocalizations l10n) => BookReportWords(
  total: l10n.bookReportTotal,
  grandTotal: l10n.bookReportGrandTotal,
  auxiliary: l10n.bookReportAuxiliary,
  summary: l10n.bookReportSummary,
  debitSide: l10n.bookReportDebitSide,
  creditSide: l10n.bookReportCreditSide,
  sales: l10n.bookReportJournalSales,
  bank: l10n.bookReportJournalBank,
  purchases: l10n.bookReportJournalPurchases,
  other: l10n.bookReportJournalOther,
);

/// Prints the books of an export run (#2376).
class BookReportPrint {
  const BookReportPrint(this.context, this.ref);

  final BuildContext context;
  final WidgetRef ref;

  /// The report [kindId] (`general_ledger`, `trial_balance`, `journals`) of
  /// [books] under [letterhead] (the space's name, address, currency and
  /// legal mentions, from the export run): quick view, save or share. A
  /// document in another currency than the book's, with no recorded rate,
  /// stops the report and is named.
  Future<void> show({
    required String kindId,
    required JournalPosted books,
    required Map<String, Object?> letterhead,
  }) async {
    final l10n = context.l10n;
    final ledger = BookLedger(
      postings: books.postings,
      year: books.year,
      accountNames: books.accountNames,
      parties: books.parties,
      functionalCurrency: books.functionalCurrency,
    );
    if (ledger.unconverted.isNotEmpty) {
      AppSnack.error(
        context,
        l10n.bookReportMissingRate(ledger.unconverted.join(', ')),
      );
      return;
    }
    final locale = Localizations.maybeLocaleOf(context)?.toString();
    final money = moneyFormat(
      books.functionalCurrency ?? letterhead['currency'] as String?,
      locale: locale,
    );
    final dateFormat = DateFormat.yMMMd(locale);
    final data = bookReportData(kindId, ledger, (
      money: money.formatMinor,
      date: dateFormat.format,
    ), words: bookReportWordsOf(l10n));
    final kind = reportKindById(kindId);
    if (data == null || kind == null) return;
    final full = <String, Object?>{
      ...letterhead,
      'issued': dateFormat.format(ref.read(clockProvider).now()),
      ...data,
    };
    final rendered = renderLetterDoc(context, ref, docId: kindId, data: full);
    final title = reportKindLabel(l10n, kind);
    final stem =
        '${kindId.replaceAll('_', '-')}-${ymd(books.year.from)}-${ymd(books.year.to)}';
    await runReportActions(
      context,
      ref,
      keyPrefix: 'book-report-$kindId',
      logMessage: 'book report pdf failed',
      render: () => rendered,
      buildPdf: () async {
        final pdf = await letterDocPdf(
          context,
          ref,
          report: rendered,
          title: title,
          layoutXml: letterLayoutXml(ref, docId: kindId),
          data: full,
        );
        return (bytes: pdf.bytes, fileName: '$stem.pdf');
      },
    );
  }
}
