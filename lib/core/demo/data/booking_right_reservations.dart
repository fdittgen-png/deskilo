// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3269 (0661) -- the Demo's reservations refuse a booking from someone who
// does not hold makeReservations, as the server does on every path that
// books for the caller: a single booking, a series, and the kiosk's reserve
// and walk-up for the badge's member. The check is a hook the Demo wires to
// the persona's real permissions; the suite's own fake books freely.
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../features/reservations/domain/reservation_repository.dart';
import 'reservation_repository.dart';

class RightsCheckedReservationRepository extends FakeReservationRepository {
  RightsCheckedReservationRepository({super.actor});

  /// Whether the signed-in member holds makeReservations.
  bool Function() mayBook = () => true;

  PostgrestException get _refusal => const PostgrestException(
    message: 'not allowed to make reservations',
    code: '42501',
  );

  @override
  Future<String> create({
    required String workspaceId,
    String? seatId,
    String? deskId,
    String? officeId,
    String? levelId,
    required DateTime startsAt,
    required DateTime endsAt,
    bool checkIn = false,
    String? requestId,
  }) async {
    if (!mayBook()) throw _refusal;
    return super.create(
      workspaceId: workspaceId,
      seatId: seatId,
      deskId: deskId,
      officeId: officeId,
      levelId: levelId,
      startsAt: startsAt,
      endsAt: endsAt,
      checkIn: checkIn,
      requestId: requestId,
    );
  }

  @override
  Future<SeriesResult> createSeries({
    required String workspaceId,
    String? seatId,
    String? deskId,
    String? officeId,
    String? levelId,
    required DateTime firstStart,
    required DateTime firstEnd,
    required SeriesPattern pattern,
    required DateTime until,
  }) async {
    if (!mayBook()) throw _refusal;
    return super.createSeries(
      workspaceId: workspaceId,
      seatId: seatId,
      deskId: deskId,
      officeId: officeId,
      levelId: levelId,
      firstStart: firstStart,
      firstEnd: firstEnd,
      pattern: pattern,
      until: until,
    );
  }

  /// The kiosk books for the badge's member; the sentinel token models a
  /// badge whose member lacks the right (check-out and the rest are not
  /// bookings).
  @override
  Future<String> kioskAct({
    required String workspaceId,
    required String badgeToken,
    required String action,
    String? seatId,
    String? levelId,
    DateTime? startsAt,
    DateTime? endsAt,
  }) async {
    if (badgeToken == 'no-right-badge' &&
        (action == 'reserve' || action == 'check_in')) {
      throw _refusal;
    }
    return super.kioskAct(
      workspaceId: workspaceId,
      badgeToken: badgeToken,
      action: action,
      seatId: seatId,
      levelId: levelId,
      startsAt: startsAt,
      endsAt: endsAt,
    );
  }
}
