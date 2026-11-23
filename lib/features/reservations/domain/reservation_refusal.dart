// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4156 (A1 of #4174) — what a booking refusal means, as plain data.
//
// The server raises a DKK errcode (0739) and, when the refusal names a value,
// that value as JSON in DETAIL; a few refusals have no code of their own yet
// and are read by their words (a bounded compatibility reading, kept here and
// nowhere else). The data boundary turns whatever the transport gave into this
// value ONCE; everything after it — the application, the presentation that
// chooses the words — reads only this. No SDK, no Flutter, no localisation, no
// logger: a refusal is not wording, and a malformed DETAIL is not a second
// failure.
//
// This is the server's refusal, distinct from the client-side `BookingRefusal`
// gate (`booking_gate.dart`), which foresees one before asking.
import 'dart:convert';
import '../../../core/codes/dk_code.dart';

/// A refusal's kind: a code the server issues, or one of the legacy readings.
enum ReservationRefusalKind {
  /// A DKK code of 0739 (`code` names it).
  coded,

  /// The hierarchy guard: a space whose parent or child is taken in that
  /// period (read by its words).
  spaceChainTaken,

  /// An occupancy refusal by another reservation (read by its words).
  alreadyReserved,

  /// The permission refusal every booking write can raise (42501, by its
  /// words).
  notAllowed,

  /// The kiosk's answer to a badge it does not know (by its words).
  badgeRejected,

  /// The kiosk's answer to a check-out of a booking that is not checked in
  /// (by its words).
  notCheckedIn,

  /// Anything else: shown with the screen's own fallback, never with the
  /// server's text.
  unknown,
}

/// A server's booking refusal: its meaning and the values it named.
class ReservationRefusal {
  const ReservationRefusal._({
    required this.kind,
    this.code,
    this.minutes,
    this.days,
    this.blockedByOther = false,
  });

  /// The meaning of a refusal the server issued under [code], with the values
  /// it carried: used by tests and fakes that stand in for a server.
  const ReservationRefusal.coded(String this.code, {this.minutes, this.days})
    : kind = ReservationRefusalKind.coded,
      blockedByOther = code == DkCode.dkk26;

  /// What the transport could not be read as: no kind, no value, no text.
  static const ReservationRefusal unknown = ReservationRefusal._(
    kind: ReservationRefusalKind.unknown,
  );

  final ReservationRefusalKind kind;

  /// The DKK code, for [ReservationRefusalKind.coded] only.
  final String? code;

  /// The duration the refusal names, in minutes (a slot, a minimum, a
  /// maximum), when it named a valid one.
  final int? minutes;

  /// The number of days the refusal names (a horizon, a series), when it named
  /// a valid one.
  final int? days;

  /// Whether ANOTHER reservation caused it (the occupancy refusals): surfaces
  /// offer contacting the reserver. A member's own booking is not this.
  final bool blockedByOther;

  /// Reads what a server answered: its errcode [code], its message and its
  /// DETAIL [details] (an already decoded map, or a JSON string). Never
  /// throws, whatever the shapes: a value that is not a whole non-negative
  /// number is absent, a detail that is not an object names nothing, and a
  /// code this app does not know is not kept.
  factory ReservationRefusal.fromServer({
    String? code,
    String? message,
    Object? details,
  }) {
    final known = code != null && _knownCodes.contains(code);
    final words = message ?? '';
    final other =
        code == DkCode.dkk26 ||
        code == '23P01' ||
        words.contains('already reserved');
    if (known) {
      final values = _detail(details);
      return ReservationRefusal._(
        kind: ReservationRefusalKind.coded,
        code: code,
        minutes: _whole(values['minutes']),
        days: _whole(values['days']),
        blockedByOther: other,
      );
    }
    // What still has no code of its own: the hierarchy guard keeps Postgres's
    // exclusion code (23P01), a taken seat is the exclusion constraint itself,
    // and the permission refusal is 42501 for every write.
    final kind = words.contains('that space is already reserved in that period')
        ? ReservationRefusalKind.spaceChainTaken
        : words.contains('already reserved')
        ? ReservationRefusalKind.alreadyReserved
        : words.contains('not allowed to make reservations')
        ? ReservationRefusalKind.notAllowed
        : words.contains('badge not recognized')
        ? ReservationRefusalKind.badgeRejected
        : words.contains('not checked in')
        ? ReservationRefusalKind.notCheckedIn
        : ReservationRefusalKind.unknown;
    return ReservationRefusal._(kind: kind, blockedByOther: other);
  }
}

/// A server's booking refusal, raised by the reservation data boundary for the
/// application and the presentation to read: the typed refusal, plus the
/// transport's own error ([cause], never shown) so the trace keeps what
/// happened. A timeout, a lost answer or a disconnect is NOT this: it stays an
/// unknown outcome and recovers under its original request id.
class ReservationRefused implements Exception {
  const ReservationRefused(this.refusal, {this.cause});

  final ReservationRefusal refusal;

  /// The error the transport raised, for diagnostics only.
  final Object? cause;

  @override
  String toString() =>
      'ReservationRefused(${refusal.kind.name}'
      '${refusal.code == null ? '' : ' ${refusal.code}'})';
}

/// Every code 0739 issues (DKK14 and DKK24 are not issued): the only ones this
/// app reads as a meaning.
const Set<String> _knownCodes = {
  DkCode.dkk01,
  DkCode.dkk02,
  DkCode.dkk03,
  DkCode.dkk04,
  DkCode.dkk05,
  DkCode.dkk06,
  DkCode.dkk07,
  DkCode.dkk08,
  DkCode.dkk09,
  DkCode.dkk10,
  DkCode.dkk11,
  DkCode.dkk12,
  DkCode.dkk13,
  DkCode.dkk15,
  DkCode.dkk16,
  DkCode.dkk17,
  DkCode.dkk18,
  DkCode.dkk19,
  DkCode.dkk20,
  DkCode.dkk21,
  DkCode.dkk22,
  DkCode.dkk23,
  DkCode.dkk25,
  DkCode.dkk26,
  DkCode.dkk27,
  DkCode.dkk28,
  DkCode.dkk29,
  DkCode.dkk30,
  DkCode.dkk31,
  DkCode.dkk32,
  DkCode.dkk33,
  DkCode.dkk34,
  DkCode.dkk35,
  DkCode.dkk36,
};

/// A whole, non-negative number from a detail value (an integer, or a double
/// with no fraction); anything else — a string, a list, an object, a boolean,
/// null, a negative or a huge number — is absent.
int? _whole(Object? value) {
  final n = switch (value) {
    final int i => i,
    final double d when d.isFinite && d == d.truncateToDouble() => d.toInt(),
    _ => null,
  };
  return n == null || n < 0 || n > 1000000 ? null : n;
}

/// The refusal's values: DETAIL read as a JSON object (or one already
/// decoded), or none.
Map<String, Object?> _detail(Object? details) {
  if (details is Map) {
    return {for (final e in details.entries) '${e.key}': e.value};
  }
  if (details is! String || details.isEmpty) return const {};
  try {
    final decoded = jsonDecode(details);
    return decoded is Map
        ? {for (final e in decoded.entries) '${e.key}': e.value}
        : const {};
  } on FormatException {
    // trace-exempt: a DETAIL that is not JSON names no value.
    return const {};
  }
}

/// Whether [error] is an occupancy refusal caused by ANOTHER member's
/// reservation (#622): surfaces use it to offer contacting the reserver. The
/// member's OWN booking ('you already have a reservation in that period') is
/// deliberately not this.
bool isBlockedByOtherError(Object error) =>
    error is ReservationRefused && error.refusal.blockedByOther;
