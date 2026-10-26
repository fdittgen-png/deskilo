// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2370 / #2365 — the generic journal export's words: the file is saved,
// or the person is told why there is none (no local book, or the roles to
// map first). The decision is `application/generic_journal_export.dart`.
import 'package:flutter/material.dart';

import '../../../core/features/enabled_feature_keys.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/app_snack.dart';
import '../application/generic_journal_export.dart';
import '../domain/fec_postings.dart';
import '../providers/accounting_connection_providers.dart';
import 'accounting_export_run.dart';

export '../application/generic_journal_export.dart'
    show
        GenericJournal,
        JournalBlocked,
        JournalNeedsRates,
        JournalOpeningRefused,
        JournalPosted,
        JournalSafTRefused,
        journalCsvOf,
        writtenWith;

/// Builds a posted file through [build] (the generic journal, or #2365 the
/// FEC of a local book) and hands it to [save].
Future<void> exportGenericJournal(
  BuildContext context,
  Future<GenericJournal> Function() build, {
  required Future<void> Function(String content) save,
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
    case JournalNeedsLocalBook():
      AppSnack.error(context, l10n.journalNeedsLocalBook);
    case JournalBlocked(:final roles):
      AppSnack.error(context, l10n.journalBlocked(roles.join(', ')));
    case JournalNeedsRates(:final documents):
      AppSnack.error(context, l10n.journalNeedsRates(documents.join(', ')));
    case JournalRefused(:final blockers):
      String named(FecBlock block) => [
        for (final b in blockers)
          if (b.block == block) b.subject,
      ].join(', ');
      AppSnack.error(
        context,
        blockers.any((b) => b.block == FecBlock.partyCode)
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
          gaps.map((g) => l10n.saftGap(g.kind.name, g.subject)).join('; '),
        ),
      );
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
