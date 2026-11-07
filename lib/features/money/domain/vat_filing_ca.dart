// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2361 — the Canadian return as a file (see `vat_filing_files.dart`).
import '../../../core/text/csv.dart';
import '../../../core/time/date_text.dart';
import 'vat_compliance.dart';
import 'vat_declaration.dart';
import 'vat_filing_files.dart'
    show VatFilingFileException, VatFilingFileProblem;

/// #2361 — the Canadian return as one CSV: `return, business_number,
/// period_start, period_end, line, label, base, tax`, the GST34 lines then
/// the FPZ-500 QST lines. Amounts in dollars and cents, a line-101 base in
/// whole dollars as the form takes it. The quick-method flag is not a
/// column: the remittance of that method is the CRA's own calculation.
String gstQstReturnCsv({
  required VatDeclaration declaration,
  required String businessNumber,
}) {
  if (!isValidCanadianBn(businessNumber)) {
    throw const VatFilingFileException(VatFilingFileProblem.businessNumber);
  }
  final bn = formatCanadianRegistration(businessNumber);
  final rows = <List<String>>[
    [
      'return',
      'business_number',
      'period_start',
      'period_end',
      'line',
      'label',
      'base',
      'tax',
    ],
  ];
  void section(String name, List<VatFormBox> boxes) {
    for (final box in boxes) {
      rows.add([
        name,
        bn,
        isoDay(declaration.periodStart),
        isoDay(declaration.periodEnd),
        box.code,
        box.label,
        if (box.hasBase) _dollars(box.netCents) else '',
        if (box.hasTax) _dollars(box.vatCents) else '',
      ]);
    }
  }

  section(
    'GST34',
    vatFormBoxes('CA', declaration.lines, periodEnd: declaration.periodEnd),
  );
  section('FPZ-500', vatQstFormBoxes(declaration.lines));
  return rows
      .map(
        (r) => [
          for (final (i, cell) in r.indexed)
            // base and tax are numbers: never quoted, never apostrophed
            if (i >= 6) cell else csvCell(cell),
        ].join(','),
      )
      .map((r) => '$r\r\n')
      .join();
}

/// Dollars with cents and a dot: `-12.05`.
String _dollars(int cents) {
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  return '$sign${abs ~/ 100}.${twoDigits(abs % 100)}';
}
