// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The annual VAT summary of a country whose periodic returns add up to a
// yearly one: the Spanish Modelo 390 and the Italian dichiarazione IVA
// annuale. It is a sheet, not a filing file: the year's prepared and filed
// returns, their lines put together and read through the same boxes as the
// periodic form, which the owner or the adviser transcribes into the
// annual form (whose own numbering differs).
import '../../../core/files/xlsx.dart';
import '../../../core/i18n/currencies.dart';
import 'vat_declaration.dart';
import 'vat_form_catalogue.dart';

/// The returns of [year] that count: one per period, the filed one where
/// there is one, else the latest prepared; drafts never.
List<VatDeclaration> _returnsOfYear(
  Iterable<VatDeclaration> declarations,
  int year,
) {
  final byPeriod = <(DateTime, DateTime), VatDeclaration>{};
  for (final d in declarations) {
    if (d.periodStart.year != year || !(d.isFiled || d.isPrepared)) continue;
    final key = (d.periodStart, d.periodEnd);
    final kept = byPeriod[key];
    final better =
        kept == null ||
        (d.isFiled && !kept.isFiled) ||
        (d.isFiled == kept.isFiled && d.createdAt.isAfter(kept.createdAt));
    if (better) byPeriod[key] = d;
  }
  return byPeriod.values.toList()
    ..sort((a, b) => a.periodStart.compareTo(b.periodStart));
}

/// The summary of [year] for [country], or null where the country has no
/// annual summary or the year no return.
({String title, List<VatFormBox> boxes, String currency})? vatAnnualSummary(
  String country,
  int year,
  Iterable<VatDeclaration> declarations,
) {
  final title = vatAnnualSummaryName(country);
  if (title == null) return null;
  final returns = _returnsOfYear(declarations, year);
  if (returns.isEmpty) return null;
  return (
    title: title,
    boxes: vatFormBoxes(country, [
      for (final d in returns) ...d.lines,
    ], periodEnd: DateTime(year, 12, 31)),
    currency: returns.first.currency,
  );
}

/// The summary as a one-sheet workbook: the box, its words, base and tax
/// in the major unit of [currency]; a box without a base or a tax leaves
/// the cell empty.
List<XlsxSheet> vatAnnualSummarySheets({
  required String title,
  required List<VatFormBox> boxes,
  required List<String> header,
  required String currency,
}) {
  final perMajor = Currencies.minorPerMajor(currency);
  return [
    XlsxSheet(
      name: title,
      rows: [
        header,
        for (final b in boxes)
          [
            b.code,
            b.label,
            if (b.hasBase) XlsxAmount(b.netCents / perMajor) else null,
            if (b.hasTax) XlsxAmount(b.vatCents / perMajor) else null,
          ],
      ],
    ),
  ];
}
