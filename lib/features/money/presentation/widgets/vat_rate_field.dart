// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/vat_rate.dart';

/// Which VAT rate a catalogue entry is taxed at (0072).
///
/// Renders NOTHING when the workspace has no rates: a workspace that
/// charges no VAT should not have to look at a field that can only say
/// "none". '' is the value meaning "the workspace default", so an owner who
/// later changes that default does not have to revisit every service.
class VatRateField extends StatelessWidget {
  const VatRateField({
    super.key,
    required this.rates,
    required this.value,
    required this.onChanged,
  });

  final List<VatRate> rates;

  /// A rate id, or '' for the workspace default.
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    if (rates.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    // A rate that was deactivated after this item pointed at it is still
    // its rate: keep showing the default entry rather than silently
    // re-taxing it here.
    final known = rates.any((rate) => rate.id == value);
    return DropdownButtonFormField<String>(
      key: const ValueKey('vat-rate-field'),
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
