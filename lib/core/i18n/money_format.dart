// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:intl/intl.dart';

import '../settings/setting_defaults.g.dart';

/// A currency formatter that knows its code (#711).
///
/// `NumberFormat.simpleCurrency(name:)` was called from thirty places,
/// each without a locale — so every reader got `en_US` spelling — and
/// each followed by `.format(cents / 100)`, which is only a euro's
/// arithmetic. This carries the locale its caller names (#3484: the
/// member's `AppFormat.locale`, or a document's) and the currency's
/// minor digits, and offers [formatMinor] so a caller hands over what
/// it has — the stored integer — and never divides.
class MoneyFormat {
  MoneyFormat(this.code, {required String? locale})
      : _format = NumberFormat.currency(
          locale: locale,
          name: code,
          symbol: NumberFormat.simpleCurrency(
            locale: locale,
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

  /// The locale it spells amounts in.
  String get locale => _format.locale;

  String get currencySymbol => _format.currencySymbol;

  String get currencyName => _format.currencyName ?? code;
}

/// The one-liner the sweep replaced `NumberFormat.simpleCurrency(name:)`
/// with. Null or empty code reads as the registry's default currency (the
/// euro until an operator changes it), as the old call read the euro.
MoneyFormat moneyFormat(String? code, {required String? locale}) =>
    MoneyFormat((code == null || code.isEmpty) ? SettingDefaults.localeDefaultCurrency : code, locale: locale);
