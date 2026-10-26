// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2357 — INPUT VAT: the VAT a space paid on an expense and may deduct.
// An expense is entered gross (what was paid); it states the VAT rate it
// carried and the share the space may deduct (100 % unless part of it is
// private or serves an exempt activity). The return reports the tax only
// — CA3 line 20, UStVA Kz 66, UK box 4, CH 400, CA 108 — and subtracts it
// from the VAT collected. Its tax point is the day the expense was
// approved.
//
// A service bought from a supplier abroad carries no VAT of the space's
// country: the expense says so, its amount is then the base, and the space
// owes the acquisition tax on it and deducts its share (CH 383 and 400).
//
// The SQL twin is `vat_input_split` (0408), read by `vat_input_amounts`;
// `vat_return_parity_test.dart` pins both to the figures of pgTAP 170.
import 'vat_rate.dart';

/// What an expense of [grossCents] at [percent], of which [deductiblePct]
/// percent of the VAT may be deducted, puts on the return: its base
/// ([netCents], the same per-line split invoices use) and the deductible
/// VAT, rounded half away from zero.
({int netCents, int deductibleCents}) vatInputSplit(
  int grossCents,
  double percent,
  double deductiblePct,
) {
  final net = vatSplit(grossCents, percent).netCents;
  final full = grossCents - net;
  final share = deductiblePct.clamp(0, 100);
  return (netCents: net, deductibleCents: (full * share / 100).round());
}

/// What an expense of [netCents] bought from a supplier abroad at
/// [percent] owes and deducts (CH Bezugsteuer, art. 45 MWSTG): the
/// acquisition tax on the amount, which is the base, and the [deductiblePct]
/// share of it the space may deduct, each rounded half away from zero. The
/// SQL twin is `vat_acquisition_split`.
({int taxCents, int deductibleCents}) vatAcquisitionSplit(
  int netCents,
  double percent,
  double deductiblePct,
) {
  // In integers, as the database's numerics compute it: the rate in
  // thousandths of a percent is exact for every rate the app knows.
  final rate = (percent * _thousandths).round();
  final product = netCents * rate;
  const whole = 100 * _thousandths;
  final tax = product.sign * ((product.abs() + whole ~/ 2) ~/ whole);
  final share = deductiblePct.clamp(0, 100);
  return (taxCents: tax, deductibleCents: (tax * share / 100).round());
}

/// A rate counted in thousandths of a percent (14.975 % is 14975).
const _thousandths = 1000;
