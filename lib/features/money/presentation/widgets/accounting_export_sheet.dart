// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/accounting_capability.dart';
import '../../domain/accounting_format.dart';

/// Picks the accounting export (#669).
///
/// The sheet's real job is not choosing a file type. It is making sure
/// nobody sends an authority something the app never claimed: each row
/// states what its file IS — the tax office's own format, something an
/// accountant imports and reviews, or a declared subset — because the
/// person tapping is rarely the person who will be asked to defend it.
///
/// Ordered by the registry: the country's regulatory file first when
/// there is one. Someone under audit is looking for one specific thing
/// and should not have to read past three alternatives to find it.
Future<AccountingFormat?> showAccountingExportSheet(
  BuildContext context, {
  required List<AccountingFormat> formats,
}) async {
  if (formats.isEmpty) return null;
  final l10n = context.l10n;
  return showAppSheet<AccountingFormat>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Expanded(
                  child: Text(
                    l10n.invoiceExportChoose,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                // #1393 — what each format may CLAIM is the whole
                // question here, and the sheet lists eight of them
                // without room to say it.
                HelpDot(
                  l10n.helpTopicAccounting,
                  anchor: HelpAnchor.invoicingAccountingExport,
                ),
              ]),
              const SizedBox(height: AppSpacing.lg),
              for (final format in formats)
                _FormatTile(format: format, l10n: l10n),
            ],
          ),
        ),
      ),
    ),
  );
}

class _FormatTile extends StatelessWidget {
  const _FormatTile({required this.format, required this.l10n});

  final AccountingFormat format;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        key: ValueKey('accounting-export-${format.id}'),
        contentPadding: EdgeInsets.zero,
        leading: Icon(_icon),
        title: Text(_name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_claimText, style: Theme.of(context).textTheme.bodySmall),
            // The certification note is NOT folded into the claim line.
            // "This is Portugal's own format" and "this software is not
            // certified in Portugal" are both true, and an owner who
            // reads only the first has been misled by omission.
            if (capabilityOf(format)
                .obligations
                .contains(Obligation.completePostedBooks))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.exportNoCompleteBooks,
                  key: const ValueKey('accounting-export-incomplete-books'),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.error),
                ),
              ),
            if (format.uncertifiedSoftware)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.exportUncertifiedSoftware,
                  key: const ValueKey('accounting-export-uncertified'),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.error),
                ),
              ),
          ],
        ),
        onTap: () => Navigator.of(context).pop(format),
      ),
    );
  }

  IconData get _icon => switch (format.id) {
        'fec' || 'datev' || 'sage50' || 'ch_kmu' => Icons.table_chart_outlined,
        'saft' || 'saft_pt' => Icons.code_outlined,
        'audit_trail' => Icons.fact_check_outlined,
        'bundle' => Icons.archive_outlined,
        _ => Icons.description_outlined,
      };

  String get _name => switch (format.id) {
        'fec' => l10n.invoiceExportFec,
        'saft' => l10n.invoiceExportSafT,
        'saft_pt' => l10n.invoiceExportSafTPt,
        'datev' => l10n.invoiceExportDatev,
        'sage50' => l10n.invoiceExportSage,
        'ch_kmu' => l10n.invoiceExportSwissKmu,
        'accountant_csv' =>
          l10n.invoiceExportAccountantCsv,
        'generic_journal_csv' => l10n.invoiceExportGenericJournal,
        'audit_trail' => l10n.invoiceExportAuditTrail,
        'fr_ereporting' => l10n.invoiceExportFrEReporting,
        'bundle' => l10n.invoiceExportBundle,
        _ => format.id,
      };

  /// What the file claims. Deliberately blunt: this is the sentence that
  /// stops someone filing an accountant's working file as a tax return.
  String get _claimText => switch (format.claim) {
        FormatClaim.regulatory => l10n.exportClaimRegulatory,
        FormatClaim.exchange => l10n.exportClaimExchange,
        FormatClaim.subset => l10n.exportClaimSubset,
      };
}
