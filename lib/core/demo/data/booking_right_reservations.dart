// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3269 (0661) -- the Demo's reservations refuse a booking from someone who
// does not hold makeReservations, as the server does on every path that
// books for the caller: a single booking, a series, and the kiosk's reserve
// and walk-up for the badge's member. The check is a hook the Demo wires to
// the persona's real permissions; the suite's own fake books freely.
// #3293 adds the two paths that act on someone else's booking: booking for
// another member and cancelling another member's booking need an active
// administrator or owner, as admin_create_reservation_for and
// cancel_reservation require.
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../features/reservations/domain/reservation_repository.dart';
import 'reservation_repository.dart';

class RightsCheckedReservationRepository extends FakeReservationRepository {
  RightsCheckedReservationRepository({super.actor});

  /// Whether the signed-in member holds makeReservations.
  bool Function() mayBook = () => true;

  /// #3293 — whether the signed-in member is an active administrator or
  /// owner of the space: admin_create_reservation_for books for another
  /// member only for them, and cancel_reservation cancels someone else's
  /// booking only for them.
  bool Function() mayActForOthers = () => true;

  /// #3293 — whether [memberId] is an active member of the space, the
  /// subject admin_create_reservation_for accepts.
  bool Function(String memberId) isActiveMember = (_) => true;

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

  @override
  Future<String> createFor({
    required String workspaceId,
    required String subjectMemberId,
    String? seatId,
    String? levelId,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    if (!mayActForOthers()) {
      throw const PostgrestException(
        message: 'not an admin of this workspace',
      );
    }
    if (!isActiveMember(subjectMemberId)) {
      throw const PostgrestException(message: 'unknown subject member');
    }
    return super.createFor(
      workspaceId: workspaceId,
      subjectMemberId: subjectMemberId,
      seatId: seatId,
      levelId: levelId,
      startsAt: startsAt,
      endsAt: endsAt,
    );
  }

  @override
  Future<void> cancel(String reservationId) async {
    final own = reservations
        .any((r) => r.id == reservationId && r.memberId == myMemberId);
    if (!own && !mayActForOthers()) {
      throw const PostgrestException(message: 'not your reservation', code: 'DKK29');
    }
    return super.cancel(reservationId);
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
