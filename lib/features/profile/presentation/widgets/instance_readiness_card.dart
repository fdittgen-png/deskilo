// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

import '../../../../core/instance/instance_readiness.dart';
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

  static String title(AppLocalizations? l10n, InstanceReadiness r) =>
      switch (r.verdict) {
        InstanceReadinessVerdict.install =>
          l10n?.instanceReadyInstall ?? 'The project is empty: everything will be installed.',
        InstanceReadinessVerdict.resume => l10n?.instanceReadyResume(r.pending) ??
            'A DesKilo install stopped part-way: ${r.pending} migrations remain and only those will run.',
        InstanceReadinessVerdict.upgrade =>
          l10n?.instanceReadyUpgrade(r.marker ?? 0, r.pending) ??
              'DesKilo version ${r.marker} is installed: only the ${r.pending} missing migrations will run.',
        InstanceReadinessVerdict.current => l10n?.instanceReadyCurrent(r.marker ?? 0) ??
            'DesKilo version ${r.marker} is installed and current: the schema needs nothing.',
        InstanceReadinessVerdict.needsAttention =>
          l10n?.instanceReadyAttention ?? 'This project needs attention — nothing was installed.',
      };

  static String? detail(AppLocalizations? l10n, InstanceReadiness r) =>
      switch (r.attention) {
        null => null,
        InstanceAttention.notHealthy => l10n?.instanceAttentionNotHealthy ??
            'Supabase does not report the project as healthy. Wait until it is, or restore it in the dashboard.',
        InstanceAttention.postgresVersion =>
          l10n?.instanceAttentionPostgres(r.postgresMajor ?? 0, supportedPostgresMajor) ??
              'It runs Postgres ${r.postgresMajor}; DesKilo is built for Postgres $supportedPostgresMajor.',
        InstanceAttention.foreignTables =>
          l10n?.instanceAttentionForeign(r.foreignTables.join(', ')) ??
              'Its public schema holds tables DesKilo does not create (${r.foreignTables.join(', ')}). Installing there is refused; use an empty project.',
        InstanceAttention.unrecorded => l10n?.instanceAttentionUnrecorded ??
            'DesKilo tables are there but no migration was recorded. Record what it has with `dart run tool/instance.dart record` first.',
        InstanceAttention.otherTooling => l10n?.instanceAttentionOtherTooling ??
            'Its migrations were recorded by other tooling, so where DesKilo would resume cannot be read. Use an empty project.',
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
                  child: Text(l10n?.instanceChooseAnother ?? 'Choose another project'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
