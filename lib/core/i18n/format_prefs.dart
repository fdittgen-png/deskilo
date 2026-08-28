// SPDX-License-Identifier: 0BSD

/// How a member wants to READ what the workspace shows them (#711).
///
/// THE WORKSPACE OWNS THE MONEY AND THE CLOCK; THE MEMBER OWNS HOW THEY
/// READ THEM. A Paris coworking bills in euros and opens at 09:00 Paris
/// time — that is not negotiable per member. But whether 1 234,56 € or
/// €1,234.56, whether 14:30 or 2:30 PM, and whether a booking at 09:00
/// Paris shows as 09:00 or as the 03:00 it is in Montréal — those are
/// the reader's, and the app used to decide them for everyone with
/// `en_US` and the device clock.
///
/// Stored on the PROFILE (0132), not on the device: a preference that
/// followed the phone and not the person is one you set three times.
class FormatPrefs {
  const FormatPrefs({
    this.formatLocale = '',
    this.clock = ClockPref.auto,
    this.timeZoneMode = TimeZoneMode.workspace,
  });

  /// A BCP-47 tag for numbers and dates — `fr_CH`, `en_GB`, `de_AT` —
  /// or '' to derive one from the UI language and the workspace's
  /// country. Independent of the UI language on purpose: an English
  /// speaker in Switzerland reads `1'234.56` and `28.08.2026`.
  final String formatLocale;

  final ClockPref clock;

  final TimeZoneMode timeZoneMode;

  static const defaults = FormatPrefs();

  factory FormatPrefs.fromDb(Map<String, dynamic> db) => FormatPrefs(
        formatLocale: db['format_locale'] as String? ?? '',
        clock: ClockPref.fromWire(db['clock'] as String?),
        timeZoneMode: TimeZoneMode.fromWire(db['time_zone_mode'] as String?),
      );

  Map<String, dynamic> toDb() => {
        'format_locale': formatLocale,
        'clock': clock.wire,
        'time_zone_mode': timeZoneMode.wire,
      };

  FormatPrefs copyWith({
    String? formatLocale,
    ClockPref? clock,
    TimeZoneMode? timeZoneMode,
  }) =>
      FormatPrefs(
        formatLocale: formatLocale ?? this.formatLocale,
        clock: clock ?? this.clock,
        timeZoneMode: timeZoneMode ?? this.timeZoneMode,
      );

  @override
  bool operator ==(Object other) =>
      other is FormatPrefs &&
      other.formatLocale == formatLocale &&
      other.clock == clock &&
      other.timeZoneMode == timeZoneMode;

  @override
  int get hashCode => Object.hash(formatLocale, clock, timeZoneMode);
}

/// 24-hour, 12-hour, or whatever the format region prefers.
enum ClockPref {
  auto('auto'),
  h24('24h'),
  h12('12h');

  const ClockPref(this.wire);
  final String wire;

  static ClockPref fromWire(String? wire) =>
      values.where((c) => c.wire == wire).firstOrNull ?? auto;
}

/// Which clock a bare instant is shown in.
///
/// `workspace` is the default and the safe one: every booking window is
/// anchored there, so a member two zones away who reads "09:00" reads
/// the time the door opens. `device` is for the member who lives in
/// their own clock and wants the app to as well — the zone is then
/// LABELLED wherever it differs, so 03:00 never reads as a mistake.
enum TimeZoneMode {
  workspace('workspace'),
  device('device');

  const TimeZoneMode(this.wire);
  final String wire;

  static TimeZoneMode fromWire(String? wire) =>
      values.where((m) => m.wire == wire).firstOrNull ?? workspace;
}
