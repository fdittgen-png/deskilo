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
    this.itemId,
    this.supplierId,
  });

  final String workspaceId;

  /// #4479 -- the stocked item the row is for: only the units it converts from are offered.
  final String? itemId;
  final String? supplierId;

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
    final all = ref.watch(pickableUnitsProvider(workspaceId));
    final item = itemId;
    final only = item == null ? null : ref.watch(itemOrderUnitsProvider((workspaceId: workspaceId, itemId: item, supplierId: supplierId))).value?.units;
    final units = only == null ? all : [for (final u in all) if (only.any((o) => o.code == u.code)) u];
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
bool _vatPercentIsListed(List<VatRate> rates, double? percent) => percent == null || rates.any((r) => r.percent == percent);

const _noVat = 'none';

/// A VAT rate of the business, picked by its identity (two rates may share a percentage); the percent is never typed (#4479).
class VatRatePicker extends ConsumerWidget {
  const VatRatePicker({super.key, required this.rateId, required this.percent, required this.onChanged, required this.label, this.enabled = true});

  /// The rate the row holds; null while none is chosen.
  final String? rateId;

  /// The percent the row holds: of the rate, or the one a line stored before it named a rate.
  final double? percent;

  /// The rate picked; null for none.
  final ValueChanged<VatRate?> onChanged;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) => switch (ref.watch(vatRatesProvider)) {
    AsyncData(:final value) => _VatChoice(
      key: const ValueKey('vat-choice'),
      rates: [
        for (final r in value) if (r.active) r,
      ],
      rateId: rateId,
      percent: percent,
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

/// Whether the held rate is one of [rates]: a rate by its id, or a stored percent that is some rate's.
bool vatRateIsListed(List<VatRate> rates, String? rateId, double? percent) =>
    rateId != null ? rates.any((r) => r.id == rateId) : _vatPercentIsListed(rates, percent);

/// The choice once the rates are read: none, each rate, and a held rate that is none of them, shown as it is and flagged.
class _VatChoice extends StatelessWidget {
  const _VatChoice({super.key, required this.rates, required this.rateId, required this.percent, required this.onChanged, required this.label});

  final List<VatRate> rates;
  final String? rateId;
  final double? percent;
  final ValueChanged<VatRate?>? onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final format = appFormatOf(context);
    final listed = vatRateIsListed(rates, rateId, percent);
    // a line stored before it named a rate shows the one rate that has its percent
    final sharing = [for (final r in rates) if (r.percent == percent) r.id];
    final current = rateId ?? (percent == null ? _noVat : (sharing.length == 1 ? sharing.single : 'percent-$percent'));
    final known = current == _noVat || rates.any((r) => r.id == current);
    final picked = onChanged;
    return AppDropdownField<String>(
      key: ValueKey('vat-$current'),
      label: label,
      value: current,
      error: listed ? null : l.masterDataUnlisted,
      items: [
        if (!known) (current, percent == null ? current : format.ratePercent(percent!)),
        (_noVat, l.masterDataNoVat),
        for (final r in rates) (r.id, '${r.label} (${format.ratePercent(r.percent)})'),
      ],
      onChanged: picked == null ? null : (v) => picked(rates.where((r) => r.id == v).firstOrNull),
    );
  }
}
