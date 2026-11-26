// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4471 -- a unit of an item or a group is picked from the business's units of measure, never typed. The same choice the money
// forms make (their picker reads the units through a seam; here the stock owns them). A value that is none of the units (a name
// typed before) is shown as it is and flagged: a unit from the list replaces it before the form saves.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/dropdown_field.dart';
import '../../../core/ui/form_kit.dart' show FormErrorsScope;
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/workspace_units.dart';
import '../providers/workspace_units_providers.dart';

/// The units a unit input of [workspaceId] offers: the business's own that are not archived while the units feature is on, the
/// six of before while it is off.
List<WorkspaceUnit> _unitsOffered(WidgetRef ref, String workspaceId) {
  final on = ref.watch(enabledFeaturesSyncProvider).contains(WorkspaceFeature.unitsOfMeasure);
  // the business's units are read whether the feature is on or not: it hides the screen that makes units, not the units that exist
  final all = ref.watch(workspaceUnitListProvider(workspaceId)).value ?? builtInUnits;
  return pickableUnits(all, unitsOn: on);
}

/// Whether [code] (empty: none) is one of [units].
bool _isListed(List<WorkspaceUnit> units, String code) => code.isEmpty || units.any((u) => u.code == code);

/// The codes a unit input of [workspaceId] offers, read when a sheet opens, for the sheet's own check before it saves: a unit that is not
/// among them (a name typed before) cannot be saved. A business whose units cannot be read is offered the six of before.
Future<Set<String>> stockUnitCodes(BuildContext context, String workspaceId) async {
  final container = ProviderScope.containerOf(context);
  final on = container.read(enabledFeaturesSyncProvider).contains(WorkspaceFeature.unitsOfMeasure);
  final all = await guardRead<List<WorkspaceUnit>>(
    domain: 'stock',
    message: 'the units could not be read for a sheet',
    read: () => container.read(workspaceUnitListProvider(workspaceId).future),
    fallback: (_) => builtInUnits,
  );
  return {for (final u in pickableUnits(all, unitsOn: on)) u.code};
}

class StockUnitPicker extends ConsumerWidget {
  const StockUnitPicker({super.key, required this.workspaceId, required this.value, required this.onChanged, required this.label, this.none, this.fieldKey});

  final String workspaceId;

  /// The unit code the field holds; '' while none is chosen.
  final String value;
  final ValueChanged<String> onChanged;
  final String label;

  /// The words of "no unit" when the field may stay empty; null when a unit must be chosen.
  final String? none;

  /// The key the form reports this field's problems under, as a text field's `fieldKey`.
  final String? fieldKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = _unitsOffered(ref, workspaceId);
    final listed = _isListed(units, value);
    final scope = fieldKey == null ? null : FormErrorsScope.maybeOf(context);
    return AppDropdownField<String>(
      key: ValueKey('stock-unit-pick-$value'),
      label: label,
      value: value.isEmpty && none == null ? null : value,
      error: listed ? scope?.errors[fieldKey] : context.l10n.masterDataUnlisted,
      items: [
        if (!listed) (value, value),
        if (none != null) ('', none!),
        for (final u in units) (u.code, u.label ?? u.code),
      ],
      onChanged: (v) {
        if (scope != null && fieldKey != null) scope.onEdit(fieldKey!);
        onChanged(v ?? '');
      },
    );
  }
}
