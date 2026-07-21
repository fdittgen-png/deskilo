// SPDX-License-Identifier: 0BSD
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/seat_context.dart';
import 'floor_plan_providers.dart';

part 'seat_context_providers.g.dart';

/// Where one seat lives (#182): level · office · desk · seat names for the
/// calendar's reservation detail sheet. Null for an unknown seat.
@riverpod
Future<SeatContext?> seatContext(Ref ref, String seatId) {
  return ref.watch(floorPlanRepositoryProvider).fetchSeatContext(seatId);
}

/// [seatContext] for a whole-office reservation: level + office names only.
@riverpod
Future<SeatContext?> officeContext(Ref ref, String officeId) {
  return ref.watch(floorPlanRepositoryProvider).fetchOfficeContext(officeId);
}
