// SPDX-License-Identifier: 0BSD
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/fake_notification_service.dart';
import '../../helpers/fake_reservation_repository.dart';
import '../../helpers/mock_providers.dart';

void main() {
  testWidgets('booting with an upcoming reservation schedules its reminder',
      (tester) async {
    final notifications = FakeNotificationService();
    final start = DateTime.now().add(const Duration(hours: 3));
    final reservations = FakeReservationRepository()
      ..reservations.add(
        Reservation(
          id: 'res-up',
          workspaceId: 'ws-1',
          seatId: 'seat-4',
          memberId: 'member-1',
          startsAt: start,
          endsAt: start.add(const Duration(hours: 4)),
          status: ReservationStatus.reserved,
        ),
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(
          notifications: notifications,
          reservations: reservations,
          floorPlan: FakeFloorPlanRepository()..seedSmallPlan(),
        ),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(notifications.rescheduleCalls, isNotEmpty);
    expect(notifications.lastReminders, hasLength(1));
    expect(notifications.lastReminders.single.reservationId, 'res-up');
    expect(notifications.lastReminders.single.body, contains('A1'));
  });
}
