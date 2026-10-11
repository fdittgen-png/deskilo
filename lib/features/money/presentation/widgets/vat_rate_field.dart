// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../../../core/vat/supply_class.dart';
import '../../domain/vat_rate.dart';
import '../../domain/vat_regime.dart';

/// Which VAT rate a catalogue entry is taxed at (0072).
///
/// Renders NOTHING when the workspace has no rates OR its declared
/// regime charges no VAT (#484 — an exempt association must not be asked
/// to tax a service): a workspace that charges no VAT should not have to
/// look at a field that can only say "none". '' is the value meaning
/// "the workspace default", so an owner who later changes that default
/// does not have to revisit every service. The 0095 server gate is the
/// enforcement; this is the honest UI for it.
class VatRateField extends ConsumerWidget {
  const VatRateField({
    super.key,
    required this.rates,
    required this.value,
    required this.onChanged,
    this.dropdownKey = const ValueKey('vat-rate-field'),
  });

  final List<VatRate> rates;

  /// Key of the inner dropdown — override when two pickers share a
  /// screen (#542: the billing page has the pack AND the tariff one).
  final Key dropdownKey;

  /// A rate id, or '' for the workspace default.
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regime = vatRegimeFromWire(
        ref.watch(currentWorkspaceProvider).value?.vatRegime);
    // #544 — rate pickers are VAT MANAGEMENT: with the feature off the
    // picker disappears everywhere at once and stored rates keep
    // applying (the flag hides configuration, never the tax math).
    if (rates.isEmpty ||
        regime != VatRegime.vatRegistered ||
        !ref
            .watch(enabledFeaturesSyncProvider)
            .contains(WorkspaceFeature.vatManagement)) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    // A rate that was deactivated after this item pointed at it is still
    // its rate: keep showing the default entry rather than silently
    // re-taxing it here.
    final known = rates.any((rate) => rate.id == value);
    return DropdownButtonFormField<String>(
      key: dropdownKey,
      initialValue: known ? value : '',
      decoration: InputDecoration(
        labelText: l10n?.vatServiceRate ?? 'VAT rate',
      ),
      items: [
        DropdownMenuItem(
          value: '',
          child: Text(
            l10n?.vatServiceRateDefault ?? 'Workspace default',
          ),
        ),
        for (final rate in rates)
          DropdownMenuItem(
            value: rate.id,
            child: Text(vatRateOption(rate)),
          ),
      ],
      onChanged: (picked) => onChanged(picked ?? ''),
    );
  }
}

/// How a rate reads in a picker: 'Standard (20 %)'.
String vatRateOption(VatRate rate) {
  final percent = rate.percent == rate.percent.roundToDouble()
      ? rate.percent.toStringAsFixed(0)
      : rate.percent.toString();
  return '${rate.label} ($percent %)';
}

/// #2354 — where a catalogue service is supplied for VAT.
///
/// Renders NOTHING unless the workspace charges VAT and
/// `supplyClassification` is on: a seller that charges no VAT has no
/// place of supply to choose, and with the feature off every new charge
/// is connected with the premises (the server's default). The server
/// freezes the choice on each charge; this field only edits the service.
class SupplyClassField extends ConsumerWidget {
  const SupplyClassField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final SupplyClass value;
  final ValueChanged<SupplyClass> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regime = vatRegimeFromWire(
      ref.watch(currentWorkspaceProvider).value?.vatRegime,
    );
    if (regime != VatRegime.vatRegistered ||
        !ref
            .watch(enabledFeaturesSyncProvider)
            .contains(WorkspaceFeature.supplyClassification)) {
      return const SizedBox.shrink();
    }
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('en'));
    return DropdownButtonFormField<SupplyClass>(
      key: const ValueKey('supply-class-field'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: l10n.supplyClassLabel,
        helperText: l10n.supplyClassHelper,
        helperMaxLines: 5,
        suffixIcon: HelpDot(
          l10n.helpHintMoneyPaymentsTipSupplyTopic,
          anchor: HelpAnchor.serviceSupply,
        ),
      ),
      items: [
        for (final supply in SupplyClass.values)
          DropdownMenuItem(
            value: supply,
            child: Text(switch (supply) {
              SupplyClass.property => l10n.supplyClassProperty,
              SupplyClass.general => l10n.supplyClassGeneral,
            }, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (picked) => onChanged(picked ?? SupplyClass.property),
    );
  }
}
