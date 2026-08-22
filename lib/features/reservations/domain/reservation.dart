// SPDX-License-Identifier: 0BSD
import 'package:freezed_annotation/freezed_annotation.dart';

part 'reservation.freezed.dart';

/// Lifecycle per spec §3. Persisted by name — never rename values.
enum ReservationStatus { reserved, checkedIn, completed, cancelled, released }

/// Maps the snake_case DB status strings (checked_in) to the enum.
ReservationStatus reservationStatusFromDb(String value) => switch (value) {
      'reserved' => ReservationStatus.reserved,
      'checked_in' => ReservationStatus.checkedIn,
      'completed' => ReservationStatus.completed,
      'cancelled' => ReservationStatus.cancelled,
      'released' => ReservationStatus.released,
      _ => throw ArgumentError.value(value, 'value', 'unknown status'),
    };

String reservationStatusToDb(ReservationStatus status) => switch (status) {
      ReservationStatus.reserved => 'reserved',
      ReservationStatus.checkedIn => 'checked_in',
      ReservationStatus.completed => 'completed',
      ReservationStatus.cancelled => 'cancelled',
      ReservationStatus.released => 'released',
    };

/// A booking of one seat — or one whole office, or one whole level
/// (spec §3, 0050).
@freezed
sealed class Reservation with _$Reservation {
  const Reservation._();

  const factory Reservation({
    required String id,
    required String workspaceId,
    String? seatId,
    String? deskId,
    String? officeId,

    /// Set when the booking covers a WHOLE level (0050); exactly one of
    /// seat/office/level is non-null.
    String? levelId,
    required String memberId,
    required DateTime startsAt,
    required DateTime endsAt,
    required ReservationStatus status,
    String? seriesId,

    /// Repetition modality of the series ('daily' / 'weekdays' /
    /// 'weekly', 0034); null on single bookings and pre-0034 series.
    String? seriesPattern,
    DateTime? checkedInAt,
    DateTime? checkedOutAt,

    /// Audit substitution snapshot (#587): the human-readable chain
    /// (workspace · level · room · table · chair, up to the deleted
    /// target's depth) written when an OWNER deleted the plan object
    /// this reservation pointed at. Null while the target lives.
    String? spaceLabel,
  }) = _Reservation;

  /// How early check-in opens before the start (spec §4.3, #408).
  static const checkInLeeway = Duration(minutes: 15);

  /// The display name of the booked space: the live plan name while the
  /// target exists, else the #587 substitution snapshot written when the
  /// plan object was deleted — past bookings stay traceable.
  String spaceNameFrom(Map<String, String> targetNames) =>
      targetNames[seatId ?? deskId ?? officeId ?? levelId] ??
      spaceLabel ??
      '';

  bool get isActive =>
      status == ReservationStatus.reserved ||
      status == ReservationStatus.checkedIn;

  /// Presence rule (#408): checking in means "I am standing here NOW".
  /// Allowed only while [now] is inside `[startsAt − 15 min, endsAt)` —
  /// never ahead of the window (the future), never after the
  /// reservation ended (the past). Mirrors `check_in_reservation`
  /// (migration 0077); the server is the authority, this gates the UI.
  bool checkInWindowOpen(DateTime now) =>
      status == ReservationStatus.reserved &&
      !now.isBefore(startsAt.subtract(checkInLeeway)) &&
      now.isBefore(endsAt);

  /// Active and covering the instant [at] (start inclusive, end exclusive).
  bool coversInstant(DateTime at) =>
      isActive && !at.isBefore(startsAt) && at.isBefore(endsAt);

  /// Active and overlapping the half-open window `[from, to)` (#184): a
  /// reservation ending exactly at [from] or starting exactly at [to] does
  /// NOT overlap — mirroring [coversInstant]'s end-exclusive semantics.
  bool coversRange(DateTime from, DateTime to) =>
      isActive && from.isBefore(endsAt) && startsAt.isBefore(to);
}
