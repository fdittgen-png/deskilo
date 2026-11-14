// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The tax reference editor's closed-list choices, and the two fields a
// threshold's charge (the Italian stamp duty) and an issuing gate's
// outside-VAT postal codes (the Canary Islands, Ceuta, Melilla) are typed in.
import 'package:deskilo_document_model/paper.dart';
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart';

import '../../../../core/i18n/time_zones.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/einvoice_mandates.dart';

/// The closed-list choices of a version form, from the version it copies:
/// the threshold effect, the tax point rule and backstop, the retention
/// start, the mandate duty, the export format, the taxability, the tax
/// system.
Map<String, String> taxReferenceChoicesOf(TaxValue? v) => {
  'effect': v is ThresholdValue ? v.effect : 'next_year',
  'standard': v is TaxPointValue ? v.standard : 'invoice',
  'cash_backstop': v is TaxPointValue ? v.cashBackstop : 'none',
  'start': v is RetentionValue ? v.from : 'fiscal_year_end',
  'duty': v is MandateValue ? v.duty : MandateDuty.receiveAll.wire,
  'format': v is AccountMapValue ? v.format : 'coa',
  'status': v is TaxabilityValue ? v.status : taxabilityStatuses.first,
  'tax_system': v is IssuingGateValue ? v.taxSystem : 'vat',
  'banking_scheme': v is CountryValue ? v.bankingScheme : 'sepa',
  'paper': v is CountryValue ? (v.paper ?? Paper.a4.wire) : Paper.a4.wire,
};

/// The text of the charge and postal-code fields, from the version copied.
Map<String, String> taxReferenceExtraTexts(TaxValue? v) => {
  'charge_cents': v is ThresholdValue && v.chargeCents != 0
      ? '${v.chargeCents}'
      : '',
  'outside_vat_postal_codes': v is IssuingGateValue
      ? v.outsideVatPostalCodes.join(', ')
      : '',
  'papers': v is CountryValue ? (v.papers ?? const []).join(', ') : '',
};

/// The postal-code prefixes typed in [text], separated by commas.
List<String> postalPrefixesOf(String text) => [
  for (final p in text.split(','))
    if (p.trim().isNotEmpty) p.trim(),
];

/// #2488 -- the banking schemes a country of the creation catalogue may name.
const bankingSchemeNames = ['sepa', 'uk', 'us', 'ca', 'ch'];

/// #3852 -- the papers typed in the `country` form; empty: A4 and Letter.
List<String> _papersOf(FormControllers fields) => postalPrefixesOf(fields.text('papers'));

/// The refusals of the `country` form: a three-letter currency, a zone the
/// app's clock knows, and papers the app prints on that hold the usual one.
FieldErrors countryFieldErrors(
  AppLocalizations l10n,
  FormControllers fields,
  Map<String, String> choice,
) {
  final papers = _papersOf(fields);
  return {
    if (!RegExp(r'^[A-Za-z]{3}$').hasMatch(fields.text('currency'))) 'currency': l10n.taxRefRequired,
    if (!TimeZones.isKnown(fields.text('time_zone').trim())) 'time_zone': l10n.taxRefInvalidTimeZone,
    if (papers.isNotEmpty &&
        (papers.any((p) => Paper.fromWire(p) == null) ||
            papers.toSet().length != papers.length ||
            !papers.contains(choice['paper'])))
      'papers': l10n.taxRefInvalidPapers,
  };
}

/// The `country` value the form's fields and choices stand for.
CountryValue countryValueOf(FormControllers fields, Map<String, String> choice) => CountryValue(
  currency: fields.text('currency').toUpperCase(),
  timeZone: fields.text('time_zone').trim(),
  bankingScheme: choice['banking_scheme']!,
  position: int.tryParse(fields.text('position')) ?? 0,
  // #3852 -- A4 is what an absent paper means; an empty list, both papers.
  paper: choice['paper'] == Paper.a4.wire ? null : choice['paper'],
  papers: _papersOf(fields).isEmpty ? null : _papersOf(fields),
);
