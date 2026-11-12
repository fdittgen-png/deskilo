// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3487 — the one reader of a number a member types. A keyboard under a
// German, French, Spanish or Italian locale puts `,` on its decimal key, a
// Swiss one groups with `'`, a French one with a narrow space; screens used
// to call `double.tryParse` themselves, and seven of them read `0,5` as
// nothing.
//
// The rules, in order:
//   * spaces (also no-break and narrow no-break) and apostrophes (' ’) are
//     grouping and are dropped, where grouping is allowed;
//   * one leading minus (`-` or `−`) where [allowNegative];
//   * `.` and `,` both present: the last one is the decimal separator, it
//     occurs once, the other one groups;
//   * one kind present more than once: it groups, in groups of three;
//   * one kind present once: the decimal separator, unless it is the
//     locale's grouping symbol, grouping is allowed and exactly three
//     digits follow it (`1.234` under de_DE is 1234, `1,234` under en_GB
//     too). [threeDecimals] keeps a single separator decimal even then, for
//     the amounts of a currency with three minor digits.
//   * anything else, or nothing typed: null — the caller says what blank
//     means.
import 'package:intl/intl.dart';
import 'package:intl/number_symbols_data.dart' show numberFormatSymbols;

final _groupingChars = RegExp('[   \'’]');
final _body = RegExp(r'^[0-9.,]+$');
final _groupsOfThree = RegExp(r'^[0-9]{1,3}([.,][0-9]{3})+$');

/// The decimal and grouping symbols of [locale] (the member's format locale,
/// `AppFormat.locale`), English ones for a locale the number data does not
/// know.
({String decimal, String group}) _symbolsOf(String locale) {
  final name = Intl.canonicalizedLocale(locale);
  final known = numberFormatSymbols.containsKey(name) ||
      numberFormatSymbols.containsKey(Intl.shortLocale(name));
  final symbols = NumberFormat.decimalPattern(known ? name : 'en').symbols;
  return (decimal: symbols.DECIMAL_SEP, group: symbols.GROUP_SEP);
}

/// The decimal separator of [locale], as the reader expects it typed.
String decimalSeparatorOf(String locale) => _symbolsOf(locale).decimal;

/// The number typed in [raw], or null. [grouping] off reads a percentage,
/// a weight or a quantity: one separator at most, `.` or `,`, always the
/// decimal one.
num? parseDecimalInput(
  String raw, {
  String? locale,
  bool grouping = true,
  bool allowNegative = true,
  bool threeDecimals = false,
}) {
  var text = raw.trim();
  if (grouping) text = text.replaceAll(_groupingChars, '');
  if (text.isEmpty) return null;
  var negative = false;
  if (text.startsWith('-') || text.startsWith('−')) {
    if (!allowNegative) return null;
    negative = true;
    text = text.substring(1);
  }
  if (!_body.hasMatch(text)) return null;
  if (grouping && locale == null) {
    // #3484 — grouping depends on the locale, and there is no global one to
    // fall back on: the caller names it (`AppFormat.parseNumber`).
    throw ArgumentError.notNull('locale');
  }
  final normal = grouping
      ? _grouped(text, _symbolsOf(locale!).group, threeDecimals)
      : _ungrouped(text);
  if (normal == null) return null;
  final value = double.tryParse(normal);
  if (value == null) return null;
  return negative ? -value : value;
}

String? _ungrouped(String text) {
  final separators = text.replaceAll(RegExp('[0-9]'), '');
  if (separators.length > 1) return null;
  return text.replaceAll(',', '.');
}

String? _grouped(String text, String localeGroup, bool threeDecimals) {
  final dots = '.'.allMatches(text).length;
  final commas = ','.allMatches(text).length;
  if (dots > 0 && commas > 0) {
    final decimal = text.lastIndexOf('.') > text.lastIndexOf(',') ? '.' : ',';
    final group = decimal == '.' ? ',' : '.';
    if ((decimal == '.' ? dots : commas) != 1) return null;
    final whole = text.substring(0, text.lastIndexOf(decimal));
    if (whole.contains(decimal) || !_groupsOfThree.hasMatch(whole.replaceAll(group, ','))) {
      return null;
    }
    return '${whole.replaceAll(group, '')}.${text.substring(text.lastIndexOf(decimal) + 1)}';
  }
  final count = dots + commas;
  if (count == 0) return text;
  if (count > 1) {
    return _groupsOfThree.hasMatch(text) ? text.replaceAll(RegExp('[.,]'), '') : null;
  }
  final separator = dots == 1 ? '.' : ',';
  final after = text.length - text.indexOf(separator) - 1;
  final groups = separator == localeGroup && after == 3 && !threeDecimals &&
      _groupsOfThree.hasMatch(text);
  return groups ? text.replaceAll(separator, '') : text.replaceAll(',', '.');
}
