// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4479 -- Settings > Units of measure: the business's general conversions (1 kg = 1000 g), each a line that is edited by a tap and
// deleted by its icon. A conversion works both ways and one step only; an item's own conversion wins over these, and a packaging unit
// has none here. The server decides what is refused and the screen says it in words; nothing is changed on a failed read.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ids/request_id.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/app_snack.dart';
import '../../../core/ui/async_read_body.dart';
import '../domain/stock_config.dart';
import '../domain/unit_conversions.dart';
import '../domain/workspace_units.dart';
import '../providers/workspace_units_providers.dart';
import 'measure_unit_text.dart';
import 'stock_config_text.dart';
import 'unit_conversion_sheet.dart';

class UnitConversionsSection extends ConsumerWidget {
  const UnitConversionsSection({super.key, required this.workspaceId, required this.units});

  final String workspaceId;
  final List<WorkspaceUnit> units;

  Future<void> _edit(BuildContext context, WidgetRef ref, UnitConversion? conversion) => showUnitConversionSheet(
    context,
    ref.read(unitConversionsProvider),
    workspaceId: workspaceId,
    units: units,
    conversion: conversion,
    onDone: () async => ref.invalidate(unitConversionListProvider(workspaceId)),
  );

  Future<void> _delete(BuildContext context, WidgetRef ref, UnitConversion c) async {
    final l10n = context.l10n;
    try {
      await ref.read(unitConversionsProvider).delete(workspaceId, requestId: newRequestId(), fromUnit: c.fromUnit, toUnit: c.toUnit);
      ref.invalidate(unitConversionListProvider(workspaceId));
    } on StockConfigRefused catch (e, stack) {
      TraceLogger.instance.warn('stock', 'deleting a conversion was refused: ${e.reason}', error: e, stackTrace: stack);
      if (context.mounted) AppSnack.error(context, stockRefusalText(l10n, e.reason, subject: StockSubject.measureUnit));
    }
  }

  String _name(BuildContext context, String code) {
    final unit = units.where((u) => u.code == code).firstOrNull;
    return unit == null ? code : measureUnitName(context.l10n, unit);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final list = ref.watch(unitConversionListProvider(workspaceId));
    return Column(
      key: const ValueKey('unit-conversions'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.lg),
        Text(l10n.unitConversionsTitle, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.unitConversionsIntro),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            key: const ValueKey('unit-conversion-new'),
            onPressed: list.hasValue ? () => _edit(context, ref, null) : null,
            icon: const Icon(Icons.add),
            label: Text(l10n.unitConversionNew),
          ),
        ),
        switch (list) {
          AsyncData(:final value) when value.isEmpty => Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(l10n.unitConversionsEmpty, key: const ValueKey('unit-conversions-empty')),
          ),
          AsyncData(:final value) => Column(
            children: [
              for (final c in value)
                ListTile(
                  key: ValueKey('unit-conversion-${c.fromUnit}-${c.toUnit}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.unitConversionLine(_name(context, c.fromUnit), conversionFactorText(c), _name(context, c.toUnit))),
                  // #4479 -- a conversion a person wrote says so; one whose unit was edited since asks to be looked at
                  subtitle: c.needsReview
                      ? Text(l10n.unitConversionNeedsReview, key: ValueKey('unit-conversion-review-${c.fromUnit}-${c.toUnit}'))
                      : (c.authored ? Text(l10n.unitConversionAuthored) : null),
                  onTap: () => _edit(context, ref, c),
                  trailing: IconButton(
                    key: ValueKey('unit-conversion-delete-${c.fromUnit}-${c.toUnit}'),
                    tooltip: l10n.unitConversionDelete,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(context, ref, c),
                  ),
                ),
            ],
          ),
          AsyncError(:final error) => ReadFailureBanner(
            key: const ValueKey('unit-conversions-failed'),
            error: error,
            onRetry: () => ref.invalidate(unitConversionListProvider(workspaceId)),
          ),
          _ => const Padding(padding: EdgeInsets.all(AppSpacing.md), child: LinearProgressIndicator()),
        },
      ],
    );
  }
}
