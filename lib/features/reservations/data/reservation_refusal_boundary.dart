// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4156 / #4315 / #4317 -- the ONE place a server's refusal of a booking command leaves the
// transport's type. Every booking write of the reservation data files goes through
// [asReservationRefusal] (`reservation_refusal_boundary_test` pins it): the repository's own
// bookings, the kiosk, and the commands sent to another business's host.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/connection_outcome.dart';
import '../domain/reservation_refusal.dart';

/// Runs [body]; a [PostgrestException] the server ANSWERED with becomes the typed
/// [ReservationRefused], its original error kept as the cause and its stack kept. A write that
/// ended without an answer (a timeout, a dropped connection, a gateway error page, an unreadable
/// body: see [leftOutcomeUnknown]) is NOT a refusal: it passes through untouched, so the
/// booking's recovery under its original request id is unchanged.
Future<T> asReservationRefusal<T>(Future<T> Function() body) async {
  try {
    return await body();
  } on PostgrestException catch (e, st) {
    if (leftOutcomeUnknown(e)) rethrow;
    Error.throwWithStackTrace(
      ReservationRefused(
        ReservationRefusal.fromServer(code: e.code, message: e.message, details: e.details),
        cause: e,
      ),
      st,
    );
  }
}
