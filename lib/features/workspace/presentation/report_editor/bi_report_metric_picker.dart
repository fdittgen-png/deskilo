// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The figures a visual may be bound to: the registered modules this reader
// may read now, each with its unit, date basis and coverage, so the person
// sees what a figure is before choosing it. Nothing else can be bound: no
// formula, no field outside the registry.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/bi_modules.dart';
import '../../providers/workspace_providers.dart';
import '../widgets/bi_module_section.dart' show biModuleViews;
import 'bi_report_labels.dart';

/// The modules this reader may bind now, in registry order.
List<BiModule> biBindableModules(WidgetRef ref) => [
  for (final m in visibleBiModules(
    ref.read(enabledFeaturesSyncProvider),
    ref.read(myPermissionsProvider),
  ))
    if (biModuleViews.containsKey(m.id)) m,
];

/// "Percentage · reservation time · recorded history".
String biFigureFacts(AppLocalizations l10n, BiModule module) =>
    l10n.biEditorSourceNote(
      biUnitLabel(l10n, module.metric.unit),
      biDateBasisLabel(l10n, module.metric.dateBasis),
      biCoverageLabel(l10n, module.metric.coverage),
    );

/// Asks which of [modules] to bind; null when the person closes the list.
Future<String?> pickBiMetric(BuildContext context, List<BiModule> modules) {
  return showAppSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final l10n = context.l10n;
      return SafeArea(
        child: ListView(
          key: const ValueKey('bi-metric-picker'),
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          children: [
            Padding(
              padding: AppSpacing.gutterH,
              child: Text(
                l10n.biEditorChooseFigure,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final m in modules)
              ListTile(
                key: ValueKey('bi-metric-${m.id}'),
                title: Text(biModuleViews[m.id]!.title(l10n)),
                subtitle: Text(biFigureFacts(l10n, m)),
                onTap: () => Navigator.of(context).pop(m.id),
              ),
          ],
        ),
      );
    },
  );
}
