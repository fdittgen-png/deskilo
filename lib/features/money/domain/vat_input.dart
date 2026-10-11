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
