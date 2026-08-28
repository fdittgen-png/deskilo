// SPDX-License-Identifier: 0BSD
import 'package:intl/intl.dart';

import 'currencies.dart';

/// A currency formatter that knows its code (#711).
///
/// `NumberFormat.simpleCurrency(name:)` was called from thirty places,
/// each without a locale — so every reader got `en_US` spelling — and
/// each followed by `.format(cents / 100)`, which is only a euro's
/// arithmetic. This carries the locale from `Intl.defaultLocale` (set by
/// the format controller from the member's profile) and the currency's
/// minor digits, and offers [formatMinor] so a caller hands over what
/// it has — the stored integer — and never divides.
class MoneyFormat {
  MoneyFormat(this.code, {String? locale})
      : _format = NumberFormat.currency(
          locale: locale ?? Intl.defaultLocale,
          name: code,
          symbol: NumberFormat.simpleCurrency(
            locale: locale ?? Intl.defaultLocale,
            name: code,
          ).currencySymbol,
          decimalDigits: Currencies.minorDigits(code),
        );

  final String code;
  final NumberFormat _format;

  /// The stored minor-unit amount, spelled for the reader.
  String formatMinor(int minor) => _format.format(Currencies.toMajor(minor, code));

  /// A MAJOR-unit number — kept for callers that already hold one.
  String format(num major) => _format.format(major);

  String get currencySymbol => _format.currencySymbol;

  String get currencyName => _format.currencyName ?? code;
}

/// The one-liner the sweep replaced `NumberFormat.simpleCurrency(name:)`
/// with. Null or empty code reads as the euro, as the old call did.
MoneyFormat moneyFormat(String? code, {String? locale}) =>
    MoneyFormat((code == null || code.isEmpty) ? 'EUR' : code, locale: locale);
