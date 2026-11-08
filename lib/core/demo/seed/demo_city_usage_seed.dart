// SPDX-License-Identifier: AGPL-3.0-or-later
// Completed fictional bookings produce the same usage facts as check-out.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import '../../../features/money/domain/usage_record.dart';
import '../../../features/reservations/domain/reservation.dart';
import '../data/money_repository.dart';

void seedCityUsage(FakeMoneyRepository money, Iterable<Reservation> bookings) {
  for (final booking in bookings) {
    if (booking.status != ReservationStatus.completed || booking.seatId == null) {
      continue;
    }
    final minutes = booking.endsAt.difference(booking.startsAt).inMinutes;
    money.usageRecords.add(
      UsageRecord(
        id: 'usage-${booking.id}',
        memberId: booking.memberId,
        reservationId: booking.id,
        period: yearMonth(booking.startsAt.year, booking.startsAt.month),
        reservedFrom: booking.startsAt,
        reservedTo: booking.endsAt,
        countedMinutes: minutes,
        reservedMinutes: minutes,
        checkedInAt: booking.checkedInAt,
        checkedOutAt: booking.checkedOutAt,
        actualMinutes: minutes,
      ),
    );
  }
}
