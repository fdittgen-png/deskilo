// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3626 (desk M7) — the command behind New booking at the desk: the same one
// the Reserve hub runs (`bookSeat`: for me, for someone else or a series, a
// plain booking kept as a durable intent until the server answers), here with
// the instant the grid's position resolved to.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/reservations/application/book_seat.dart';
import '../../features/reservations/providers/reservation_providers.dart';

/// Makes the booking [request] describes, for [myMemberId]. Throws what the
/// repository throws: the caller says what the server answered.
Future<BookingOutcome> bookFromDesk(
  WidgetRef ref,
  BookingRequest request, {
  required String? myMemberId,
}) => bookSeat(
  ref.read(reservationRepositoryProvider),
  request,
  myMemberId: myMemberId,
  recovery: ref.read(bookingRecoveryProvider),
);
