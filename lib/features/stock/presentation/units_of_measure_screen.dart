// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4442 -- Settings > Units of measure: the units the business's items, quotes and invoices are measured in, grouped by what they
// measure, each with its conversion line (1 km = 1000 m). The owner and the admins add a unit, rename one, set its UN/ECE code
// and archive one nobody uses; the built-in units are always there and their factors never change. The server decides what is
// refused and the screen says it in words; nothing is changed on a failed read.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/help/help_anchors.dart';
import '../../../core/ids/request_id.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/app_snack.dart';
import '../domain/measure_unit_form.dart';
import '../domain/stock_config.dart';
import '../domain/workspace_units.dart';
import '../providers/workspace_units_providers.dart';
import 'measure_unit_sheet.dart';
import 'measure_unit_text.dart';
import 'stock_config_text.dart';
import 'stock_page_shell.dart';
import 'unit_conversions_section.dart';

class UnitsOfMeasureScreen extends ConsumerWidget {
  const UnitsOfMeasureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return StockPageShell(
      title: l10n.featureUnitsOfMeasureTitle,
      anchor: HelpAnchor.settingsUnits,
      // a unit is added once the units are read: a new one is checked against them
      floatingActionButton: (ref, workspaceId) => switch (ref.watch(workspaceUnitListProvider(workspaceId)).value) {
        null => null,
        final all => FloatingActionButton.extended(
          key: const ValueKey('measure-units-new'),
          onPressed: () => _edit(context, ref, workspaceId, all, null),
          icon: const Icon(Icons.add),
          label: Text(l10n.measureUnitNew),
        ),
      },
      body: (context, ref, workspaceId) => StockRead(
        keyName: 'measure-units',
        value: ref.watch(workspaceUnitListProvider(workspaceId)),
        onRetry: () => ref.invalidate(workspaceUnitListProvider(workspaceId)),
        data: (value) => _Units(
          workspaceId: workspaceId,
          units: value,
          onEdit: (u) => _edit(context, ref, workspaceId, value, u),
          onArchive: (u) => _archive(context, ref, workspaceId, u),
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, String workspaceId, List<WorkspaceUnit> all, WorkspaceUnit? unit) =>
      showMeasureUnitSheet(
        context,
        ref.read(workspaceUnitsProvider),
        workspaceId: workspaceId,
        all: all,
        unit: unit,
        onDone: () async => ref.invalidate(workspaceUnitListProvider(workspaceId)),
      );

  Future<void> _archive(BuildContext context, WidgetRef ref, String workspaceId, WorkspaceUnit unit) async {
    final l10n = context.l10n;
    try {
      await ref.read(workspaceUnitsProvider).archive(workspaceId, requestId: newRequestId(), code: unit.code, archived: !unit.archived);
      ref.invalidate(workspaceUnitListProvider(workspaceId));
    } on StockConfigRefused catch (e, stack) {
      TraceLogger.instance.warn('stock', 'archiving a unit was refused: ${e.reason}', error: e, stackTrace: stack);
      if (context.mounted) AppSnack.error(context, stockRefusalText(l10n, e.reason, subject: StockSubject.measureUnit));
    }
  }
}

class _Units extends StatelessWidget {
  const _Units({required this.workspaceId, required this.units, required this.onEdit, required this.onArchive});

  final String workspaceId;
  final List<WorkspaceUnit> units;
  final void Function(WorkspaceUnit unit) onEdit;
  final void Function(WorkspaceUnit unit) onArchive;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md).add(const EdgeInsets.only(bottom: kFabSafeBottom)),
      children: [
        Text(l10n.measureUnitsIntro),
        for (final d in UnitDimension.values) ...[
          if (units.any((u) => u.dimension == d)) ...[
            const SizedBox(height: AppSpacing.md),
            Text(measureDimensionText(l10n, d), style: Theme.of(context).textTheme.titleSmall, key: ValueKey('measure-dimension-${d.name}')),
            for (final u in units.where((u) => u.dimension == d))
              _UnitTile(unit: u, base: baseUnitOf(units, d), onEdit: () => onEdit(u), onArchive: () => onArchive(u)),
          ],
        ],
        // #4479 -- what converts to what is defined, never implied
        UnitConversionsSection(workspaceId: workspaceId, units: units),
      ],
    );
  }
}

class _UnitTile extends StatelessWidget {
  const _UnitTile({required this.unit, required this.base, required this.onEdit, required this.onArchive});

  final WorkspaceUnit unit;
  final WorkspaceUnit? base;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tags = [if (unit.builtIn) l10n.measureUnitBuiltIn, if (unit.archived) l10n.measureUnitArchivedTag];
    return ListTile(
      key: ValueKey('measure-unit-${unit.code}'),
      contentPadding: EdgeInsets.zero,
      title: Text(measureUnitName(l10n, unit)),
      subtitle: Text([
        l10n.measureUnitLine(unit.code, factorText(unit), base == null ? '' : measureUnitName(l10n, base!)),
        ...tags,
      ].join(' · ')),
      onTap: onEdit,
      trailing: unit.builtIn
          ? null
          : IconButton(
              key: ValueKey('measure-unit-archive-${unit.code}'),
              tooltip: unit.archived ? l10n.measureUnitRestore : l10n.measureUnitArchive,
              icon: Icon(unit.archived ? Icons.unarchive_outlined : Icons.archive_outlined),
              onPressed: onArchive,
            ),
    );
  }
}
