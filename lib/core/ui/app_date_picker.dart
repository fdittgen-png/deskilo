// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbols.dart';
import 'package:intl/intl.dart';

import '../i18n/app_format.dart';
import '../i18n/format_controller.dart';
import '../i18n/week_start.dart';

/// #3648 — THE date picker of the app: the one place `showDatePicker` and
/// `showDateRangePicker` are called (a lint refuses them anywhere else).
///
/// The framework's pickers take their first column from the interface
/// language's `MaterialLocalizations.firstDayOfWeekIndex` and have no
/// parameter for it, so a picker and the grid beside it disagreed. Here the
/// picker reads the reader's week (`weekStartOf`: the format locale's, or the
/// day they chose) through a narrow adapter, [_WeekStartLocalizationsDelegate]:
/// the interface language's own strings and date syntax, with ONE value
/// replaced. The day a person taps is the day returned, in any week.
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  AppFormat? format,
  String? helpText,
}) =>
    showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: helpText,
      builder: _weekStartBuilder(format ?? appFormatOf(context)),
    );

/// The range variant of [showAppDatePicker].
Future<DateTimeRange?> showAppDateRangePicker({
  required BuildContext context,
  required DateTime firstDate,
  required DateTime lastDate,
  AppFormat? format,
  DateTimeRange? initialDateRange,
}) =>
    showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: initialDateRange,
      builder: _weekStartBuilder(format ?? appFormatOf(context)),
    );

/// The picker builder that puts [format]'s week under a framework picker.
TransitionBuilder _weekStartBuilder(AppFormat format) {
  final delegate = _WeekStartLocalizationsDelegate(weekStartOf(format));
  return (context, child) => Localizations.override(
        context: context,
        delegates: [delegate],
        child: child,
      );
}

/// Loads the interface language's [MaterialLocalizations] with the first day
/// of the week replaced by [firstWeekday] (an ISO weekday).
class _WeekStartLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _WeekStartLocalizationsDelegate(this.firstWeekday);

  final int firstWeekday;

  @override
  bool isSupported(Locale locale) =>
      GlobalMaterialLocalizations.delegate.isSupported(locale);

  @override
  Future<MaterialLocalizations> load(Locale locale) async {
    final base = await GlobalMaterialLocalizations.delegate.load(locale);
    final name = _intlName(locale);
    if (name == null) return base;
    final translation = getMaterialTranslation(
      locale,
      DateFormat.y(name),
      DateFormat.yMd(name),
      DateFormat.yMMMd(name),
      DateFormat.MMMEd(name),
      _WeekStartDateFormat(DateFormat.yMMMMEEEEd(name), firstWeekday),
      DateFormat.yMMMM(name),
      DateFormat.MMMd(name),
      NumberFormat.decimalPattern(name),
      NumberFormat('00', name),
    );
    return translation ?? base;
  }

  /// The locale name `intl` formats it under, as the framework's own delegate
  /// resolves it; null when `intl` knows neither the tag nor the language.
  static String? _intlName(Locale locale) {
    final tag = Intl.canonicalizedLocale(locale.toString());
    if (DateFormat.localeExists(tag) && NumberFormat.localeExists(tag)) {
      return tag;
    }
    final language = locale.languageCode;
    return DateFormat.localeExists(language) &&
            NumberFormat.localeExists(language)
        ? language
        : null;
  }

  @override
  bool shouldReload(_WeekStartLocalizationsDelegate old) =>
      old.firstWeekday != firstWeekday;
}

/// The one date format the framework reads the first day of the week from
/// (`GlobalMaterialLocalizations.firstDayOfWeekIndex` and its narrow names
/// come from the symbols of its full-date format): [of] unchanged, except
/// that its symbols start the week on [firstWeekday]. `intl` counts the first
/// day from Monday = 0, ISO weekdays from Monday = 1: normalised right here.
class _WeekStartDateFormat extends DateFormat {
  _WeekStartDateFormat(DateFormat of, int firstWeekday)
      : _symbols = _startingOn(of.dateSymbols, firstWeekday),
        super(of.pattern, of.locale);

  final DateSymbols _symbols;

  @override
  DateSymbols get dateSymbols => _symbols;

  static DateSymbols _startingOn(DateSymbols s, int firstWeekday) => DateSymbols(
        NAME: s.NAME,
        ERAS: s.ERAS,
        ERANAMES: s.ERANAMES,
        NARROWMONTHS: s.NARROWMONTHS,
        STANDALONENARROWMONTHS: s.STANDALONENARROWMONTHS,
        MONTHS: s.MONTHS,
        STANDALONEMONTHS: s.STANDALONEMONTHS,
        SHORTMONTHS: s.SHORTMONTHS,
        STANDALONESHORTMONTHS: s.STANDALONESHORTMONTHS,
        WEEKDAYS: s.WEEKDAYS,
        STANDALONEWEEKDAYS: s.STANDALONEWEEKDAYS,
        SHORTWEEKDAYS: s.SHORTWEEKDAYS,
        STANDALONESHORTWEEKDAYS: s.STANDALONESHORTWEEKDAYS,
        NARROWWEEKDAYS: s.NARROWWEEKDAYS,
        STANDALONENARROWWEEKDAYS: s.STANDALONENARROWWEEKDAYS,
        SHORTQUARTERS: s.SHORTQUARTERS,
        QUARTERS: s.QUARTERS,
        AMPMS: s.AMPMS,
        ZERODIGIT: s.ZERODIGIT,
        DATEFORMATS: s.DATEFORMATS,
        TIMEFORMATS: s.TIMEFORMATS,
        AVAILABLEFORMATS: s.AVAILABLEFORMATS,
        FIRSTDAYOFWEEK: (firstWeekday - 1) % 7,
        WEEKENDRANGE: s.WEEKENDRANGE,
        FIRSTWEEKCUTOFFDAY: s.FIRSTWEEKCUTOFFDAY,
        DATETIMEFORMATS: s.DATETIMEFORMATS,
      );
}
