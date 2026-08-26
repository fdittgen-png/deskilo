// SPDX-License-Identifier: 0BSD
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/time/workspace_time.dart';
import '../../workspace/domain/booking_granularity.dart';

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

  /// Presence rule (#408 → 0113/#600): checking in means "I am here".
  /// Base window is `[startsAt − 15 min, endsAt)`; minute grids widen
  /// the leeway to one grid step, and under the day-based and hours
  /// granularities the slot IS the working day, so ANY arrival on the
  /// slot's workspace-local day counts (an early same-day check-in the
  /// old flat leeway silently hid from the UI). Mirrors
  /// `check_in_reservation` (0113); the server stays the authority.
  bool checkInWindowOpen(DateTime now, {BookingGranularity? granularity}) {
    if (status != ReservationStatus.reserved || !now.isBefore(endsAt)) {
      return false;
    }
    var leeway = checkInLeeway;
    final step = granularity?.stepMinutes;
    if (step != null && step > checkInLeeway.inMinutes) {
      leeway = Duration(minutes: step);
    }
    if (!now.isBefore(startsAt.subtract(leeway))) return true;
    return granularity != null &&
        (granularity.isDayBased || granularity == BookingGranularity.hours) &&
        WorkspaceTime.dateOf(startsAt) == WorkspaceTime.dateOf(now);
  }

  /// The instant the check-in window OPENS — derived from the very rule
  /// [checkInWindowOpen] gates on (#636). The disabled tile used to
  /// announce `start − 15 min` while the gate had already widened the
  /// leeway to the grid step (or opened for the whole day), so it named
  /// a time the gate did not use — worse than saying nothing.
  DateTime checkInOpensAt({BookingGranularity? granularity}) {
    if (granularity != null &&
        (granularity.isDayBased || granularity == BookingGranularity.hours)) {
      // The slot IS the working day: the window opens with that day.
      final day = WorkspaceTime.dateOf(startsAt);
      return WorkspaceTime.at(day.year, day.month, day.day);
    }
    var leeway = checkInLeeway;
    final step = granularity?.stepMinutes;
    if (step != null && step > checkInLeeway.inMinutes) {
      leeway = Duration(minutes: step);
    }
    return startsAt.subtract(leeway);
  }

  /// Active and covering the instant [at] (start inclusive, end exclusive).
  bool coversInstant(DateTime at) =>
      isActive && !at.isBefore(startsAt) && at.isBefore(endsAt);

  /// Active and overlapping the half-open window `[from, to)` (#184): a
  /// reservation ending exactly at [from] or starting exactly at [to] does
  /// NOT overlap — mirroring [coversInstant]'s end-exclusive semantics.
  bool coversRange(DateTime from, DateTime to) =>
      isActive && from.isBefore(endsAt) && startsAt.isBefore(to);
}
