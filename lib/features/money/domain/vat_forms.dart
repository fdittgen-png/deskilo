// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2357 — a country's VAT return form, as DATA: which declaration lines
// each box adds up, which boxes are totals of others, and how the form
// rounds (the French CA3 in whole euros, half up; the German UStVA bases
// in whole euros, cut in the declarant's favour; the UK's boxes 6–9 in
// whole pounds; the rest in cents). The forms themselves, per country and
// year, are in `vat_form_catalogue.dart`; this file only knows how to
// read one.
//
// A declaration line (`VatDeclarationLine`) is the server's: a rate, a
// UNCL5305 category (S, AE, E, Z, G, O — or `asset` for the VAT on a
// fixed asset), a direction (sales or deductible VAT) and whether it
// corrects a filed return. A box selects lines by those four and adds up
// their base or their tax.
import 'vat_components.dart';
import 'vat_declaration.dart';

/// How a form rounds an amount kept in cents.
enum VatRounding {
  /// To the cent, as computed.
  cents,

  /// To the whole unit, half away from zero (FR CA3, CA line 101).
  wholeHalfUp,

  /// To the whole unit, the cents dropped (DE UStVA bases, UK boxes 6–9).
  wholeDown;

  int apply(int cents) => switch (this) {
    VatRounding.cents => cents,
    VatRounding.wholeHalfUp => cents.sign * ((cents.abs() + 50) ~/ 100) * 100,
    VatRounding.wholeDown => cents.sign * (cents.abs() ~/ 100) * 100,
  };
}

/// Which declaration lines a box adds up.
class VatLineSelector {
  const VatLineSelector({
    this.input = false,
    this.rates,
    this.groups,
    this.excludeGroups,
    this.categories,
    this.correction,
    this.vatSign = 0,
    this.schemes,
  });

  /// #2361 — only these taxes of a line that is made of several (`GST`,
  /// `HST`, `QST`): the term then adds up the matching components, not the
  /// whole line. A line the server did not split counts as GST/HST.
  final Set<String>? schemes;

  /// Deductible VAT (true) or sales (false).
  final bool input;

  /// Only these rates; null for any.
  final Set<double>? rates;

  /// #2480 -- only lines whose fiscal group (`VatGroup.wire`) is one of
  /// these; null for any. Set from a `form_box` row, never written in code.
  final Set<String>? groups;

  /// Every group but these (FR line 14, DE Kz 35); a line whose rate is in
  /// none of the country's groups counts as "other". Null for no exclusion.
  final Set<String>? excludeGroups;

  /// Only these categories; null for any.
  final Set<String>? categories;

  /// Only corrections (true), only the period's own lines (false), or both.
  final bool? correction;

  /// Only lines whose VAT is positive (1) or negative (-1); 0 for both.
  final int vatSign;

  /// This selector, restricted by a `form_box` row.
  VatLineSelector withGroups({
    required Set<String> groups,
    required Set<String> excludeGroups,
  }) =>
      VatLineSelector(
        input: input,
        rates: rates,
        groups: groups.isEmpty ? this.groups : groups,
        excludeGroups: excludeGroups.isEmpty ? this.excludeGroups : excludeGroups,
        categories: categories,
        correction: correction,
        vatSign: vatSign,
        schemes: schemes,
      );

  /// Whether [line] is picked; [VatDeclarationLine.group] is the fiscal
  /// group the line was taxed in ('' when the rate is in none of them).
  bool matches(VatDeclarationLine line) =>
      line.isInput == input &&
      (rates == null || rates!.contains(line.percent)) &&
      (groups == null || groups!.contains(line.group)) &&
      (excludeGroups == null || !excludeGroups!.contains(line.group)) &&
      (categories == null || categories!.contains(_category(line))) &&
      (correction == null || line.isCorrection == correction) &&
      (vatSign == 0 || line.vatCents.sign == vatSign);
}

/// What [line] contributes to a term: the whole base or tax, or with
/// [VatLineSelector.schemes] the part of the matching taxes. A Canadian line
/// without the server's split is split here with the same arithmetic.
int _amountOf(VatLineSelector selector, VatDeclarationLine line, bool ofTax) {
  final schemes = selector.schemes;
  if (schemes == null) return ofTax ? line.vatCents : line.netCents;
  final parts = line.components.isNotEmpty
      ? line.components
      : vatComponentsOf('CA', line.percent, line.netCents, line.vatCents);
  if (parts.isEmpty) {
    final federal = schemes.contains('GST') || schemes.contains('HST');
    return !federal ? 0 : (ofTax ? line.vatCents : line.netCents);
  }
  var total = 0;
  for (final c in parts) {
    if (schemes.contains(c.scheme)) total += ofTax ? c.taxCents : c.baseCents;
  }
  return total;
}

/// A line's category, a zero-rate line an older client stored without one
/// read as outside the scope.
String _category(VatDeclarationLine line) =>
    line.category.isNotEmpty ? line.category : (line.percent > 0 ? 'S' : 'O');

/// One addend of a box: the base or the tax of the lines [selector]
/// matches, or another box's (rounded) value, times [factor].
class VatTerm {
  const VatTerm.lines(VatLineSelector this.selector, {this.factor = 1})
    : box = null,
      boxTax = false;

  /// Another box of the same form: its base, or with [tax] its tax.
  const VatTerm.box(String this.box, {bool tax = false, this.factor = 1})
    : selector = null,
      boxTax = tax;

  final VatLineSelector? selector;
  final String? box;
  final bool boxTax;
  final int factor;
}

/// One line of a form: a code, its printed label, and a base and/or a tax
/// cell — each with the key a filing file names it by.
class VatBoxSpec {
  const VatBoxSpec(
    this.code,
    this.label, {
    this.base = const [],
    this.tax = const [],
    this.baseKey = '',
    this.taxKey = '',
    this.baseRounding = VatRounding.cents,
    this.taxRounding = VatRounding.cents,
    this.always = false,
    this.clampAtZero = false,
    this.absolute = false,
    this.formBox,
  });

  /// #2480 -- the key (`<form>/<box code>`) of the `form_box` row that
  /// supplies this box's label and the groups its line terms select; null
  /// for a box with no rate selection. The box's arithmetic stays here.
  final String? formBox;

  final String code;
  final String label;
  final List<VatTerm> base;
  final List<VatTerm> tax;

  /// The cell's name in a filing file: an ELSTER Kennzahl (`Kz81`), a
  /// CA3 EDI code (`0207`), an MTD field (`vatDueSales`).
  final String baseKey;
  final String taxKey;
  final VatRounding baseRounding;
  final VatRounding taxRounding;

  /// Printed even at zero (a total, the amount due).
  final bool always;

  /// A box that only holds a positive amount (an amount due, a credit).
  final bool clampAtZero;

  /// A box that states a difference without its sign (UK box 5).
  final bool absolute;

  bool get hasBase => base.isNotEmpty;
  bool get hasTax => tax.isNotEmpty;

  /// This box with the wording and the group selection of its `form_box`.
  VatBoxSpec resolvedBy({
    required String label,
    required Set<String> groups,
    required Set<String> excludeGroups,
  }) {
    VatTerm pick(VatTerm t) => t.selector == null
        ? t
        : VatTerm.lines(
            t.selector!.withGroups(groups: groups, excludeGroups: excludeGroups),
            factor: t.factor,
          );
    return VatBoxSpec(
      code,
      label,
      base: [for (final t in base) pick(t)],
      tax: [for (final t in tax) pick(t)],
      baseKey: baseKey,
      taxKey: taxKey,
      baseRounding: baseRounding,
      taxRounding: taxRounding,
      always: always,
      clampAtZero: clampAtZero,
      absolute: absolute,
      formBox: formBox,
    );
  }
}

/// A country's return form, from the year it applies.
class VatFormSpec {
  const VatFormSpec({
    required this.country,
    required this.name,
    required this.validFrom,
    required this.boxes,
  });

  /// ISO 3166-1 alpha-2, upper case.
  final String country;

  /// 'CA3 (3310-CA3-SD)', 'UStVA', 'VAT100'…
  final String name;

  /// The first day the layout applies.
  final DateTime validFrom;
  final List<VatBoxSpec> boxes;
}

/// One filled box of a form: the rounded base and tax, in cents.
class VatFormBox {
  const VatFormBox({
    required this.code,
    required this.label,
    required this.netCents,
    required this.vatCents,
    this.hasBase = true,
    this.hasTax = true,
    this.baseKey = '',
    this.taxKey = '',
  });

  final String code;
  final String label;
  final int netCents;
  final int vatCents;
  final bool hasBase;
  final bool hasTax;
  final String baseKey;
  final String taxKey;
}

/// [spec] filled from [lines], in the form's order: a box appears when it
/// holds an amount or is [VatBoxSpec.always]. Totals read the ROUNDED
/// values of the boxes they add, as the form does.
List<VatFormBox> fillVatForm(VatFormSpec spec, List<VatDeclarationLine> lines) {
  final base = <String, int>{};
  final tax = <String, int>{};
  int sum(List<VatTerm> terms, {required bool ofTax}) {
    var total = 0;
    for (final t in terms) {
      final selector = t.selector;
      if (selector != null) {
        for (final l in lines) {
          if (selector.matches(l)) {
            total += t.factor * _amountOf(selector, l, ofTax);
          }
        }
      } else {
        final values = t.boxTax ? tax : base;
        total += t.factor * (values[t.box] ?? 0);
      }
    }
    return total;
  }

  final out = <VatFormBox>[];
  for (final box in spec.boxes) {
    var b = box.baseRounding.apply(sum(box.base, ofTax: false));
    var v = box.taxRounding.apply(sum(box.tax, ofTax: true));
    if (box.clampAtZero) {
      b = b < 0 ? 0 : b;
      v = v < 0 ? 0 : v;
    }
    if (box.absolute) {
      b = b.abs();
      v = v.abs();
    }
    base[box.code] = b;
    tax[box.code] = v;
    final empty = (!box.hasBase || b == 0) && (!box.hasTax || v == 0);
    if (empty && !box.always) continue;
    out.add(
      VatFormBox(
        code: box.code,
        label: box.label,
        netCents: box.hasBase ? b : 0,
        vatCents: box.hasTax ? v : 0,
        hasBase: box.hasBase,
        hasTax: box.hasTax,
        baseKey: box.baseKey,
        taxKey: box.taxKey,
      ),
    );
  }
  return out;
}
