// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/instance/instance_readiness.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';

/// #1308 S1 — what an existing project already holds, said before anything
/// is installed onto it. "Needs attention" names the reason and offers to
/// choose another project; the wizard runs nothing meanwhile.
class InstanceReadinessCard extends StatelessWidget {
  const InstanceReadinessCard({
    super.key,
    required this.readiness,
    required this.onChooseAnother,
  });

  final InstanceReadiness readiness;
  final VoidCallback onChooseAnother;

  static String title(AppLocalizations l10n, InstanceReadiness r) =>
      switch (r.verdict) {
        InstanceReadinessVerdict.install =>
          l10n.instanceReadyInstall,
        InstanceReadinessVerdict.resume => l10n.instanceReadyResume(r.pending),
        InstanceReadinessVerdict.upgrade =>
          l10n.instanceReadyUpgrade(r.marker ?? 0, r.pending),
        InstanceReadinessVerdict.current => l10n.instanceReadyCurrent(r.marker ?? 0),
        InstanceReadinessVerdict.needsAttention =>
          l10n.instanceReadyAttention,
      };

  static String? detail(AppLocalizations l10n, InstanceReadiness r) =>
      switch (r.attention) {
        null => null,
        InstanceAttention.notHealthy => l10n.instanceAttentionNotHealthy,
        InstanceAttention.postgresVersion =>
          l10n.instanceAttentionPostgres(r.postgresMajor ?? 0, supportedPostgresMajor),
        InstanceAttention.foreignTables =>
          l10n.instanceAttentionForeign(r.foreignTables.join(', ')),
        InstanceAttention.unrecorded => l10n.instanceAttentionUnrecorded,
        InstanceAttention.otherTooling => l10n.instanceAttentionOtherTooling,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = detail(l10n, readiness);
    return Card(
      key: ValueKey('instance-readiness-${readiness.verdict.name}'),
      color: readiness.blocks ? scheme.errorContainer : null,
      child: Padding(
        padding: AppSpacing.mdAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title(l10n, readiness),
                style: Theme.of(context).textTheme.titleSmall),
            if (text != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(text),
            ],
            if (readiness.blocks)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  key: const ValueKey('instance-choose-another'),
                  onPressed: onChooseAnother,
                  child: Text(l10n.instanceChooseAnother),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
