// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3308 — the Demo's guest passes, per space, as sell_guest_pass (0672)
// does them: the seller needs issueInvoices, the space's passes need
// manageServices; a sale writes a customer record of origin guest (no
// account, no subscription), books the place day by day, charges the pass
// and issues its own invoice to the guest, and files the payment as a
// pending request when the money was taken. The same request id never
// sells twice. Nothing leaves the visitor's session: no money moves.
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../features/money/domain/guest_pass.dart';
import '../../../features/money/domain/invoice.dart';
import '../../../features/money/domain/ledger_entry.dart';
import '../../../features/plan/domain/seat.dart';
import '../../../features/workspace/domain/member.dart';
import '../../time/date_text.dart';
import 'money/demo_member_account_commands.dart';
import 'money_repository.dart';
import 'reservation_repository.dart';
import 'workspace_repository.dart';

class FakeGuestPassRepository implements GuestPassRepository {
  FakeGuestPassRepository({
    required this.workspaceId,
    required this.currency,
    required this.reservations,
    required this.workspaces,
    required this.money,
    required this.now,
    required this.maySell,
    required this.mayPrice,
    required this.floorPlanSeats,
    List<GuestPassOffer> offers = const [],
  }) : offerList = [...offers];

  final String workspaceId;
  final String currency;
  final FakeReservationRepository reservations;
  final FakeWorkspaceRepository workspaces;
  final FakeMoneyRepository money;
  final DateTime Function() now;
  final bool Function() maySell;
  final bool Function() mayPrice;
  final List<Seat> Function() floorPlanSeats;
  final List<GuestPassOffer> offerList;
  final Map<String, GuestPassSale> sales = {};
  int _next = 1;

  @override
  Future<List<GuestPassOffer>> offers(String workspaceId) async =>
      [...offerList]..sort((a, b) => a.name.compareTo(b.name));

  @override
  Future<List<GuestPassPlace>> places(String workspaceId) async => [
    for (final s in floorPlanSeats()) (seatId: s.id, label: s.name),
  ];

  @override
  Future<String> saveOffer(
    String workspaceId, {
    String? id,
    required String name,
    required GuestPassUnit unit,
    required int priceCents,
    String? vatRateId,
    bool active = true,
  }) async {
    if (!mayPrice()) {
      throw const PostgrestException(message: 'not allowed to edit the guest passes', code: '42501');
    }
    final offer = GuestPassOffer(
      id: id ?? 'demo-pass-offer-${_next++}',
      name: name.trim(),
      unit: unit,
      priceCents: priceCents,
      vatRateId: vatRateId,
      active: active,
    );
    final i = offerList.indexWhere((o) => o.id == offer.id);
    if (id != null && i < 0) throw StateError('unknown guest pass');
    i < 0 ? offerList.add(offer) : offerList[i] = offer;
    return offer.id;
  }

  @override
  Future<GuestPassSale> sell(
    String workspaceId, {
    required GuestPassDraft draft,
    required Map<String, Object?> guest,
    required String requestId,
  }) async {
    final done = sales[requestId];
    if (done != null) {
      return GuestPassSale(
        passId: done.passId,
        memberId: done.memberId,
        reservationIds: done.reservationIds,
        units: done.units,
        amountCents: done.amountCents,
        invoiceId: done.invoiceId,
        paymentEventId: done.paymentEventId,
        replayed: true,
      );
    }
    if (!maySell()) {
      throw const PostgrestException(message: 'not allowed to sell a guest pass', code: '42501');
    }
    final offer = offerList
        .where((o) => o.id == draft.offer?.id && o.active)
        .firstOrNull;
    if (offer == null) throw StateError('unknown guest pass');
    if (guestPassProblems(draft).isNotEmpty) throw StateError('invalid pass');
    final first = '${guest['first_name'] ?? ''}'.trim();
    final last = '${guest['last_name'] ?? ''}'.trim();
    final name = [first, last].where((s) => s.isNotEmpty).join(' ');
    if (name.isEmpty) throw StateError('a guest needs a name');

    final memberId = 'demo-guest-${sales.length + 1}';
    workspaces.otherMembers.add(
      Member(
        id: memberId,
        workspaceId: workspaceId,
        userId: '',
        isAdmin: false,
        isOwner: false,
        status: MemberStatus.active,
        subscriptionPct: 0,
        managedName: name,
        origin: MemberOrigin.guest,
        customerCapacity: '${guest['company'] ?? ''}'.trim().isEmpty ? 'consumer' : null,
        joinedAt: now(),
      ),
    );
    final bookings = <String>[];
    for (var d = 0; d < draft.days; d++) {
      final day = draft.day;
      await reservations.createFor(
        workspaceId: workspaceId,
        subjectMemberId: memberId,
        seatId: draft.seatId,
        startsAt: DateTime(day.year, day.month, day.day + d, 0, draft.startMinutes),
        endsAt: DateTime(day.year, day.month, day.day + d, 0, draft.endMinutes),
      );
      bookings.add(reservations.reservations.last.id);
    }
    final units = guestPassUnits(GuestPassDraft(
      offer: offer,
      seatId: draft.seatId,
      day: draft.day,
      startMinutes: draft.startMinutes,
      endMinutes: draft.endMinutes,
      days: draft.days,
    ));
    final amount = units * offer.priceCents;
    final period = yearMonth(draft.day.year, draft.day.month);
    String? invoiceId;
    String? paymentId;
    if (amount > 0) {
      final at = now();
      money.ledger.add(
        LedgerEntry(
          id: 'demo-guest-charge-${sales.length + 1}',
          memberId: memberId,
          kind: LedgerKind.charge,
          category: LedgerCategory.service,
          amountCents: amount,
          description: '${offer.name} × $units',
          period: period,
          createdAt: at,
          occurredOn: draft.day,
        ),
      );
      final n = money.nextInvoiceNumber++;
      invoiceId = 'inv-guest-$n';
      money.invoices.insert(
        0,
        Invoice(
          id: invoiceId,
          workspaceId: workspaceId,
          memberId: memberId,
          number: 'INV-${at.year}-${n.toString().padLeft(4, '0')}',
          issuedAt: at,
          period: period,
          title: period,
          lines: [
            InvoiceLine(
              kind: 'service',
              label: '${offer.name} × $units',
              amountCents: amount,
            ),
          ],
          totalCents: amount,
          currency: currency,
          memberName: name,
          memberAddress: '',
          workspaceName: '',
          workspaceAddress: '',
          issuerName: '',
          signature: 'g' * 64,
        ),
      );
      if (draft.paid) {
        paymentId = await DemoMemberAccountCommands(money).recordPayment(
          workspaceId: workspaceId,
          memberId: memberId,
          amountCents: amount,
          note: offer.name,
          paidOn: at,
          period: period,
        );
      }
    }
    final sale = GuestPassSale(
      passId: 'demo-pass-${sales.length + 1}',
      memberId: memberId,
      reservationIds: bookings,
      units: units,
      amountCents: amount,
      invoiceId: invoiceId,
      paymentEventId: paymentId,
    );
    sales[requestId] = sale;
    return sale;
  }
}
