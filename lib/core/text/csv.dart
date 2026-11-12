// SPDX-License-Identifier: AGPL-3.0-or-later

/// One CSV cell writer for every file the app exports (#2385). It lives in the
/// standards package since #3333 (the country add-ons share ONE copy); this
/// library keeps the application's callers where they were.
library;

import 'package:deskilo_money_kernel/deskilo_money_kernel.dart'
    show Currencies;

export 'package:deskilo_jurisdiction_standards/deskilo_jurisdiction_standards.dart'
    show CsvDialect, csvCell;

/// [minor] units of [currency] as a plain decimal number (`-12.50`), in
/// the currency's own exponent, never a universal /100: the one way an
/// exported CSV writes an amount.
String csvAmount(int minor, String currency) {
  final digits = Currencies.minorDigits(currency);
  if (digits == 0) return '$minor';
  final sign = minor < 0 ? '-' : '';
  final text = minor.abs().toString().padLeft(digits + 1, '0');
  final cut = text.length - digits;
  return '$sign${text.substring(0, cut)}.${text.substring(cut)}';
}
