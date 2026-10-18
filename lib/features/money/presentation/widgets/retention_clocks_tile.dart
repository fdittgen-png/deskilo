// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/vat/retention.dart';
import '../../../../l10n/app_localizations.dart';

String _className(AppLocalizations l10n, String docClass) => switch (docClass) {
  'invoice' => l10n.retentionClassInvoice,
  'books' => l10n.retentionClassBooks,
  'correspondence' => l10n.retentionClassCorrespondence,
  _ => l10n.retentionClassVoucher,
};

String _ruleText(AppLocalizations l10n, RetentionRule r) => r.from == 'document_date'
    ? l10n.retentionFromDocument(r.years)
    : l10n.retentionFromYearEnd(r.years);

/// #2571 -- how long this space's country makes it keep each kind of record
/// (the `retention` rows of the tax reference), with the statute and whether
/// a person has confirmed the rule. Read-only: the rules are reference data.
class RetentionClocksTile extends StatelessWidget {
  const RetentionClocksTile({required this.country, super.key});

  /// The workspace's country code; null while it is not known.
  final String? country;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final country = this.country;
    if (country == null) return const SizedBox.shrink();
    final rules = retentionRules(country);
    if (rules.isEmpty) return const SizedBox.shrink();
    return ListTile(
      key: const ValueKey('retention-clocks'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.history_toggle_off_outlined),
      title: Text(l10n.retentionTitle),
      subtitle: Text(
        [for (final r in rules) '${_className(l10n, r.docClass)}: ${r.years}'].join(' · '),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          key: const ValueKey('retention-clocks-dialog'),
          title: Text(l10n.retentionTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.retentionHint(country.toUpperCase())),
                const SizedBox(height: AppSpacing.md),
                for (final r in rules) ...[
                  Text(
                    '${_className(l10n, r.docClass)} — ${_ruleText(l10n, r)}',
                    key: ValueKey('retention-rule-${r.docClass}'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    r.confirmed ? r.source : '${r.source} (${l10n.retentionUnconfirmed})',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              key: const ValueKey('retention-clocks-close'),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(MaterialLocalizations.of(context).closeButtonLabel),
            ),
          ],
        ),
      ),
    );
  }
}
