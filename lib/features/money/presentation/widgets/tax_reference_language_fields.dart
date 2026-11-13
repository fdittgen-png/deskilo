// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3850 -- the tax reference editor's form of a `document_language` row: the
// country's official languages, whether an invoice may be in its customer's
// language (a switch of the version form), and the language a region
// requires, typed as `QC=fr`.
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart';

import '../../../../core/ui/form_kit.dart';
import '../../../../l10n/app_localizations.dart';

final _language = RegExp(r'^[a-z]{2}$');
final _region = RegExp(r'^[A-Z0-9]{1,3}$');

List<String> _items(String text) => [
  for (final p in text.split(','))
    if (p.trim().isNotEmpty) p.trim(),
];

/// The text of the two list fields, from the version copied.
Map<String, String> documentLanguageTexts(TaxValue? v) => {
  'languages': v is DocumentLanguageValue ? v.languages.join(', ') : '',
  'required_languages': v is DocumentLanguageValue
      ? [for (final e in v.requiredBySubdivision.entries) '${e.key}=${e.value}']
            .join(', ')
      : '',
};

/// The required languages typed in [text]; null when one is malformed.
Map<String, String>? _required(String text) {
  final out = <String, String>{};
  for (final item in _items(text)) {
    final pair = item.split('=');
    if (pair.length != 2) return null;
    final region = pair[0].trim().toUpperCase();
    final language = pair[1].trim().toLowerCase();
    if (!_region.hasMatch(region) || !_language.hasMatch(language)) return null;
    out[region] = language;
  }
  return out;
}

/// The refusals of the form: at least one two-letter language, and
/// well-formed region requirements.
FieldErrors documentLanguageFieldErrors(
  AppLocalizations l10n,
  FormControllers fields,
) {
  final languages = _items(fields.text('languages'));
  return {
    if (languages.isEmpty ||
        languages.length > 10 ||
        !languages.every(_language.hasMatch))
      'languages': l10n.taxRefInvalidLanguages,
    if (_required(fields.text('required_languages')) == null)
      'required_languages': l10n.taxRefInvalidRequiredLanguages,
  };
}

/// The `document_language` value the form stands for.
DocumentLanguageValue documentLanguageValueOf(
  FormControllers fields,
  Map<String, bool> flag,
) => DocumentLanguageValue(
  languages: _items(fields.text('languages')),
  customerLanguage: flag['customer_language']!,
  requiredBySubdivision:
      _required(fields.text('required_languages')) ?? const {},
);
