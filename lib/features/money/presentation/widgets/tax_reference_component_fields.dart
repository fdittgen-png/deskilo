// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2539 -- the `rate_component` rows of the tax reference editor: the taxes
// inside a combined rate typed one per line as `scheme, authority, percent`.
import 'package:flutter/material.dart';

import '../../../../core/text/number_text.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/vat/tax_reference.dart';
import '../../../../l10n/app_localizations.dart';

/// The taxes typed in [text], or null when a line is not of the form
/// `scheme, authority, percent` (percent above 0 up to 99.999) or there is none.
List<RateComponent>? parseRateComponents(String text) {
  final out = <RateComponent>[];
  for (final line in text.split('\n')) {
    if (line.trim().isEmpty) continue;
    final parts = line.split(',').map((p) => p.trim()).toList();
    if (parts.length != 3 || parts[0].isEmpty || parts[1].isEmpty) return null;
    final pct = double.tryParse(parts[2]);
    if (pct == null || pct <= 0 || pct > 99.999) return null;
    out.add(RateComponent(scheme: parts[0], authority: parts[1], percent: pct));
  }
  return out.isEmpty ? null : out;
}

/// Whether [components] exist and add up to the combined [percent].
bool rateComponentsAddUp(List<RateComponent>? components, double? percent) {
  if (components == null || percent == null) return false;
  final sum = components.fold<double>(0, (s, c) => s + c.percent);
  return (sum - percent).abs() < 1e-9;
}

/// [value]'s taxes as the editor shows them.
String rateComponentsText(RateComponentValue value) => [
  for (final c in value.components)
    '${c.scheme}, ${c.authority}, ${percentText(c.percent)}',
].join('\n');

/// The multi-line field of the taxes.
Widget rateComponentsField(FormControllers fields, AppLocalizations l10n) =>
    AppTextField(
      key: const ValueKey('tax-ref-components'),
      controller: fields['components'],
      fieldKey: 'components',
      label: l10n.taxRefRateComponents,
      maxLines: 4,
    );
