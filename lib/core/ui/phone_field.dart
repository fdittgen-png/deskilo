// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3650 — the one phone field of a form: the country whose calling code a
// national number is read in (from the app's catalogue, "France (+33) ·
// FR"), and the number as the person types it. A number typed with + or 00
// needs no country. What is typed is kept as typed; the validated
// international form comes from [phoneEntryOf], and a number that cannot be
// one of its country's is refused in words ([phoneProblemText]).
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../country/country_catalog.dart';
import '../i18n/country_names.dart';
import '../l10n/context_l10n.dart';
import '../phone/phone_entry.dart';
import '../text/collation.dart';
import 'form_kit.dart';
import 'master_data_field.dart';

/// The countries of the catalogue the phone metadata knows, each with its
/// calling code, named in the reader's language.
List<MasterDataOption> _callingOptions(BuildContext context) {
  final l10n = context.l10n;
  return [
    for (final c in CountryCatalog.countries)
      if (callingCodeOf(c.code) case final code when code.isNotEmpty)
        MasterDataOption(
          code: c.code,
          name: '${localizedCountryName(l10n, c.code)} (+$code)',
        ),
  ]..sort((a, b) => compareNames(a.name, b.name));
}

/// The number of [number] read in [country]: its typed and validated forms.
PhoneEntry phoneEntryOf(
  TextEditingController number,
  TextEditingController country,
) => parsePhone(number.text, country: country.text);

/// Why [entry] has no validated form, in words; null when it has one or
/// nothing was typed.
String? phoneProblemText(AppLocalizations l10n, PhoneEntry entry) =>
    entry.isEmpty
    ? null
    : switch (entry.problem) {
        PhoneProblem.noCountry => l10n.phoneNoCountry,
        PhoneProblem.notANumber => l10n.phoneNotANumber,
        PhoneProblem.notValidForCountry => l10n.phoneNotValidForCountry,
        null => null,
      };

class PhoneField extends StatelessWidget {
  const PhoneField({
    super.key,
    required this.number,
    required this.country,
    required this.label,
    this.fieldKey,
    this.helper,
    this.error,
    this.autofocus = false,
    this.enabled = true,
    this.onChanged,
  });

  /// What the person types.
  final TextEditingController number;

  /// The ISO code of the country a national number is read in.
  final TextEditingController country;
  final String label;

  /// The form error key of the number, and the prefix of the two parts'
  /// widget keys: `<fieldKey>-country`, `<fieldKey>-number`.
  final String? fieldKey;
  final String? helper;
  final String? error;
  final bool autofocus;
  final bool enabled;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        MasterDataField(
          controller: country,
          label: l10n.phoneCountryLabel,
          options: _callingOptions(context),
          textKey: fieldKey == null ? null : ValueKey('$fieldKey-country'),
          enabled: enabled,
          onChanged: (_) => onChanged?.call(),
        ),
        const FormGap(),
        AppTextField(
          key: fieldKey == null ? null : ValueKey('$fieldKey-number'),
          controller: number,
          label: label,
          fieldKey: fieldKey,
          helper: helper,
          error: error,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          autofocus: autofocus,
          enabled: enabled,
          onChanged: (_) => onChanged?.call(),
        ),
      ],
    );
  }
}
