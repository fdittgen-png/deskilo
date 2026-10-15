// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2362 -- the sales-tax rows of the tax reference editor: the jurisdictions of
// a postal code typed one per line as `level, name, percent`.
import 'package:flutter/material.dart';

import '../../../../core/text/number_text.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/vat/tax_reference.dart';
import '../../../../l10n/app_localizations.dart';

/// The jurisdictions typed in [text], or null when a line is not of the form
/// `level, name, percent` (percent 0 to 20) or there is none.
List<SalesTaxComponent>? parseSalesTaxComponents(String text) {
  final out = <SalesTaxComponent>[];
  for (final line in text.split('\n')) {
    if (line.trim().isEmpty) continue;
    final parts = line.split(',').map((p) => p.trim()).toList();
    final pct = parts.length < 3
        ? null
        : double.tryParse(parts.last.replaceAll(',', '.'));
    if (pct == null || pct < 0 || pct > 20 || parts.first.isEmpty) return null;
    out.add(
      SalesTaxComponent(
        level: parts.first,
        label: parts.sublist(1, parts.length - 1).join(', '),
        percent: pct,
      ),
    );
  }
  return out.isEmpty ? null : out;
}

/// [value]'s jurisdictions as the editor shows them.
String salesTaxComponentsText(SalesTaxValue value) => [
  for (final c in value.components)
    '${c.level}, ${c.label}, ${percentText(c.percent)}',
].join('\n');

/// The multi-line field of the jurisdictions.
Widget salesTaxComponentsField(FormControllers fields, AppLocalizations l10n) =>
    AppTextField(
      key: const ValueKey('tax-ref-components'),
      controller: fields['components'],
      fieldKey: 'components',
      label: l10n.taxRefComponents,
      maxLines: 6,
    );
