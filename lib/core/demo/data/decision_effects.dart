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
import 'package:deskilo/features/money/domain/invoice_commands.dart' show PaymentAllocation;
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
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

  String ledger(WorkspaceEvent e, LedgerKind kind, LedgerCategory category, int cents, String text,
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
      // #4165 — a declared payment of invoices without a month keeps its mode
      allocationMode: e.payload['allocation_mode'] as String? ?? 'legacy',
    ));
    return id;
  }

  int intOf(Object? v) => (v as num?)?.toInt() ?? 0;

  events.onDecided = (e, {required accepted}) async {
    if (!accepted) {
      // A refusal frees what the request held, and ends a waiting join.
      cancel(e.reservationId, const {ReservationStatus.reserved, ReservationStatus.checkedIn});
      // a refused declaration frees the invoices it named (0797)
      money.claims.remove(e.id);
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
        final note = e.payload['note'] as String? ?? '';
        final credit = ledger(e, LedgerKind.credit, LedgerCategory.payment, intOf(e.payload['amount_cents']),
            note, occurredOn: DateTime.tryParse(e.payload['paid_on'] as String? ?? ''));
        await _applyDeclared(money, e, credit, note);
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

/// #4224 — as 0797 on a server: an approved declared payment that names
/// invoices is applied to them, what each still owes, and its claim ends.
Future<void> _applyDeclared(
  FakeMoneyRepository money,
  WorkspaceEvent e,
  String ledgerId,
  String note,
) async {
  final claim = money.claims.remove(e.id);
  if (claim == null) return;
  int paid(String id) => money.invoiceMatchesStore[id]?.paidCents ?? 0;
  final parts = <PaymentAllocation>[
    for (final inv in money.invoices)
      if (claim.contains(inv.id) && inv.totalCents - paid(inv.id) > 0)
        (invoiceId: inv.id, amountCents: inv.totalCents - paid(inv.id)),
  ];
  if (parts.isEmpty) return;
  await money.invoiceCommands.applyPaymentToInvoices(
    workspaceId: e.workspaceId,
    paymentLedgerId: ledgerId,
    allocations: parts,
    note: note,
  );
}
