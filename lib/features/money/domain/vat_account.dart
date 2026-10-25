// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2378 — the VAT account (UK VAT Regulations 1995 reg. 32): per return
// period, the output tax due and the input tax claimed, each with the
// corrections made to earlier periods, and what is payable. It is read
// from the lines of the returns themselves (`compute_vat_return`), so the
// account and the return can never disagree: its output total is box 1
// and its input total box 4 of the VAT100.
import 'package:meta/meta.dart';

import '../../../core/money/money_text.dart';
import '../../../core/text/csv.dart';
import 'archive_bundle.dart';
import 'vat_declaration.dart';

/// One period of the VAT account.
@visibleForTesting
class VatAccountPeriod {
  const VatAccountPeriod({
    required this.start,
    required this.end,
    required this.status,
    required this.number,
    required this.currency,
    required this.outputTaxCents,
    required this.outputCorrectionCents,
    required this.inputTaxCents,
    required this.inputCorrectionCents,
  });

  final DateTime start;
  final DateTime end;

  /// The return's lifecycle (`prepared`, `filed`) and its number once filed.
  final String status;
  final String number;
  final String currency;

  /// Output tax on the period's own supplies, and corrections of earlier
  /// periods made in this return.
  final int outputTaxCents;
  final int outputCorrectionCents;

  /// Input tax claimed on the period's purchases, and its corrections.
  final int inputTaxCents;
  final int inputCorrectionCents;

  /// The VAT payable side: box 1 of the return.
  int get payableCents => outputTaxCents + outputCorrectionCents;

  /// The VAT allowable side: box 4 of the return.
  int get allowableCents => inputTaxCents + inputCorrectionCents;

  /// What the period leaves to pay (negative: to reclaim).
  int get netCents => payableCents - allowableCents;
}

/// The VAT account of [declarations]: one period per return the server
/// computed (a draft an older client wrote is not a return), oldest first.
@visibleForTesting
List<VatAccountPeriod> buildVatAccount(Iterable<VatDeclaration> declarations) {
  final periods = [
    for (final d in declarations)
      if (d.isPrepared || d.isFiled) _periodOf(d),
  ]..sort((a, b) => a.start.compareTo(b.start));
  return periods;
}

VatAccountPeriod _periodOf(VatDeclaration d) {
  int sum({required bool input, required bool correction}) => d.lines
      .where((l) => l.isInput == input && l.isCorrection == correction)
      .fold(0, (total, l) => total + l.vatCents);
  return VatAccountPeriod(
    start: d.periodStart,
    end: d.periodEnd,
    status: d.isFiled ? 'filed' : d.status,
    number: d.number,
    currency: d.currency,
    outputTaxCents: sum(input: false, correction: false),
    outputCorrectionCents: sum(input: false, correction: true),
    inputTaxCents: sum(input: true, correction: false),
    inputCorrectionCents: sum(input: true, correction: true),
  );
}

/// The VAT account as a CSV: one row per period, amounts decimal with a
/// point in the return's currency.
@visibleForTesting
String buildVatAccountCsv(List<VatAccountPeriod> periods) {
  String day(DateTime d) => d.toIso8601String().substring(0, 10);
  final buffer = StringBuffer()
    ..writeln('# VAT account: output tax and input tax per return period, '
        'corrections of earlier periods apart, read from the lines of '
        'each return')
    ..writeln([
      'period_start',
      'period_end',
      'return',
      'status',
      'currency',
      'output_tax',
      'output_corrections',
      'vat_payable',
      'input_tax',
      'input_corrections',
      'vat_allowable',
      'net_vat',
    ].join(','));
  for (final p in periods) {
    buffer.writeln([
      day(p.start),
      day(p.end),
      csvCell(p.number),
      p.status,
      csvCell(p.currency),
      minorToText(p.outputTaxCents, p.currency),
      minorToText(p.outputCorrectionCents, p.currency),
      minorToText(p.payableCents, p.currency),
      minorToText(p.inputTaxCents, p.currency),
      minorToText(p.inputCorrectionCents, p.currency),
      minorToText(p.allowableCents, p.currency),
      minorToText(p.netCents, p.currency),
    ].join(','));
  }
  return buffer.toString();
}

/// #2378 — the archive's VAT account file: the returns whose period ends in
/// [year], or nothing when the space prepared none.
Map<String, List<int>> archiveVatAccount(
  Iterable<VatDeclaration> declarations,
  int year,
) {
  final account = buildVatAccount([
    for (final d in declarations)
      if (d.periodEnd.year == year) d,
  ]);
  return {
    if (account.isNotEmpty) 'vat-account.csv': textBytes(buildVatAccountCsv(account)),
  };
}
