// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2357 — the VAT return forms the app fills, per country and per year
// they apply from. Labels are the forms' own words, in the form's own
// language (a translated box name is the wrong box); keys are the names a
// filing file uses for each cell.
//
//  * FR — CA3 (3310-CA3-SD), whole euros, half up. Sales by rate on lines
//    08/09/9B/11/14 and by category on E1 (exports, ex-line 04) and E2
//    (other non-taxable: intra-EU services, exempt, ex-line 05);
//    deductible VAT on 19 (fixed assets) and 20 (other goods and
//    services). A correction in the Treasury's favour adds to its rate
//    line (output) or to line 15 (input VAT to pay back); one in the
//    declarant's favour goes to line 21. Lines 16, 23, 25 and 28 total.
//  * DE — UStVA, bases in whole euros cut in the declarant's favour, tax
//    in cents. Kz 81/86 by rate, Kz 35/36 other rates; Kz 21 (B2B services
//    taxed in another member state), Kz 45 (other supplies not taxable
//    here), Kz 43 (tax-free with input-tax deduction), Kz 48 (tax-free
//    without), Kz 66 input tax, Kz 83 the advance payment. A correction
//    (§ 17 UStG) lands on the boxes of the period of the change.
//  * GB — VAT100 / MTD: boxes 1–5 in pence, 6–9 in whole pounds dropped.
//  * CH — MWST (effective method), from the 2024 rates: 200–299 turnover,
//    303/313/343 by rate, 400/405 input tax, 500/510 due or credit.
//  * CA — GST/HST (GST34): line 101 in whole dollars, the tax lines in
//    cents; corrections on 104 (adds) and 107 (deducts).
//  * ES — Modelo 303: 01–09 by rate, 28–31 deductible VAT (current, fixed
//    assets), 27/45/46 totals, 59/60/120 by category.
//  * IT — LIPE quadro VP: VP2–VP6.
// Any other country gets a per-rate listing.
//
// A form that changes in a later year gets a second entry with that
// year's [VatFormSpec.validFrom]; `vatFormSpecFor` picks by period.
import 'package:meta/meta.dart';

import 'vat_declaration.dart';
import 'vat_forms.dart';

part 'vat_form_catalogue/ca.dart';
part 'vat_form_catalogue/ch.dart';
part 'vat_form_catalogue/de.dart';
part 'vat_form_catalogue/es.dart';
part 'vat_form_catalogue/fr.dart';
part 'vat_form_catalogue/gb.dart';
part 'vat_form_catalogue/it.dart';

const _taxable = {'S'};
const _asset = {'asset'};

VatTerm _sales({
  Set<double>? rates,
  Set<double>? otherRatesThan,
  Set<String>? categories = _taxable,
  bool? correction,
  int vatSign = 0,
  int factor = 1,
  Set<String>? schemes,
}) => VatTerm.lines(
  VatLineSelector(
    rates: rates,
    otherRatesThan: otherRatesThan,
    categories: categories,
    correction: correction,
    vatSign: vatSign,
    schemes: schemes,
  ),
  factor: factor,
);

VatTerm _input({
  Set<String>? categories,
  bool? correction,
  int vatSign = 0,
  int factor = 1,
  Set<String>? schemes,
}) => VatTerm.lines(
  VatLineSelector(
    input: true,
    categories: categories,
    correction: correction,
    vatSign: vatSign,
    schemes: schemes,
  ),
  factor: factor,
);

const _w = VatRounding.wholeHalfUp;

/// A cell a coworking space always files as zero (UK boxes 2, 8 and 9:
/// goods moved to or from the EU).
const _nothing = VatTerm.lines(VatLineSelector(categories: <String>{}));

const _wd = VatRounding.wholeDown;

/// Every form the app fills, oldest layout first per country.
@visibleForTesting
final List<VatFormSpec> vatFormCatalogue = [
  _ca3,
  _ustva,
  _vat100,
  _mwst,
  _gst34,
  _modelo303,
  _lipe,
];

/// #2361 — Revenu Québec's FPZ-500, QST part.
VatFormSpec get qstFormSpec => _fpz500Qst;

/// The form [country] files for a period ending on [periodEnd]: the
/// latest layout already in force, the earliest one for an older period;
/// null for a country without one.
VatFormSpec? vatFormSpecFor(String country, DateTime periodEnd) {
  final code = switch (country.trim().toUpperCase()) {
    'UK' => 'GB',
    final c => c,
  };
  final forms = [
    for (final f in vatFormCatalogue)
      if (f.country == code) f,
  ]..sort((a, b) => a.validFrom.compareTo(b.validFrom));
  if (forms.isEmpty) return null;
  return forms.lastWhere(
    (f) => !f.validFrom.isAfter(periodEnd),
    orElse: () => forms.first,
  );
}

/// A country without a form in the catalogue: one box per rate of the
/// sales, and the deductible VAT.
VatFormSpec genericVatForm(List<VatDeclarationLine> lines) {
  final rates = {
    for (final l in lines)
      if (!l.isInput) l.percent,
  }.toList()..sort((a, b) => b.compareTo(a));
  return VatFormSpec(
    country: '',
    name: '',
    validFrom: DateTime(2000),
    boxes: [
      for (final r in rates)
        VatBoxSpec(
          _pct(r),
          r == 0 ? '0 % / out of scope' : 'Rate ${_pct(r)}',
          base: [
            _sales(rates: {r}, categories: null),
          ],
          tax: [
            _sales(rates: {r}, categories: null),
          ],
        ),
      VatBoxSpec('Input', 'Input VAT', base: [_input()], tax: [_input()]),
    ],
  );
}

String _pct(double percent) {
  final text = percent == percent.roundToDouble()
      ? percent.toStringAsFixed(0)
      : percent.toString();
  return '$text %';
}
