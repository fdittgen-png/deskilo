// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';

/// A currency formatter that knows its code (#711).
///
/// `NumberFormat.simpleCurrency(name:)` was called from thirty places,
/// each without a locale — so every reader got `en_US` spelling — and
/// each followed by `.format(cents / 100)`, which is only a euro's
/// arithmetic. This carries the locale its caller names (#3484: the
/// member's `AppFormat.locale`, or a document's) and the currency's
/// minor digits, and offers [formatMinor] so a caller hands over what
/// it has — the stored integer — and never divides.
/// #3658 — an amount whose currency is not known is incomplete, not smaller:
/// its scale itself is unknown (1 250 units are 1 250 JPY or 1.250 KWD). A
/// document, a file or a payment refuses it at its boundary with this.
class CurrencyUnavailable implements Exception {
  const CurrencyUnavailable([this.where = '']);

  /// What needed the currency, for the trace.
  final String where;

  @override
  String toString() => 'CurrencyUnavailable($where)';
}

final RegExp _isoCode = RegExp(r'^[A-Z]{3}$');

/// Whether [code] names a currency (ISO 4217's shape).
bool isCurrencyCode(String? code) => code != null && _isoCode.hasMatch(code);

/// [code] when it names a currency; [CurrencyUnavailable] otherwise.
String requireCurrency(String? code, {String where = ''}) {
  if (!isCurrencyCode(code)) throw CurrencyUnavailable(where);
  return code!;
}

/// "Currency unavailable" in [locale]'s language (English when the app has
/// none for it): what stands in place of an amount whose currency is not
/// known. The stored units are never shown as an amount.
String currencyUnavailableText(String? locale) {
  final language = (locale ?? '').split(RegExp('[_-]')).first;
  final supported = AppLocalizations.supportedLocales
      .any((l) => l.languageCode == language);
  return lookupAppLocalizations(Locale(supported ? language : 'en'))
      .moneyCurrencyUnavailable;
}

class MoneyFormat {
  MoneyFormat(
    this.code, {
    required String? locale,
    bool spaceAlphabetic = false,
    bool distinct = false,
  }) : _unavailable = null,
       // A code standing in for a shared symbol reads `USD 100.00`, never
       // `USD100.00` (#3851).
       spaceAlphabetic = spaceAlphabetic || distinct,
       _format = NumberFormat.currency(
          locale: locale,
          name: code,
          symbol: distinct
              ? _distinctSymbol(code, locale: locale)
              : NumberFormat.simpleCurrency(
                  locale: locale,
                  name: code,
                ).currencySymbol,
          decimalDigits: Currencies.minorDigits(code),
        );

  /// #3658 — the formatter of an amount whose currency is not known: every
  /// amount reads [text] ("Currency unavailable"), never a number.
  MoneyFormat.unavailable({required String text, required String? locale})
    : code = '',
      spaceAlphabetic = false,
      _unavailable = text,
      _format = NumberFormat.decimalPattern(locale);

  final String code;
  final NumberFormat _format;
  final String? _unavailable;

  /// Whether the currency is unknown: amounts read "Currency unavailable".
  bool get unavailable => _unavailable != null;

  /// #3591 -- on a screen, an alphabetic symbol (CHF, PLN) is set off from the
  /// number by a no-break space (`CHF 95.00`, `95,00 CHF`). Documents and
  /// exports leave this off: their bytes are pinned.
  final bool spaceAlphabetic;

  /// The stored minor-unit amount, spelled for the reader.
  String formatMinor(int minor) => _unavailable ?? _spaced(
        _format.format(Currencies.toMajor(minor, code)),
        _format.currencySymbol,
        spaceAlphabetic: spaceAlphabetic,
      );

  /// A MAJOR-unit number — kept for callers that already hold one.
  String format(num major) => _unavailable ?? _spaced(
        _format.format(major),
        _format.currencySymbol,
        spaceAlphabetic: spaceAlphabetic,
      );

  /// The locale it spells amounts in.
  String get locale => _format.locale;

  String get currencySymbol => _unavailable == null ? _format.currencySymbol : '';

  String get currencyName =>
      _unavailable == null ? (_format.currencyName ?? code) : '';
}

final RegExp _alphabetic = RegExp(r'^[A-Za-z]{3}$');

/// [formatted] with an alphabetic [symbol] (three letters, no glyph) set off
/// from the number by one no-break space, on the side the locale put it;
/// a glyph symbol (€, £, $) and everything else stays as the locale spelled
/// it. Only when [spaceAlphabetic].
String _spaced(String formatted, String symbol, {required bool spaceAlphabetic}) {
  // No symbol at all (a record that names no currency): the number alone,
  // without the gap the locale left for one.
  if (symbol.isEmpty) return formatted.trim();
  if (!spaceAlphabetic || !_alphabetic.hasMatch(symbol)) return formatted;
  final at = formatted.indexOf(symbol);
  if (at < 0) return formatted;
  final before = formatted.substring(0, at);
  final after = formatted.substring(at + symbol.length);
  // Leading: nothing but a sign before it.
  if (before.replaceAll(RegExp(r'[-\u2212+\s]'), '').isEmpty) {
    return '$before$symbol\u00A0${after.trimLeft()}';
  }
  return '${before.trimRight()}\u00A0$symbol$after';
}

/// [formatted] spaced as a screen shows it (#3591): for the callers that
/// build their own `NumberFormat`.
String spaceAlphabeticSymbol(String formatted, String symbol) =>
    _spaced(formatted, symbol, spaceAlphabetic: true);

/// The symbol that names [code] beside amounts of other currencies: what a
/// personal surface shows, where the documents of businesses in different
/// countries sit in one list. A dollar sign is the symbol of seven of the
/// currencies a business may pick, `kr` of four and `¥` of two, so
/// `$120.00` from a studio in Toronto and from a desk in Austin read as the
/// same money. A symbol another selectable currency shares, and any code
/// the kernel does not list, is spelled as its ISO code; a symbol only one
/// currency carries (`€`, `£`, `zł`) stays. Never the reader's own
/// currency as an exception: which dollar is "theirs" follows the format
/// locale, and that follows the business they last opened.
String _distinctSymbol(String code, {required String? locale}) =>
    _distinctSymbols.putIfAbsent((locale, code), () {
      if (!Currencies.selectable.contains(code)) return code;
      String narrow(String c) =>
          NumberFormat.simpleCurrency(locale: locale, name: c).currencySymbol;
      final own = narrow(code);
      final shared = Currencies.selectable.any(
        (other) => other != code && narrow(other) == own,
      );
      return shared ? code : own;
    });

final Map<(String?, String), String> _distinctSymbols = {};

/// The one-liner the sweep replaced `NumberFormat.simpleCurrency(name:)`
/// with. [distinct] (#3851): a symbol another selectable currency shares is
/// spelled as the ISO code -- what a printed document uses. #3658: a missing or malformed code is not read as any currency —
/// every amount then reads "Currency unavailable".
MoneyFormat moneyFormat(
  String? code, {
  required String? locale,
  bool spaceAlphabetic = false,
  bool distinct = false,
}) =>
    isCurrencyCode(code)
        ? MoneyFormat(
            code!,
            locale: locale,
            spaceAlphabetic: spaceAlphabetic,
            distinct: distinct,
          )
        : MoneyFormat.unavailable(
            text: currencyUnavailableText(locale),
            locale: locale,
          );

/// #3851 -- the formatter of a printed document: a symbol another currency
/// shares is spelled as the ISO code, on every amount.
MoneyFormat documentMoneyFormat(String? code, {required String? locale}) =>
    moneyFormat(code, locale: locale, distinct: true);

/// #3851 -- a document's `total` and `currency` placeholders: the amount and
/// the ISO code beside it (empty when the code is unknown).
Map<String, Object?> documentTotalData(
  String? code,
  MoneyFormat format,
  int minor,
) => {
  'total': format.formatMinor(minor),
  'currency': isCurrencyCode(code) ? code : '',
};
