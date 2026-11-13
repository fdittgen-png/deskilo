// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3291 — what a decided request changes in its space's other stores, the
// effects respond_to_event applies on a server (0101; the reservation
// rule of 0113). Before, a Demo approval only changed the request's
// status: the booking a deletion was approved for stayed on the plan, an
// approved join left the member waiting, an approved expense was never
// credited. Effects the Demo does not hold a store for (a quota extension,
// a negotiated price) stay the request's status, named in the audit.
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import 'event_repository.dart';
import 'money_repository.dart';
import 'reservation_repository.dart';
import 'workspace_repository.dart';

/// Wires [events] so a decision reaches [reservations], [workspaces] and
/// [money] of the same space, as of [now].
void wireDecisionEffects(
  FakeEventRepository events, {
  required FakeReservationRepository reservations,
  required FakeWorkspaceRepository workspaces,
  required FakeMoneyRepository money,
  required DateTime Function() now,
}) {
  var next = 1;
  void cancel(String? id, Set<ReservationStatus> from) {
    final i = reservations.reservations.indexWhere((r) => r.id == id);
    if (i < 0 || !from.contains(reservations.reservations[i].status)) return;
    reservations.reservations[i] = reservations.reservations[i].copyWith(status: ReservationStatus.cancelled);
  }

  Future<void> memberStatus(String? id, MemberStatus to) async {
    final rows = [workspaces.myMember, ...workspaces.otherMembers];
    final m = rows.where((r) => r.id == id).firstOrNull;
    if (m != null && m.status == MemberStatus.pending) await workspaces.updateMemberStatus(m.id, to);
  }

  void ledger(WorkspaceEvent e, LedgerKind kind, LedgerCategory category, int cents, String text,
      {DateTime? occurredOn}) {
    final at = now();
    final id = 'decided-${e.id}-${next++}';
    money.ledger.add(LedgerEntry(
      id: id,
      memberId: e.subjectMemberId,
      kind: kind,
      category: category,
      amountCents: cents,
      description: text,
      period: e.payload['period'] as String? ?? yearMonth(at.year, at.month),
      createdAt: at,
      occurredOn: occurredOn,
    ));
    if (e.payload['vat_percent'] case final num percent) {
      money.ledgerVatPercents[id] = percent.toDouble();
    }
  }

  int intOf(Object? v) => (v as num?)?.toInt() ?? 0;

  events.onDecided = (e, {required accepted}) async {
    if (!accepted) {
      // A refusal frees what the request held, and ends a waiting join.
      cancel(e.reservationId, const {ReservationStatus.reserved, ReservationStatus.checkedIn});
      if (e.type == EventType.memberJoin) await memberStatus(e.subjectMemberId, MemberStatus.exited);
      return;
    }
    switch (e.type) {
      case EventType.memberJoin:
        await memberStatus(e.subjectMemberId, MemberStatus.active);
      case EventType.reservationDelete:
        cancel(e.payload['reservation_id'] as String? ?? e.reservationId,
            const {ReservationStatus.reserved, ReservationStatus.checkedIn, ReservationStatus.completed});
      case EventType.payment:
        // A confirmed payment is a credit dated the day the money moved.
        ledger(e, LedgerKind.credit, LedgerCategory.payment, intOf(e.payload['amount_cents']),
            e.payload['note'] as String? ?? '',
            occurredOn: DateTime.tryParse(e.payload['paid_on'] as String? ?? ''));
      case EventType.expense:
        final supply = e.payload['supply'];
        ledger(e, LedgerKind.credit, LedgerCategory.expense, intOf(e.payload['amount_cents']),
            e.payload['note'] as String? ?? (supply is Map ? '${supply['name']}' : ''));
      case EventType.serviceCharge:
        // #2860 — 0016 writes a unit price; an older row carries the amount.
        final quantity = intOf(e.payload['quantity']);
        final cents = e.payload['amount_cents'] != null
            ? intOf(e.payload['amount_cents'])
            : intOf(e.payload['price_cents']) * quantity;
        ledger(e, LedgerKind.charge, LedgerCategory.service, cents, '${e.payload['name']} x$quantity');
      default:
        break;
    }
  };
}
