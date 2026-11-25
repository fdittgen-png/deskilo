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
import '../../../../core/ui/async_read_body.dart';
import '../../../../core/ui/dropdown_field.dart';
import '../../domain/line_unit.dart';
import '../../providers/money_providers.dart' show vatRatesProvider;
import '../../providers/pickable_units_provider.dart';
import '../standalone/line_unit_text.dart';

/// Whether [code] (the empty one is "none yet") is a unit [units] offers.
bool unitIsListed(List<LineUnit> units, String code) => code.isEmpty || units.any((u) => u.code == code);

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

  /// Whether a unit must be chosen: otherwise "no unit" is offered.
  final bool required;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final units = ref.watch(pickableUnitsProvider(workspaceId));
    final listed = unitIsListed(units, value);
    return AppDropdownField<String>(
      // a value that changes from outside (a line removed above) is drawn again
      key: ValueKey('unit-$value'),
      label: label,
      value: value.isEmpty && required ? null : value,
      error: listed ? errorText : l.masterDataUnlisted,
      items: [
        if (!listed) (value, value),
        if (!required) ('', l.masterDataNoUnit),
        for (final u in units) (u.code, lineUnitName(l, code: u.code, label: u.label)),
      ],
      onChanged: enabled ? (v) => onChanged(v ?? '') : null,
    );
  }
}

/// Whether [percent] (null: none) is the rate of one of [rates].
bool vatPercentIsListed(List<VatRate> rates, double? percent) => percent == null || rates.any((r) => r.percent == percent);

const _noVat = 'none';

/// The percent of a VAT rate, picked from the business's active rates; the percent is never typed.
class VatPercentPicker extends ConsumerWidget {
  const VatPercentPicker({super.key, required this.value, required this.onChanged, required this.label, this.enabled = true});

  /// The percent the row holds; null while none is chosen (no VAT).
  final double? value;
  final ValueChanged<double?> onChanged;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) => switch (ref.watch(vatRatesProvider)) {
    AsyncData(:final value) => _VatChoice(
      rates: [
        for (final r in value) if (r.active) r,
      ],
      current: this.value,
      onChanged: enabled ? onChanged : null,
      label: label,
    ),
    AsyncError(:final error) => ReadFailureBanner(
      key: const ValueKey('vat-rates-failed'),
      error: error,
      onRetry: () => ref.invalidate(vatRatesProvider),
    ),
    _ => const LinearProgressIndicator(),
  };
}

/// The choice once the rates are read: none, each rate, and a percent that is no rate's, shown as it is and flagged.
class _VatChoice extends StatelessWidget {
  const _VatChoice({required this.rates, required this.current, required this.onChanged, required this.label});

  final List<VatRate> rates;
  final double? current;
  final ValueChanged<double?>? onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final format = appFormatOf(context);
    final listed = vatPercentIsListed(rates, current);
    // the percent each choice stands for, so none is parsed back from its text
    final percents = {for (final r in rates) '${r.percent}': r.percent};
    final picked = onChanged;
    return AppDropdownField<String>(
      key: ValueKey('vat-$current'),
      label: label,
      value: current == null ? _noVat : '$current',
      error: listed ? null : l.masterDataUnlisted,
      items: [
        if (!listed) ('$current', format.ratePercent(current!)),
        (_noVat, l.masterDataNoVat),
        for (final r in rates) ('${r.percent}', '${r.label} (${format.ratePercent(r.percent)})'),
      ],
      onChanged: picked == null ? null : (v) => picked(percents[v]),
    );
  }
}
