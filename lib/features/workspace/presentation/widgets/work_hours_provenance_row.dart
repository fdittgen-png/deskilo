// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/work_hours_reset.dart';
import '../../domain/work_hours_provenance.dart';
import '../../providers/workspace_providers.dart';

/// #1307 S4 — says where the working day came from (*Product default*,
/// *From template «…»*, *Workspace setting*) and offers the way back.
///
/// Editing stays in the normal fields above: this row only names the origin
/// and resets. Resetting to the template writes the template's values
/// through the same keyed write as any edit; resetting to the product
/// default removes the keys.
class WorkHoursProvenanceRow extends ConsumerWidget {
  const WorkHoursProvenanceRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provenance = ref.watch(workHoursProvenanceProvider).value;
    if (provenance == null) return const SizedBox.shrink();
    final label = switch (provenance.origin) {
      WorkHoursOrigin.productDefault =>
        l10n?.provenanceProductDefault ?? 'Product default',
      WorkHoursOrigin.template => l10n?.provenanceFromTemplate(
              provenance.templateName ?? '') ??
          'From template «${provenance.templateName ?? ''}»',
      WorkHoursOrigin.workspace =>
        l10n?.provenanceWorkspaceSetting ?? 'Workspace setting',
    };
    return Padding(
      padding: AppSpacing.lgH,
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Chip(
            key: ValueKey('work-hours-provenance-${provenance.origin.name}'),
            avatar: Icon(switch (provenance.origin) {
              WorkHoursOrigin.productDefault => Icons.inventory_2_outlined,
              WorkHoursOrigin.template => Icons.grid_view_outlined,
              WorkHoursOrigin.workspace => Icons.edit_outlined,
            }, size: 18),
            label: Text(label),
          ),
          if (provenance.canResetToTemplate)
            TextButton(
              key: const ValueKey('work-hours-reset-template'),
              onPressed: () => _reset(context, ref, provenance, toTemplate: true),
              child: Text(l10n?.provenanceResetToTemplate ?? 'Reset to template'),
            ),
          if (provenance.canResetToDefault)
            TextButton(
              key: const ValueKey('work-hours-reset-default'),
              onPressed: () => _reset(context, ref, provenance, toTemplate: false),
              child: Text(
                  l10n?.provenanceResetToDefault ?? 'Reset to product default'),
            ),
        ],
      ),
    );
  }

  Future<void> _reset(BuildContext context, WidgetRef ref,
      WorkHoursProvenance provenance, {required bool toTemplate}) async {
    final workspace = ref.read(currentWorkspaceProvider).value;
    final hours = provenance.templateHours;
    if (workspace == null || (toTemplate && hours == null)) return;
    await runGuarded(
      context,
      domain: 'workspace',
      message: toTemplate
          ? 'reset work hours to template failed'
          : 'reset work hours to default failed',
      action: () => toTemplate
          ? resetWorkHoursToTemplate(ref, workspace.id, hours!)
          : resetWorkHoursToProductDefault(ref, workspace.id),
    );
  }
}
