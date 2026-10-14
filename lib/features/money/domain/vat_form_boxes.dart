// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2480 (C4 of #2476) -- a return form's rated boxes take their wording and
// the fiscal groups they add up from `form_box` rows of the tax reference
// store, never from a percent written in code. Two questions are answered
// here: which version of a box's row applies to a period, and which fiscal
// group a declaration line was taxed in (from the rate rows, the same ones the
// workspace's rates are seeded from). The box STRUCTURE -- which boxes exist
// and how they total -- stays in the form's code.
import '../../../core/time/date_text.dart';
import '../../../core/vat/tax_reference.dart';
import '../../../core/vat/tax_reference_active.dart';
import 'vat_declaration.dart';
import 'vat_forms.dart';

/// The version of the `form_box` row [key] of [country] that applies to a
/// period ending [periodEnd]: the latest one valid from on or before it, the
/// earliest for an older period (as a form's layout is chosen). A change of
/// a box takes effect from its date, so a period already filed keeps reading
/// the version it was filed under.
FormBoxValue? _formBoxFor(
  TaxReferenceSet reference,
  String country,
  String key,
  DateTime periodEnd,
) {
  final versions = reference.history(TaxDomain.formBox, country, key);
  if (versions.isEmpty) return null;
  final day = isoDay(periodEnd);
  final row = versions.firstWhere(
    (r) => r.validFrom.compareTo(day) <= 0,
    orElse: () => versions.last,
  );
  return row.value as FormBoxValue;
}

/// [form] with the label and the group selection of each rated box read from
/// [reference] for a period ending [periodEnd]. A rated box without a row is
/// a defect of the data, and fails loudly rather than printing a blank box.
VatFormSpec resolveFormBoxes(
  VatFormSpec form,
  TaxReferenceSet reference,
  DateTime periodEnd,
) => VatFormSpec(
  country: form.country,
  name: form.name,
  validFrom: form.validFrom,
  boxes: [
    for (final box in form.boxes)
      if (box.formBox == null)
        box
      else
        _resolved(box, form.country, reference, periodEnd),
  ],
);

VatBoxSpec _resolved(
  VatBoxSpec box,
  String country,
  TaxReferenceSet reference,
  DateTime periodEnd,
) {
  final value = _formBoxFor(reference, country, box.formBox!, periodEnd);
  if (value == null) {
    throw TaxReferenceUnavailable(
      'no form_box row "${box.formBox}" for $country',
    );
  }
  return box.resolvedBy(
    label: value.label,
    groups: value.groups.toSet(),
    excludeGroups: value.excludeGroups.toSet(),
  );
}

/// The fiscal group a declaration line of [country] was taxed in, read from
/// the country's `rate` rows: the version in force on [periodEnd] first, any
/// earlier or later version after it (a period that straddles a change of
/// rate holds lines of both). Null where no rate row has the line's rate and
/// category -- the line then belongs to no named group.
String Function(VatDeclarationLine) lineGroupsFor(
  TaxReferenceSet reference,
  String country,
  DateTime periodEnd,
) {
  final day = isoDay(periodEnd);
  final cache = <String, String>{};
  return (line) => cache.putIfAbsent(
        '${line.percent}|${line.category}',
        () => reference.groupOfRate(
          country,
          line.percent,
          line.category.isNotEmpty ? line.category : (line.percent > 0 ? 'S' : 'O'),
          asOf: day,
        ),
      );
}
