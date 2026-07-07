// SPDX-License-Identifier: MIT
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

/// A booking of one seat — or one whole office (spec §3).
@freezed
sealed class Reservation with _$Reservation {
  const Reservation._();

  const factory Reservation({
    required String id,
    required String workspaceId,
    String? seatId,
    String? officeId,
    required String memberId,
    required DateTime startsAt,
    required DateTime endsAt,
    required ReservationStatus status,
    String? seriesId,
    DateTime? checkedInAt,
    DateTime? checkedOutAt,
  }) = _Reservation;

  bool get isActive =>
      status == ReservationStatus.reserved ||
      status == ReservationStatus.checkedIn;

  /// Active and covering the instant [at] (start inclusive, end exclusive).
  bool coversInstant(DateTime at) =>
      isActive && !at.isBefore(startsAt) && at.isBefore(endsAt);
}
