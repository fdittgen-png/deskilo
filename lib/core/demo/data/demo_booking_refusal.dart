// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../features/reservations/domain/reservation_refusal.dart';

/// #4156 — a Demo booking refusal, shaped as the real data boundary raises it:
/// the typed refusal a person's screen reads, from the code (and the words,
/// where the server has no code of its own) the real server answers with.
ReservationRefused demoBookingRefusal({
  required String message,
  String? code,
  Object? details,
}) => ReservationRefused(
  ReservationRefusal.fromServer(code: code, message: message, details: details),
);
