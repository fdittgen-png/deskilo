// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4471 -- a unit and a VAT rate are picked from the master data, never typed. One picker over the business's units of measure
// and one over its VAT rates, for every form that asks for either. A value that is not in the master data (a row saved while it
// was free text) is shown as it is, with the reason it must be replaced, and cannot be saved.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../stock/domain/workspace_units.dart';
import '../../../stock/providers/workspace_units_providers.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../providers/money_providers.dart' show vatRatesProvider;
import '../standalone/line_unit_text.dart';

/// Whether [code] (the empty one is "none yet") is a unit [units] offers.
bool unitIsListed(List<WorkspaceUnit> units, String code) => code.isEmpty || units.any((u) => u.code == code);

/// The units a unit input offers in [workspaceId]: the business's own that are not archived while the units feature is on, the
/// six of before while it is off. A business whose units are still being read is offered the six of before.
List<WorkspaceUnit> unitsOffered(WidgetRef ref, String workspaceId) {
  final on = ref.watch(enabledFeaturesSyncProvider).contains(WorkspaceFeature.unitsOfMeasure);
  final all = on ? (ref.watch(workspaceUnitListProvider(workspaceId)).value ?? builtInUnits) : builtInUnits;
  return pickableUnits(all, unitsOn: on);
}

/// What a unit is: its code, an optional unit chosen from the master data.
class UnitPickerField extends ConsumerWidget {
  const UnitPickerField({
    super.key,
    required this.workspaceId,
    required this.value,
    required this.onChanged,
    required this.label,
    this.enabled = true,
    this.errorText,
    this.required = false,
  });

  final String workspaceId;

  /// The unit code the row holds; '' while none is chosen.
  final String value;
  final ValueChanged<String> onChanged;
  final String label;
  final bool enabled;
  final String? errorText;

  /// Whether a unit must be chosen: a row with none says so; otherwise "no unit" is offered.
  final bool required;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final units = unitsOffered(ref, workspaceId);
    final listed = unitIsListed(units, value);
    return DropdownButtonFormField<String>(
      key: ValueKey('unit-$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, errorText: listed ? errorText : l.masterDataUnlisted),
      items: [
        if (!listed) DropdownMenuItem(value: value, child: Text(value, overflow: TextOverflow.ellipsis)),
        if (!required) DropdownMenuItem(value: '', child: Text(l.masterDataNoUnit)),
        for (final u in units)
          DropdownMenuItem(value: u.code, child: Text(lineUnitName(l, code: u.code, label: u.label), overflow: TextOverflow.ellipsis)),
      ],
      onChanged: enabled ? (v) => onChanged(v ?? '') : null,
    );
  }
}

/// Whether [percent] (null: none) is the rate of one of [rates].
bool vatPercentIsListed(List<VatRate> rates, double? percent) => percent == null || rates.any((r) => r.percent == percent);

/// The active VAT rates a VAT input offers; none while they are being read.
List<VatRate> vatRatesOffered(WidgetRef ref) => [for (final r in ref.watch(vatRatesProvider).value ?? const <VatRate>[]) if (r.active) r];

/// The percent of a VAT rate, picked from the business's active rates; the percent is never typed.
class VatPercentPicker extends ConsumerWidget {
  const VatPercentPicker({super.key, required this.value, required this.onChanged, required this.label, this.enabled = true});

  /// The percent the row holds; null while none is chosen (no VAT).
  final double? value;
  final ValueChanged<double?> onChanged;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final format = appFormatOf(context);
    final rates = vatRatesOffered(ref);
    final listed = vatPercentIsListed(rates, value);
    return DropdownButtonFormField<double?>(
      key: ValueKey('vat-$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, errorText: listed ? null : l.masterDataUnlisted),
      items: [
        if (!listed) DropdownMenuItem<double?>(value: value, child: Text(format.ratePercent(value!))),
        DropdownMenuItem<double?>(child: Text(l.masterDataNoVat)),
        for (final r in rates) DropdownMenuItem<double?>(value: r.percent, child: Text('${r.label} (${format.ratePercent(r.percent)})')),
      ],
      onChanged: enabled ? onChanged : null,
    );
  }
}
