// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #896/#2355 — WHEN the VAT falls due, as the legal identity asks it: the
// country's legal rule first, then only the options that country's law
// allows (France's debits, a cash scheme elsewhere). It decides which
// period a declaration covers, and it is printed on every invoice.
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/vat_tax_point.dart';
import '../vat_tax_point_labels.dart';

class VatTaxPointField extends StatelessWidget {
  const VatTaxPointField({
    super.key,
    required this.country,
    required this.value,
    required this.onChanged,
  });

  /// The seller's country (ISO 3166-1 alpha-2).
  final String country;
  final VatTaxPointOption value;
  final ValueChanged<VatTaxPointOption> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final policy = vatTaxPointPolicy(country);
    return DropdownButtonFormField<VatTaxPointOption>(
      key: const ValueKey('legal-identity-exigibility'),
      initialValue: policy.effective(value),
      isExpanded: true,
      items: [
        for (final option in policy.options)
          DropdownMenuItem(
            value: option,
            child: Text(
              vatTaxPointOptionLabel(l10n, policy, option),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (v) => onChanged(v ?? value),
      decoration: InputDecoration(
        labelText: vatWords(l10n).vatExigibilityTitle,
        helperMaxLines: 6,
        helperText: vatWords(l10n).vatExigibilitySubtitle,
      ),
    );
  }
}
