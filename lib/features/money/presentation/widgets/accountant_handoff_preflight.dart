// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/i18n/currencies.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/accountant_handoff.dart';

String _amount(int minor, String currency) =>
    '${Currencies.toMajor(minor, currency).toStringAsFixed(Currencies.minorDigits(currency))} $currency';

String handoffFindingLabel(AppLocalizations? l10n, HandoffFinding f) =>
    switch (f.kind) {
      HandoffFindingKind.missingCurrency =>
        l10n?.handoffMissingCurrency(f.subject) ?? '${f.subject}: no currency',
      HandoffFindingKind.duplicateDocument =>
        l10n?.handoffDuplicate(f.subject) ??
            '${f.subject}: appears twice in the source',
      HandoffFindingKind.orphanMatch =>
        l10n?.handoffOrphanMatch(f.subject) ??
            'A payment (${f.subject}) belongs to no document of this export',
      HandoffFindingKind.rowCountMismatch =>
        l10n?.handoffRowMismatch(f.subject) ??
            'The file rows do not match the documents (${f.subject})',
      HandoffFindingKind.overpaid =>
        l10n?.handoffOverpaid(f.subject) ??
            '${f.subject}: paid more than it charges',
    };

/// #1640 — before the accountant CSV is saved: what it holds, what it
/// left out, its totals per currency, and anything in the source that
/// disagrees. A blocking finding keeps Save disabled; nothing is
/// repaired here, only shown. True when the owner chose to save.
Future<bool> showAccountantHandoffPreflight(
  BuildContext context,
  AccountantHandoff report,
) async {
  final l10n = AppLocalizations.of(context);
  final textTheme = Theme.of(context).textTheme;
  final lines = <Widget>[
    Text(
      l10n?.handoffIncluded('${report.included}') ??
          '${report.included} document(s) in the file',
      key: const ValueKey('handoff-included'),
    ),
    for (final e in report.excluded.entries)
      Text(
        l10n?.handoffExcludedSettlements('${e.value}') ??
            '${e.value} settlement summary(ies) left out: their invoices are already listed',
        key: ValueKey('handoff-excluded-${e.key}'),
      ),
    const SizedBox(height: AppSpacing.sm),
    for (final c in report.totals.entries) ...[
      Text(c.key, style: textTheme.titleSmall),
      for (final l in c.value.entries)
        Text(
          key: ValueKey('handoff-total-${c.key}-${l.key}'),
          '${l.key == 'voided' ? (l10n?.handoffVoided ?? 'Voided') : (l10n?.handoffIssued ?? 'Issued')}: '
          '${l.value.count} · ${_amount(l.value.grossMinor, c.key)}',
        ),
      if (report.payments[c.key] case final p?)
        Text(
          key: ValueKey('handoff-payments-${c.key}'),
          l10n?.handoffPayments(
                _amount(p.confirmedMinor, c.key),
                _amount(p.pendingMinor, c.key),
              ) ??
              'Paid: ${_amount(p.confirmedMinor, c.key)} confirmed, '
                  '${_amount(p.pendingMinor, c.key)} pending',
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
          title: Text(handoffFindingLabel(l10n, f)),
        ),
    ],
    if (!report.clean)
      Text(
        l10n?.handoffBlocked ??
            'This file cannot be handed over until the source is corrected.',
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
      title: Text(l10n?.handoffTitle ?? 'Before you save'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: lines,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n?.commonCancel ?? 'Cancel'),
        ),
        FilledButton(
          key: const ValueKey('handoff-save'),
          onPressed: report.clean ? () => Navigator.pop(context, true) : null,
          child: Text(l10n?.handoffSave ?? 'Save file and report'),
        ),
      ],
    ),
  );
  return save ?? false;
}
