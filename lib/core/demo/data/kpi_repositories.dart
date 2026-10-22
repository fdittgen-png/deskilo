// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The capacity and purchase figures of the demonstration, computed from the
// session's own plan, bookings and purchase documents with the predicates
// the server states in the KPI catalogue. The demo used to answer "no
// server in this mode", so the capacity tile and the purchase cards had
// nothing to show. The cost figures (contribution, depreciation, unbilled
// commitments) still need the server's ledger of every source and stay
// unavailable.
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';
import 'package:deskilo/features/workspace/domain/kpi_purchases.dart';

import '../../time/date_text.dart';
import 'floor_plan_repository.dart';
import 'purchase_repository.dart';
import 'reservation_repository.dart';

/// `kpi_seat_capacity` over the demo: every seat offers the working day
/// (nine hours, Monday to Friday); a booking counts for the hours it holds
/// a seat inside the window.
class DemoCapacityKpiRepository implements KpiRepository {
  DemoCapacityKpiRepository({
    required this.plan,
    required this.reservations,
    required this.now,
  });

  final FakeFloorPlanRepository plan;
  final FakeReservationRepository reservations;
  final DateTime now;

  static const _openHours = 9;

  @override
  Future<SeatCapacityKpi> seatCapacity(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
    String? levelId,
  }) async {
    final offices = {
      for (final o in plan.offices)
        if (levelId == null || o.levelId == levelId) o.id,
    };
    final desks = {
      for (final d in plan.desks)
        if (offices.contains(d.officeId)) d.id,
    };
    final seats = {
      for (final s in plan.seats)
        if (s.workspaceId == workspaceId &&
            s.resourceKind == ResourceKind.seat &&
            desks.contains(s.deskId))
          s.id,
    };
    var days = 0, openDays = 0;
    for (var d = from; d.isBefore(to); d = d.add(const Duration(days: 1))) {
      days++;
      if (d.weekday <= DateTime.friday) openDays++;
    }
    var reserved = 0.0;
    for (final r in reservations.reservations) {
      if (r.workspaceId != workspaceId ||
          !seats.contains(r.seatId) ||
          r.status == ReservationStatus.cancelled ||
          r.status == ReservationStatus.released) {
        continue;
      }
      final start = r.startsAt.isBefore(from) ? from : r.startsAt;
      final end = r.endsAt.isAfter(to) ? to : r.endsAt;
      if (end.isAfter(start)) {
        reserved += end.difference(start).inMinutes / 60;
      }
    }
    return SeatCapacityKpi(
      from: from,
      to: to,
      physicalSeatHours: seats.length * days * 24.0,
      offeredSeatHours: seats.length * openDays * _openHours * 1.0,
      reservedSeatHours: reserved,
      reservedOutsideOfferedSeatHours: 0,
      overlappingSeatHours: 0,
      seats: seats.length,
      roomsWithoutSeats: 0,
      offeredRoomHours: 0,
      reservedRoomHours: 0,
      quality: {
        if (seats.isEmpty) KpiQuality.notApplicable,
        if (to.isAfter(now)) KpiQuality.partial,
      },
      reasons: [
        if (seats.isEmpty) 'no_seats',
        if (to.isAfter(now)) 'period_not_over',
      ],
      computedAt: now,
    );
  }
}

/// `kpi_purchases_summary` over the demo's purchase documents and the
/// claims and payables they left.
class DemoPurchaseKpiRepository implements PurchaseKpiRepository {
  DemoPurchaseKpiRepository({required this.purchases, required this.now});

  final FakePurchaseRepository purchases;
  final DateTime now;

  @override
  Future<PurchaseSummaryKpi> summary(
    String workspaceId, {
    required String fromMonth,
    required String toMonth,
  }) async {
    bool inRange(DateTime? d) {
      if (d == null) return false;
      final month = yearMonth(d.year, d.month);
      return month.compareTo(fromMonth) >= 0 && month.compareTo(toMonth) <= 0;
    }

    var supplierDue = 0, memberDue = 0, outflows = 0, outflowCount = 0;
    for (final row in purchases.payables) {
      final o = row.obligation;
      if (o.creditorKind == CreditorKind.supplier) {
        supplierDue += o.remainingCents;
      } else {
        memberDue += o.remainingCents;
      }
      for (final a in o.allocations) {
        if (a.isReversal || a.reversed || !inRange(a.paidOn)) continue;
        outflows += a.amountCents;
        outflowCount++;
      }
    }
    final pending = [
      for (final p in await purchases.fetchPurchases(workspaceId))
        if (p.state == PurchaseState.pending) p,
    ];
    final partial = toMonth.compareTo(yearMonth(now.year, now.month)) >= 0;
    return PurchaseSummaryKpi(
      fromMonth: fromMonth,
      toMonth: toMonth,
      currency: 'EUR',
      apOutstandingMinor: supplierDue,
      memberDueMinor: memberDue,
      pendingCount: pending.length,
      pendingMinor: pending.fold<int>(0, (s, p) => s + p.grossCents),
      outflowsMinor: outflows,
      outflows: outflowCount,
      quality: {if (partial) KpiQuality.partial},
      reasons: [if (partial) 'period_not_over'],
      computedAt: now,
    );
  }
}
