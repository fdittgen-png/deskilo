// SPDX-License-Identifier: 0BSD
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';

/// THE booking-success → user-message mapper (#663), the counterpart of
/// `bookingErrorText`.
///
/// Every refusal already explains itself; a SUCCESS did not. On the plan
/// and in the Reserve hub an ordinary booking — and a walk-up check-in —
/// completed with no message at all: the seat quietly changed colour
/// once the data refreshed. On a busy floor, or a slow connection where
/// the repaint lags the write, "it worked" and "nothing happened" look
/// identical, and the member's only recourse is to try again and risk a
/// second booking.
///
/// So an attempt now ends exactly one of two ways: the booking, named
/// and dated, or the reason it was refused. Never silence.
///
/// Shared rather than pasted, for the reason `bookingErrorText` gives in
/// its own header: the same switch lived on four screens and drifted.
String bookingSuccessText(
  AppLocalizations? l10n,
  String locale, {
  required bool checkedIn,
  required DateTime start,
  required DateTime end,
  String? spaceName,
}) {
  // Times, not durations: "until 12:00" is what a member checks against
  // the clock on the wall. Locale-aware — never a raw toString (a HARD
  // RULE of this project).
  //
  // Formatting must NOT be able to throw here. The confirmation is
  // raised on the success path, inside the same try/catch that reports
  // refusals — so an uninitialised locale would turn a booking that
  // WORKED into a message saying it failed, which is the exact bug this
  // whole change exists to remove. Fall back to a plain 24-hour clock
  // instead; a slightly less local-looking time beats a lie.
  final until = _hm(locale, end);
  final space = (spaceName ?? '').trim();

  if (checkedIn) {
    // A check-in is happening NOW, so only the end matters.
    if (space.isEmpty) {
      return l10n?.bookingCheckedInUntil(until) ?? 'Checked in until $until.';
    }
    return l10n?.bookingCheckedInAtUntil(space, until) ??
        'Checked in at $space until $until.';
  }

  // A reservation may be for another day, so it carries its date. Same
  // day gets the times alone — repeating today's date reads as noise.
  final sameDay = _isSameDay(start, end);
  final from = _hm(locale, start);
  final when = sameDay
      ? '${_md(locale, start)} $from–$until'
      : '${_md(locale, start)} $from → ${_md(locale, end)} $until';

  if (space.isEmpty) {
    return l10n?.bookingReservedWhen(when) ?? 'Reserved: $when.';
  }
  return l10n?.bookingReservedSpaceWhen(space, when) ?? 'Reserved $space: $when.';
}

/// Hours:minutes, falling back to a plain 24-hour clock when the locale
/// has no date symbols loaded.
String _hm(String locale, DateTime at) {
  try {
    return DateFormat.Hm(locale).format(at);
    // ignore: catch_no_st
  } catch (_) {
    // trace-exempt: a formatting fallback is not a failure to report,
    // and this runs on the SUCCESS path where a logged error would read
    // as the booking having gone wrong. domain/ is pure Dart besides —
    // it has no logger to reach for (AGENT_RULES layering).
    final h = at.hour.toString().padLeft(2, '0');
    final m = at.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

/// Weekday + short date, with the same guarantee.
String _md(String locale, DateTime at) {
  try {
    return DateFormat.MMMEd(locale).format(at);
    // ignore: catch_no_st
  } catch (_) {
    // trace-exempt: same reasoning as _hm above.
    return '${at.year}-${at.month.toString().padLeft(2, '0')}-'
        '${at.day.toString().padLeft(2, '0')}';
  }
}

/// Local same-day test — `DateUtils` lives in Flutter's material layer
/// and `domain/` is pure Dart (AGENT_RULES layering).
bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
