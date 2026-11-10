// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3563 -- the country field of a form: a lookup over the app's catalogue,
// each option "France · FR" in the reader's language; the controller keeps
// the ISO code.
import 'package:flutter/material.dart';

import '../country/country_catalog.dart';
import '../i18n/country_names.dart';
import '../l10n/context_l10n.dart';
import '../text/collation.dart';
import 'master_data_field.dart';

/// Every country of the catalogue, named in the reader's language.
List<MasterDataOption> _countryOptions(BuildContext context) {
  final l10n = context.l10n;
  return [
    for (final c in CountryCatalog.countries)
      MasterDataOption(code: c.code, name: localizedCountryName(l10n, c.code)),
  ]..sort((a, b) => compareNames(a.name, b.name));
}

/// Whether [code] is a country of the catalogue (case-insensitive).
bool _isKnownCountry(String code) {
  final c = code.trim().toUpperCase();
  return CountryCatalog.countries.any((x) => x.code == c);
}

/// An empty country is not an error (the field is optional); a code is one
/// when it is not in the catalogue.
bool isKnownOrEmptyCountry(String code) =>
    code.trim().isEmpty || _isKnownCountry(code);

class CountryField extends StatelessWidget {
  const CountryField({
    super.key,
    required this.controller,
    required this.label,
    this.fieldKey,
    this.textKey,
    this.focusNode,
    this.helper,
    this.error,
    this.enabled = true,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? fieldKey;
  final Key? textKey;
  final FocusNode? focusNode;
  final String? helper;
  final String? error;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => MasterDataField(
    controller: controller,
    label: label,
    options: _countryOptions(context),
    fieldKey: fieldKey,
    textKey: textKey,
    focusNode: focusNode,
    helper: helper,
    error: error,
    enabled: enabled,
    onChanged: onChanged,
  );
}
