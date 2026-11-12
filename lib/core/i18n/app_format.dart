// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../format/amount_input.dart';
import '../format/cents.dart';
import '../format/decimal_input.dart';
import '../settings/setting_defaults.g.dart';
import '../time/workspace_time.dart';
import 'format_prefs.dart';
import 'money_format.dart';

/// THE formatting seam (#711): every number, amount, date and time a
/// member reads goes through here, in THEIR format locale, with the
/// WORKSPACE's currency and clock.
///
/// Pure: takes what it needs, touches nothing global. The one global —
/// `Intl.defaultLocale` — is set by [FormatController] when the locale
/// resolves, so the two dozen `DateFormat.MMMd()` calls the app grew
/// before this seam existed stop formatting in `en_US` (#701). New code
/// should call this rather than relying on that.
class AppFormat {
  const AppFormat({
    required this.locale,
    required this.currencyCode,
    this.clock = ClockPref.auto,
    this.timeZoneMode = TimeZoneMode.workspace,
    this.weekStart = WeekStartPref.locale,
  });

  /// The resolved format locale, e.g. `fr_CH`.
  final String locale;

  /// The WORKSPACE's ISO 4217 code — never the member's.
  final String currencyCode;

  final ClockPref clock;
  final TimeZoneMode timeZoneMode;

  /// #3648 — the chosen first day of the week; read it through
  /// `weekStartOf` (`week_start.dart`), which resolves the locale's own.
  final WeekStartPref weekStart;

  /// Whatever the tests and the pre-#711 app always assumed, except the
  /// currency: no business, no currency (#3658), so its amounts read
  /// "Currency unavailable".
  static const fallback = AppFormat(
    locale: SettingDefaults.localeDefaultLocale,
    currencyCode: '',
  );

  // ── money ────────────────────────────────────────────────────────

  /// A stored minor-unit amount as the reader's currency string:
  /// 123456 EUR → `1 234,56 €` in `fr_FR`, `€1,234.56` in `en_US`,
  /// `CHF 1'234.56` in `de_CH`; 1250 JPY → `￥1,250`, never `￥12.50`.
  String money(int minor, {String? currency}) {
    final code = currency ?? currencyCode;
    if (!isCurrencyCode(code)) return currencyUnavailableText(locale);
    final symbol = _symbol(code);
    return spaceAlphabeticSymbol(
      NumberFormat.currency(
        locale: locale,
        name: code,
        symbol: symbol,
        decimalDigits: Currencies.minorDigits(code),
      ).format(Currencies.toMajor(minor, code)),
      symbol,
    );
  }

  /// A compact money string for chips and badges: whole amounts drop
  /// their decimals (`12 €`, not `12,00 €`).
  String moneyCompact(int minor, {String? currency}) {
    final code = currency ?? currencyCode;
    if (!isCurrencyCode(code)) return currencyUnavailableText(locale);
    final digits = Currencies.minorDigits(code);
    final whole = digits > 0 && minor % Currencies.minorPerMajor(code) == 0;
    final symbol = _symbol(code);
    return spaceAlphabeticSymbol(
      NumberFormat.currency(
        locale: locale,
        name: code,
        symbol: symbol,
        decimalDigits: whole ? 0 : digits,
      ).format(Currencies.toMajor(minor, code)),
      symbol,
    );
  }

  /// #3484 — the money formatter of [code] (the workspace's when null) in the
  /// member's format locale, for a screen that formats many amounts or hands
  /// the formatter on. Documents name their own locale with `moneyFormat`.
  MoneyFormat moneyIn(String? code) =>
      moneyFormat(code ?? currencyCode, locale: locale, spaceAlphabetic: true);

  /// The money formatter of a personal surface (Me): an amount beside the
  /// amounts of other businesses, each in the currency of its own record.
  /// It names the currency without doubt (`USD 120.00` and `CAD 120.00`,
  /// never two `$120.00`: a symbol several currencies share is spelled as
  /// the code) and it never
  /// reads a missing code as the open business's currency or as the
  /// platform's default: [code] is the record's own, or nothing is shown
  /// beside the number.
  MoneyFormat moneyNamed(String code) => isCurrencyCode(code)
      ? MoneyFormat(code, locale: locale, spaceAlphabetic: true, distinct: true)
      : moneyFormat(null, locale: locale);

  /// #3484 — plain numbers in the member's format locale: `1 234,5` in
  /// fr_FR; [decimals] fixes the fraction digits.
  NumberFormat numbers({int? decimals}) => decimals == null
      ? NumberFormat.decimalPattern(locale)
      : NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: decimals);

  /// #3484 — a fraction as a percentage in the member's format locale
  /// (`0.25` → `25 %` in fr_FR); [decimals] fixes the fraction digits.
  NumberFormat percents({int? decimals}) => decimals == null
      ? NumberFormat.percentPattern(locale)
      : NumberFormat.decimalPercentPattern(locale: locale, decimalDigits: decimals);

  String _symbol(String code) =>
      NumberFormat.simpleCurrency(locale: locale, name: code).currencySymbol;

  // ── numbers ──────────────────────────────────────────────────────

  String number(num value, {int? decimals}) => decimals == null
      ? NumberFormat.decimalPattern(locale).format(value)
      : NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: decimals)
          .format(value);

  String percent(num fraction) =>
      NumberFormat.percentPattern(locale).format(fraction);

  /// #3484 — a tax rate given in percent (`20` is 20 %): '20 %', '5,5 %'
  /// (fr_FR), '7.7 %' (de_CH); a whole rate without decimals. Files print
  /// rates with `percentText` instead.
  String rate(double percent) =>
      '${NumberFormat.decimalPattern(locale).format(percent)} %';

  /// #3487 — the number a member typed, in this locale's separators
  /// (`parseDecimalInput`); [grouping] off for a rate, a weight or a
  /// quantity.
  num? parseNumber(String raw, {bool grouping = true}) =>
      parseDecimalInput(raw, locale: locale, grouping: grouping);

  /// #3487 — a typed amount in minor units (`parseMinorInput`).
  int? parseMinor(String raw) => parseMinorInput(raw, locale: locale);

  /// A typed amount of [currency] (the record's) in its minor units, or why
  /// it is refused (`readAmountInput`).
  AmountRead readAmount(
    String raw, {
    required String currency,
    required bool allowNegative,
  }) => readAmountInput(
    raw,
    locale: locale,
    currency: currency,
    allowNegative: allowNegative,
  );

  // ── dates and times ──────────────────────────────────────────────

  /// #3484 — [instant] on the wall clock the reader asked for (the
  /// workspace's, or the device's): what a screen shows, compares by day or
  /// hands to a picker. Replaces `.toLocal()` and `WorkspaceTime.display`,
  /// and keeps the latter's rule: a zone-carrying value (a workspace-anchored
  /// window is a [tz.TZDateTime]) already reads in its own wall clock and
  /// passes through — "Morning until 13:00" says 13:00 on a device hours away.
  DateTime wall(DateTime instant) =>
      instant is tz.TZDateTime ? instant : _wall(instant);

  /// #3484 — the date shape [shape] in the member's format locale. It formats
  /// the value it is given as it is: an instant goes through [wall] first, a
  /// calendar date or a wall-clock value does not.
  DateFormat dates(DateShape shape) => switch (shape) {
        DateShape.day => DateFormat.d(locale),
        DateShape.weekday => DateFormat.E(locale),
        DateShape.weekdayLong => DateFormat.EEEE(locale),
        DateShape.monthShort => DateFormat.MMM(locale),
        DateShape.month => DateFormat.MMMM(locale),
        DateShape.monthDay => DateFormat.MMMd(locale),
        DateShape.weekdayMonthDay => DateFormat.MMMEd(locale),
        DateShape.numeric => DateFormat.yMd(locale),
        DateShape.monthYearShort => DateFormat.yMMM(locale),
        DateShape.date => DateFormat.yMMMd(locale),
        DateShape.weekdayDate => DateFormat.yMMMEd(locale),
        DateShape.monthYear => DateFormat.yMMMM(locale),
        DateShape.longDate => DateFormat.yMMMMd(locale),
        DateShape.fullDate => DateFormat.yMMMMEEEEd(locale),
      };

  /// #3484 — a date shape and the time, as one label: the date of [instant]
  /// on the reader's wall clock and its time under their clock preference.
  String datesAndTime(DateShape shape, DateTime instant) =>
      '${dates(shape).format(_wall(instant))} ${time(instant)}';

  /// The wall-clock the reader asked for: the workspace's, or the
  /// device's with a zone label wherever the two differ.
  DateTime _wall(DateTime instant) => switch (timeZoneMode) {
        TimeZoneMode.workspace => WorkspaceTime.wall(instant),
        TimeZoneMode.device => instant.toLocal(),
      };

  /// `28 Aug 2026` / `28 août 2026` / `28.08.2026`.
  String date(DateTime instant) => DateFormat.yMMMd(locale).format(_wall(instant));

  /// `Fri 28 Aug` — the short form for chips and rows.
  String shortDate(DateTime instant) =>
      DateFormat.MMMEd(locale).format(_wall(instant));

  /// `Aug 28`, the calendar-chip form.
  String monthDay(DateTime instant) =>
      DateFormat.MMMd(locale).format(_wall(instant));

  /// `14:30` under a 24-hour clock, `2:30 PM` under a 12-hour one, and
  /// whatever the format region does under `auto`.
  /// #1150 — a WALL-CLOCK value that is not an instant: a ruler tick, a
  /// slot boundary built with `DateTime(y, m, d, 8)`. Applies the clock
  /// preference and nothing else; [time] would shift it by the zone.
  String wallTime(DateTime wall) => switch (clock) {
        ClockPref.h24 => DateFormat.Hm(locale).format(wall),
        ClockPref.h12 => DateFormat('h:mm a', locale).format(wall),
        ClockPref.auto => DateFormat.jm(locale).format(wall),
      };

  String time(DateTime instant) {
    final wall = _wall(instant);
    return switch (clock) {
      ClockPref.h24 => DateFormat.Hm(locale).format(wall),
      ClockPref.h12 => DateFormat('h:mm a', locale).format(wall),
      ClockPref.auto => DateFormat.jm(locale).format(wall),
    };
  }

  /// `28 Aug 2026 · 14:30`.
  String dateTime(DateTime instant) => '${date(instant)} · ${time(instant)}';

  /// The zone label a device-clock reader needs beside a time: '' when
  /// the two clocks agree, `CET` / `UTC+1` otherwise.
  String zoneSuffix(DateTime instant) {
    if (timeZoneMode == TimeZoneMode.workspace) return '';
    final device = instant.toLocal();
    final workspace = WorkspaceTime.wall(instant);
    if (device.hour == workspace.hour && device.minute == workspace.minute) {
      return '';
    }
    return device.timeZoneName;
  }

  AppFormat copyWith({
    String? locale,
    String? currencyCode,
    ClockPref? clock,
    TimeZoneMode? timeZoneMode,
    WeekStartPref? weekStart,
  }) =>
      AppFormat(
        locale: locale ?? this.locale,
        currencyCode: currencyCode ?? this.currencyCode,
        clock: clock ?? this.clock,
        timeZoneMode: timeZoneMode ?? this.timeZoneMode,
        weekStart: weekStart ?? this.weekStart,
      );
}

/// The format locales a member may pick: each UI language paired with
/// the regions that spell its numbers and dates differently. Ordered so
/// the picker groups by language.
///
/// Not every BCP-47 tag on earth — intl ships symbols for these, and a
/// tag it does not know silently falls back to the root locale, which
/// is `en_US` wearing a different name.
const List<String> kFormatLocales = [
  'de_DE', 'de_AT', 'de_CH',
  'en_GB', 'en_US', 'en_CA', 'en_IE', 'en_AU',
  'es_ES', 'es_MX',
  'fr_FR', 'fr_BE', 'fr_CA', 'fr_CH',
  'it_IT', 'it_CH',
  'nl_NL', 'nl_BE', 'pt_PT', 'pl_PL', 'sv_SE', 'da_DK', 'nb_NO', 'fi_FI',
  'cs_CZ', 'hu_HU', 'ro_RO', 'el_GR', 'ja_JP',
];

/// Where `intl` has no pairing of a language with a region, the pairing that
/// reads closest to that region: Spanish in the United States or any
/// Latin-American country keeps the Americas' number and date conventions
/// (`es_MX`), not Spain's. Every other missing pairing falls to the
/// language's home region (its first [kFormatLocales] entry).
const Map<String, String> _closestPairing = {'es': 'es_MX'};

/// The regions (ISO 3166 codes) that take [_closestPairing]'s Spanish: the
/// Americas, where numbers and dates follow Mexico's usage.
const Set<String> _americasRegions = {
  'US', 'CA', 'MX', 'AR', 'CL', 'CO', 'PE', 'VE', 'EC', 'UY', 'PY', 'BO',
  'CR', 'PA', 'DO', 'GT', 'HN', 'NI', 'SV', 'PR', 'CU',
};

/// The one decision of a format locale nobody chose: its LANGUAGE is the
/// language the app is shown in, its REGION is the device's on a personal
/// surface or the business's on a business screen. The pairing is the exact
/// one when [kFormatLocales] has it (`fr` + CA → `fr_CA`, `en` + US →
/// `en_US`), else the closest listed for that region, else the language's
/// home region; a language the list does not know reads `en_GB`. English in
/// a country `intl` has no English pairing for (Switzerland, Poland, Spain …)
/// reads `en_GB`: English month names, a day-first order.
String defaultFormatLocale(String language, String region) {
  final upper = region.toUpperCase();
  final candidate = '${language}_$upper';
  if (kFormatLocales.contains(candidate)) return candidate;
  final closest = _closestPairing[language];
  if (closest != null && _americasRegions.contains(upper)) return closest;
  return kFormatLocales.firstWhere(
    (l) => l.startsWith('${language}_'),
    orElse: () => 'en_GB',
  );
}

/// #3484 — the date shapes the screens use; each names its ICU skeleton
/// (`date` is `yMMMd`: `28 Aug 2026` in en, `28 août 2026` in fr).
enum DateShape {
  day,
  weekday,
  weekdayLong,
  monthShort,
  month,
  monthDay,
  weekdayMonthDay,
  numeric,
  monthYearShort,
  date,
  weekdayDate,
  monthYear,
  longDate,
  fullDate,
}
