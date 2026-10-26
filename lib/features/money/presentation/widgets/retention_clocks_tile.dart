// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/settings/setting_defaults.g.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/vat/retention.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/providers/settings_providers.dart';
import '../../../workspace/providers/workspace_providers.dart';
import 'retention_holds_section.dart';

/// The name of the document class [docClass] a retention rule is kept for.
String retentionClassName(AppLocalizations l10n, String docClass) => switch (docClass) {
  'invoice' => l10n.retentionClassInvoice,
  'books' => l10n.retentionClassBooks,
  'correspondence' => l10n.retentionClassCorrespondence,
  _ => l10n.retentionClassVoucher,
};

/// How long [r] keeps a record and from when, in words.
String retentionRuleText(AppLocalizations l10n, RetentionRule r) => r.bySetting
    ? l10n.retentionExtendedBySetting(r.years)
    : r.from == 'document_date'
    ? l10n.retentionFromDocument(r.years)
    : l10n.retentionFromYearEnd(r.years);

/// #2571 -- how long this space's country makes it keep each kind of record
/// (the `retention` rows of the tax reference, extended by a US space's own
/// longer period), with the statute and whether a person has confirmed the
/// rule, and the legal holds that keep records past every clock. The rules
/// are reference data; only the holds are changed here.
class RetentionClocksTile extends ConsumerWidget {
  const RetentionClocksTile({required this.country, super.key});

  /// The workspace's country code; null while it is not known.
  final String? country;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final country = this.country;
    if (country == null) return const SizedBox.shrink();
    final workspaceId = ref.watch(currentWorkspaceProvider).value?.id;
    final usYears = workspaceId == null || !retentionExtendsBySetting(country)
        ? SettingDefaults.retentionUsYears
        : ref.watch(settingsSetProvider(workspaceId)).value?.read<int>('retention.us_years') ??
              SettingDefaults.retentionUsYears;
    final rules = retentionRules(country, usYears: usYears);
    if (rules.isEmpty) return const SizedBox.shrink();
    return ListTile(
      key: const ValueKey('retention-clocks'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.history_toggle_off_outlined),
      title: Text(l10n.retentionTitle),
      subtitle: Text(
        [for (final r in rules) '${retentionClassName(l10n, r.docClass)}: ${r.years}'].join(' · '),
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
                    '${retentionClassName(l10n, r.docClass)} — ${retentionRuleText(l10n, r)}',
                    key: ValueKey('retention-rule-${r.docClass}'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    r.confirmed ? r.source : '${r.source} (${l10n.retentionUnconfirmed})',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (workspaceId != null) const RetentionHoldsSection(),
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
