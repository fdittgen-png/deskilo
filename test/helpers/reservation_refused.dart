// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4156 — the refusal the reservation data boundary raises for a server's
// answer, for tests that stand in for the server.
import 'package:deskilo/features/reservations/domain/reservation_refusal.dart';

ReservationRefused refused({
  required String message,
  String? code,
  Object? details,
}) => ReservationRefused(
  ReservationRefusal.fromServer(code: code, message: message, details: details),
);
