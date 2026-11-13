// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2370 / #2365 — the generic journal export's words: the file is saved,
// or the person is told why there is none (no local book, or the roles to
// map first). The decision is `application/generic_journal_export.dart`.
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/features/enabled_feature_keys.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/app_snack.dart';
import '../application/generic_journal_export.dart';
import '../domain/fec_postings.dart';
import '../providers/accounting_connection_providers.dart';
import 'accounting_export_run.dart';
import 'saft_gap_text.dart';

export '../application/generic_journal_export.dart'
    show
        GenericJournal,
        JournalBlocked,
        JournalNeedsRates,
        JournalOpeningRefused,
        JournalPosted,
        JournalSafTRefused,
        JournalUnreadable,
        journalFileOf,
        writtenWith;

/// #3884 -- whether [read] says the books hold entries (or chart accounts)
/// this build cannot read; if so the person is told how many and nothing is
/// exported. For the exports that take the books as they are read (DATEV).
bool refuseUnreadableBooks(BuildContext context, GenericJournal? read) {
  if (read is! JournalUnreadable) return false;
  if (context.mounted) {
    AppSnack.error(context, context.l10n.journalUnreadableEntries(read.count));
  }
  return true;
}

/// Builds a posted file through [build] (the generic journal, or #2365 the
/// FEC of a local book) and hands it to [save].
Future<void> exportGenericJournal(
  BuildContext context,
  Future<GenericJournal> Function() build, {
  required Future<void> Function(String content) save,
  Future<void> Function(Uint8List bytes)? saveBytes,
}) async {
  GenericJournal? journal;
  final read = await runGuarded(
    context,
    domain: 'money',
    message: 'journal postings failed',
    action: () async => journal = await build(),
  );
  if (!read || !context.mounted) return;
  final l10n = context.l10n;
  switch (journal) {
    case JournalFile(:final content):
      await save(content);
    case JournalBytes(:final bytes):
      await saveBytes!(bytes);
    case JournalNeedsLocalBook():
      AppSnack.error(context, l10n.journalNeedsLocalBook);
    case JournalBlocked(:final roles):
      AppSnack.error(context, l10n.journalBlocked(roles.join(', ')));
    case JournalUnreadable(:final count):
      AppSnack.error(context, l10n.journalUnreadableEntries(count));
    case JournalNeedsRates(:final documents):
      AppSnack.error(context, l10n.journalNeedsRates(documents.join(', ')));
    case JournalRefused(:final blockers):
      String named(FecBlock block) => [
        for (final b in blockers)
          if (b.block == block) b.subject,
      ].join(', ');
      AppSnack.error(
        context,
        blockers.any((b) => b.block == FecBlock.currency)
            ? l10n.fecCurrencyRefused(named(FecBlock.currency))
            : blockers.any((b) => b.block == FecBlock.partyCode)
            ? l10n.journalFecPartyCode(named(FecBlock.partyCode))
            : l10n.journalFecMissingRate(named(FecBlock.missingRate)),
      );
    case JournalOpeningRefused(:final period, :final subjects):
      final day = MaterialLocalizations.of(context).formatMediumDate;
      AppSnack.error(
        context,
        l10n.journalOpeningRefused(
          day(period.from),
          day(period.to),
          subjects.join(', '),
        ),
      );
    case JournalSafTRefused(:final gaps):
      AppSnack.error(
        context,
        l10n.journalSafTRefused(
          gaps.map((g) => safTGapText(l10n, g)).join('; '),
        ),
      );
    case JournalSageRefused(:final blockers):
      AppSnack.error(
        context,
        l10n.journalSageRefused(
          blockers.map((b) => l10n.sageBlock(b.block.name, b.subject)).join('; '),
        ),
      );
    case JournalInterchangeRefused(:final problems):
      AppSnack.error(
        context,
        l10n.journalInterchangeRefused(
          problems
              .map((p) => l10n.interchangeBlock(p.block.name, p.subject))
              .join('; '),
        ),
      );
    case JournalTaxCodesMissing(:final keys):
      AppSnack.error(context, l10n.journalSwissTaxCodes(keys.join(', ')));
    case JournalContractBroken(:final report):
      AppSnack.error(
        context,
        l10n.fecContractFailed(report.failedRules.map((r) => r.name).join(', ')),
      );
    // A journal not yet written is not a file; never saved as one.
    case JournalPosted() || null:
      return;
  }
}

/// #2370 — the generic journal, saved and logged, and with the accounting
/// systems on, each document it carried recorded with its own digest: a
/// re-delivery of the same books changes nothing.
extension JournalDeliveries on AccountingExportRun {
  Future<void> saveJournal(String content) async {
    final exportId = await save(content, named('journal'));
    final journal = posted;
    final issuer = localBookOf(bookProfiles, year)?.issuerSiteId;
    if (exportId == null || journal is! JournalPosted || issuer == null) return;
    final on = featureOn(
      ref.read(enabledFeatureKeysProvider),
      accountingConnectorsKey,
      byDefault: false,
    );
    if (!on) return;
    final logged = await ref
        .read(accountingConnectionCommandProvider)
        .logJournalFile(
          workspace.id,
          bookExportId: exportId,
          targetId: format.id,
          issuerSiteId: issuer,
          postings: journal.postings,
        );
    if (logged == null || !context.mounted) return;
    AppSnack.info(
      context,
      context.l10n.acctJournalLogged(
        logged.created + logged.changed,
        logged.unchanged,
      ),
    );
  }
}
