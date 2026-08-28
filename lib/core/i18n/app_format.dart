// SPDX-License-Identifier: 0BSD
import 'package:intl/intl.dart';

import '../time/workspace_time.dart';
import 'currencies.dart';
import 'format_prefs.dart';

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
  });

  /// The resolved format locale, e.g. `fr_CH`.
  final String locale;

  /// The WORKSPACE's ISO 4217 code — never the member's.
  final String currencyCode;

  final ClockPref clock;
  final TimeZoneMode timeZoneMode;

  /// Whatever the tests and the pre-#711 app always assumed.
  static const fallback = AppFormat(locale: 'en_US', currencyCode: 'EUR');

  // ── money ────────────────────────────────────────────────────────

  /// A stored minor-unit amount as the reader's currency string:
  /// 123456 EUR → `1 234,56 €` in `fr_FR`, `€1,234.56` in `en_US`,
  /// `CHF 1'234.56` in `de_CH`; 1250 JPY → `￥1,250`, never `￥12.50`.
  String money(int minor, {String? currency}) {
    final code = currency ?? currencyCode;
    return NumberFormat.currency(
      locale: locale,
      name: code,
      symbol: _symbol(code),
      decimalDigits: Currencies.minorDigits(code),
    ).format(Currencies.toMajor(minor, code));
  }

  /// A compact money string for chips and badges: whole amounts drop
  /// their decimals (`12 €`, not `12,00 €`).
  String moneyCompact(int minor, {String? currency}) {
    final code = currency ?? currencyCode;
    final digits = Currencies.minorDigits(code);
    final whole = digits > 0 && minor % Currencies.minorPerMajor(code) == 0;
    return NumberFormat.currency(
      locale: locale,
      name: code,
      symbol: _symbol(code),
      decimalDigits: whole ? 0 : digits,
    ).format(Currencies.toMajor(minor, code));
  }

  String _symbol(String code) =>
      NumberFormat.simpleCurrency(locale: locale, name: code).currencySymbol;

  // ── numbers ──────────────────────────────────────────────────────

  String number(num value, {int? decimals}) => decimals == null
      ? NumberFormat.decimalPattern(locale).format(value)
      : NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: decimals)
          .format(value);

  String percent(num fraction) =>
      NumberFormat.percentPattern(locale).format(fraction);

  // ── dates and times ──────────────────────────────────────────────

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
  String time(DateTime instant) {
    final wall = _wall(instant);
    return switch (clock) {
      ClockPref.h24 => DateFormat.Hm(locale).format(wall),
      ClockPref.h12 => DateFormat.jm('en_US').format(wall),
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
  }) =>
      AppFormat(
        locale: locale ?? this.locale,
        currencyCode: currencyCode ?? this.currencyCode,
        clock: clock ?? this.clock,
        timeZoneMode: timeZoneMode ?? this.timeZoneMode,
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

/// The default format locale for a member who set none: their UI
/// language, regionalised by the workspace's country when that pairing
/// exists (`en` + CH → `en_CH`? no such data → `en_GB`; `fr` + CA →
/// `fr_CA`), else the language's home region.
String defaultFormatLocale(String uiLanguage, String workspaceCountry) {
  final candidate = '${uiLanguage}_${workspaceCountry.toUpperCase()}';
  if (kFormatLocales.contains(candidate)) return candidate;
  return kFormatLocales.firstWhere(
    (l) => l.startsWith('${uiLanguage}_'),
    orElse: () => 'en_GB',
  );
}
