// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/workspace_feature.dart';
import '../../domain/workspace_process.dart';
import '../feature_copy.dart';
import '../feature_names.dart';
import '../process_names.dart';

/// #1328 — one capability, explained: where it sits, what it provides,
/// what it requires, what uses it, and why it is on or off right now.
///
/// Read-only. Every relationship shown is read from the registry
/// (`requirementChain`, `dependentFeatures`, the process registry) at
/// build time: remove an edge from the manifest and this sheet stops
/// showing it. Nothing here writes; "Change it" hands the feature to the
/// switches view, which is the write path for one flag.
///
/// It says what is true and nothing more: *switched on*, *needed by X*,
/// *held back: needs Y*. "Selected through process P" is not stored, so
/// it is not claimed.
Future<void> showFeatureDetailSheet(
  BuildContext context, {
  required WorkspaceFeature feature,
  required Set<WorkspaceFeature> raw,
  required ValueChanged<WorkspaceFeature> onChange,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => FeatureDetailSheet(
        feature: feature,
        raw: raw,
        onChange: (f) {
          Navigator.of(sheetContext).pop();
          onChange(f);
        },
      ),
    );

class FeatureDetailSheet extends StatelessWidget {
  const FeatureDetailSheet({
    super.key,
    required this.feature,
    required this.raw,
    required this.onChange,
  });

  final WorkspaceFeature feature;

  /// The RAW stored set: a child stored on under an off parent is
  /// explained as held back, not hidden.
  final Set<WorkspaceFeature> raw;
  final ValueChanged<WorkspaceFeature> onChange;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final effective = effectiveFeatures(raw);
    final requires = requirementChain(feature);
    final usedBy = [
      for (final f in dependentFeatures(feature))
        if (!internalCapabilities.containsKey(f)) f,
    ];
    final home = homeProcessOf(feature);
    final path = [
      if (home != null) processLabel(l10n, home),
      for (final process in workspaceProcesses)
        for (final sub in process.subprocesses)
          if (sub.capabilities.contains(feature)) processLabel(l10n, sub.key),
    ].join(' › ');

    return SafeArea(
      child: SingleChildScrollView(
        padding: AppSpacing.gutterAll,
        child: Column(
          key: ValueKey('feature-detail-${feature.name}'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(featureName(l10n, feature), style: theme.textTheme.titleMedium),
            if (path.isNotEmpty)
              Text(path,
                  key: const ValueKey('feature-detail-path'),
                  style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            _WhyLine(feature: feature, raw: raw, effective: effective),
            const SizedBox(height: AppSpacing.sm),
            _Heading(l10n?.featureDetailProvides ?? 'Provides'),
            Text(featureDescription(l10n, feature)),
            if (feature == WorkspaceFeature.adminInvoicing)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  l10n?.featureDetailGrantsPermission(
                        l10n.permIssueInvoices,
                      ) ??
                      'Grants administrators the permission '
                          '"Issue invoices & match payments".',
                  key: const ValueKey('feature-detail-permission'),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            _Relation(
              keyName: 'requires',
              title: l10n?.featureDetailRequires ?? 'Requires',
              features: requires,
              home: home,
              mark: (f) => effective.contains(f)
                  ? Icons.check
                  : (raw.contains(f) ? Icons.pause_circle_outline : Icons.remove),
            ),
            _Relation(
              keyName: 'used-by',
              title: l10n?.featureDetailUsedBy ?? 'Used by',
              features: usedBy,
              home: home,
              mark: (f) => effective.contains(f)
                  ? Icons.check
                  : (raw.contains(f) ? Icons.pause_circle_outline : Icons.remove),
            ),
            ExpansionTile(
              key: const ValueKey('feature-detail-technical'),
              tilePadding: EdgeInsets.zero,
              title: Text(l10n?.featureDetailTechnical ?? 'Technical details'),
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n?.featureDetailKey ?? 'Technical key'),
                  subtitle: SelectableText(feature.dbKey,
                      key: const ValueKey('feature-detail-db-key'),
                      style: const TextStyle(fontFamily: 'monospace')),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              key: const ValueKey('feature-detail-change'),
              onPressed: () => onChange(feature),
              icon: const Icon(Icons.tune),
              label: Text(l10n?.featureDetailChange ?? 'Change it among the switches'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Why the capability is on or off right now — what is true, only.
class _WhyLine extends StatelessWidget {
  const _WhyLine({
    required this.feature,
    required this.raw,
    required this.effective,
  });

  final WorkspaceFeature feature;
  final Set<WorkspaceFeature> raw;
  final Set<WorkspaceFeature> effective;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final String text;
    final IconData icon;
    final String keyName;
    if (effective.contains(feature)) {
      final neededBy = [
        for (final f in dependentFeatures(feature))
          if (effective.contains(f) && !internalCapabilities.containsKey(f)) f,
      ];
      if (neededBy.isEmpty) {
        text = l10n?.featureDetailOn ?? 'Switched on.';
        keyName = 'on';
      } else {
        final names = neededBy.map((f) => featureName(l10n, f)).join(', ');
        text = l10n?.featureDetailOnNeededBy(names) ??
            'Switched on, and needed by $names.';
        keyName = 'on-needed';
      }
      icon = Icons.check_circle_outline;
    } else if (raw.contains(feature)) {
      final waiting = requirementChain(feature).firstWhere((p) => !raw.contains(p));
      text = l10n?.featureDetailHeldBack(featureName(l10n, waiting)) ??
          'Switched on, but held back: it needs ${featureName(l10n, waiting)}, which is off.';
      icon = Icons.pause_circle_outline;
      keyName = 'held-back';
    } else {
      text = l10n?.featureDetailOff ?? 'Switched off.';
      icon = Icons.radio_button_unchecked;
      keyName = 'off';
    }
    return Row(
      key: ValueKey('feature-detail-why-$keyName'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );
}

/// Requires / Used by: each related capability with its state mark, and
/// "in ‹process›" when it lives in another process — the cross-process
/// edge said in words, never in colour alone.
class _Relation extends StatelessWidget {
  const _Relation({
    required this.keyName,
    required this.title,
    required this.features,
    required this.home,
    required this.mark,
  });

  final String keyName;
  final String title;
  final List<WorkspaceFeature> features;
  final String? home;
  final IconData Function(WorkspaceFeature feature) mark;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      key: ValueKey('feature-detail-$keyName'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading(title),
        if (features.isEmpty)
          Text(l10n?.featureDetailNone ?? 'Nothing.',
              style: Theme.of(context).textTheme.bodySmall)
        else
          for (final f in features)
            ListTile(
              key: ValueKey('feature-detail-$keyName-${f.name}'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(mark(f), size: 18),
              title: Text(featureName(l10n, f)),
              subtitle: homeProcessOf(f) != null && homeProcessOf(f) != home
                  ? Text(l10n?.processInProcess(
                          processLabel(l10n, homeProcessOf(f)!)) ??
                      'in ${processLabel(l10n, homeProcessOf(f)!)}')
                  : null,
            ),
      ],
    );
  }
}
