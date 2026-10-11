// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/i18n/currencies.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/accountant_handoff.dart';

String _amount(int minor, String currency) =>
    '${Currencies.toMajor(minor, currency).toStringAsFixed(Currencies.minorDigits(currency))} $currency';

String _handoffFindingLabel(AppLocalizations l10n, HandoffFinding f) =>
    switch (f.kind) {
      HandoffFindingKind.missingCurrency =>
        l10n.handoffMissingCurrency(f.subject),
      HandoffFindingKind.duplicateDocument =>
        l10n.handoffDuplicate(f.subject),
      HandoffFindingKind.orphanMatch =>
        l10n.handoffOrphanMatch(f.subject),
      HandoffFindingKind.rowCountMismatch =>
        l10n.handoffRowMismatch(f.subject),
      HandoffFindingKind.overpaid =>
        l10n.handoffOverpaid(f.subject),
      HandoffFindingKind.unsupportedCurrency =>
        l10n.handoffUnsupportedCurrency(f.subject),
      HandoffFindingKind.amountOutOfRange =>
        l10n.handoffAmountOutOfRange(f.subject),
    };

/// #1640 — before the accountant CSV is saved: what it holds, what it
/// left out, its totals per currency, and anything in the source that
/// disagrees. A blocking finding keeps Save disabled; nothing is
/// repaired here, only shown. True when the owner chose to save.
Future<bool> showAccountantHandoffPreflight(
  BuildContext context,
  AccountantHandoff report,
) async {
  final l10n = context.l10n;
  final textTheme = Theme.of(context).textTheme;
  final lines = <Widget>[
    Text(
      l10n.handoffIncluded('${report.included}'),
      key: const ValueKey('handoff-included'),
    ),
    for (final e in report.excluded.entries)
      Text(
        l10n.handoffExcludedSettlements('${e.value}'),
        key: ValueKey('handoff-excluded-${e.key}'),
      ),
    const SizedBox(height: AppSpacing.sm),
    for (final c in report.totals.entries) ...[
      Text(c.key, style: textTheme.titleSmall),
      for (final l in c.value.entries)
        Text(
          key: ValueKey('handoff-total-${c.key}-${l.key}'),
          '${l.key == 'voided' ? (l10n.handoffVoided) : (l10n.handoffIssued)}: '
          '${l.value.count} · ${_amount(l.value.grossMinor, c.key)}',
        ),
      if (report.payments[c.key] case final p?)
        Text(
          key: ValueKey('handoff-payments-${c.key}'),
          l10n.handoffPayments(
                _amount(p.confirmedMinor, c.key),
                _amount(p.pendingMinor, c.key),
              ),
        ),
    ],
    if (report.findings.isNotEmpty) ...[
      const SizedBox(height: AppSpacing.sm),
      for (final f in report.findings)
        ListTile(
          key: ValueKey('handoff-finding-${f.kind.name}-${f.subject}'),
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(f.blocking ? Icons.block : Icons.info_outline),
          title: Text(_handoffFindingLabel(l10n, f)),
        ),
    ],
    if (!report.clean)
      Text(
        l10n.handoffBlocked,
        key: const ValueKey('handoff-blocked'),
        style: textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.error,
        ),
      ),
  ];
  final save = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      key: const ValueKey('handoff-preflight'),
      title: Text(l10n.handoffTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: lines,
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('accountant-handoff-preflight-cancel'),
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('handoff-save'),
          onPressed: report.clean ? () => Navigator.pop(context, true) : null,
          child: Text(l10n.handoffSave),
        ),
      ],
    ),
  );
  return save ?? false;
}
