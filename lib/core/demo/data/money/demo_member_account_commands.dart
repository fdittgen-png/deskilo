// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/money/domain/member_account_commands.dart';
import 'package:deskilo/features/money/domain/payment_claims.dart';
import 'package:deskilo/features/money/domain/payment_method.dart';
import 'package:deskilo/features/money/domain/payment_provider.dart';
import 'package:deskilo/features/money/domain/usage_record.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import '../money_repository.dart';
import 'demo_payment_gateway_repository.dart';

/// #2591 — what is recorded against a member's account, in the demo: answered
/// from one space's in-memory money store ([FakeMoneyRepository]); every other
/// port of that space reads and writes the same store.
class DemoMemberAccountCommands implements MemberAccountCommands {
  DemoMemberAccountCommands(this._m);

  final FakeMoneyRepository _m;

  /// #3556 — when set, the server's refusal of the next claims (a test's
  /// business already holds the invoices, say): nothing is recorded.
  ClaimRefusal? refuseClaimWith;

  /// #3556 — how many declarations pass before [refuseClaimWith] refuses
  /// (a refusal part-way through a selection of several months).
  int refuseAfter = 0;

  @override
  Future<String> declareInvoicesPaid({
    required String workspaceId,
    required String memberId,
    required InvoiceClaim claim,
  }) async {
    if (refuseClaimWith case final r?) {
      if (refuseAfter == 0) throw ClaimRefused(r);
      refuseAfter -= 1;
    }
    // #4165 — the app sends a retry after a lost answer under the request id
    // of its first attempt, and the server answers the one declaration it
    // made: the Demo answers the declaration that still holds these invoices
    final first = claim.standalone ? _declaredOf(memberId, claim) : null;
    if (first != null) return first;
    checkDemoClaim(_m, memberId: memberId, claim: claim, currency: _m.invoiceCommands.currency);
    final id = await recordPayment(
      workspaceId: workspaceId,
      memberId: memberId,
      amountCents: claim.amountCents,
      period: claim.standalone ? null : claim.period,
    );
    if (claim.standalone) _spendOnlyByAllocations(id);

    // #3556 — the invoices it pays wait for the business's approval.
    _m.claims[id] = [...claim.invoiceIds];
    return id;
  }

  /// #4165 — a standalone declaration is spent only by the allocations that name it (0901): its event says so.
  void _spendOnlyByAllocations(String eventId) {
    final events = _m.eventRepository?.events;
    final at = events?.indexWhere((e) => e.id == eventId) ?? -1;
    if (events == null || at < 0) return;
    events[at] = events[at].copyWith(payload: {...events[at].payload, 'allocation_mode': 'explicit'});
  }

  /// The pending declaration of exactly the invoices of [claim], if any.
  String? _declaredOf(String memberId, InvoiceClaim claim) {
    final ids = {...claim.invoiceIds};
    for (final e in _m.claims.entries) {
      if (e.key.startsWith('evt-payment-') &&
          e.value.length == ids.length &&
          e.value.toSet().containsAll(ids) &&
          _m.eventRepository?.events.any((x) =>
                  x.id == e.key &&
                  x.status == EventStatus.pending &&
                  x.subjectMemberId == memberId) ==
              true) {
        return e.key;
      }
    }
    return null;
  }

  @override
  Future<void> withdrawPaymentClaim({
    required String workspaceId,
    required String paymentId,
  }) async {
    // #3556 — as withdraw_payment_claim (0797): its invoices are free again;
    // a payment already captured is no longer being processed.
    final captured = _m.paymentIntents.any(
      (p) => p.orderId == paymentId && p.status != 'created',
    );
    if (captured) throw const ClaimRefused(ClaimRefusal.notProcessing);
    if (_m.claims.remove(paymentId) == null) {
      throw const ClaimRefused(ClaimRefusal.nothingToFree);
    }
    _m.withdrawnClaims.add(paymentId);
  }

  @override
  Future<void> withdrawPaymentDeclaration({
    required String workspaceId,
    required String eventId,
  }) async {
    // #4140 — as withdraw_payment_declaration (0800): only while the
    // business has not decided it; its invoices are free again.
    final events = _m.eventRepository?.events;
    final i = events?.indexWhere((e) => e.id == eventId) ?? -1;
    if (events == null || i < 0) {
      throw const ClaimRefused(ClaimRefusal.notMyPayment);
    }
    if (events[i].status != EventStatus.pending) {
      throw const ClaimRefused(ClaimRefusal.decided);
    }
    events[i] = events[i].copyWith(
      status: EventStatus.withdrawn,
      decidedAt: _m.eventRepository!.now(),
    );
    _m.claims.remove(eventId);
  }

  @override
  Future<String> recordPayment({
    required String workspaceId,
    required String memberId,
    required int amountCents,
    String note = '',
    PaymentMethod? method,
    DateTime? paidOn,
    String? period,
  }) async {
    _m.recordedPayments.add((
      amountCents: amountCents,
      note: note,
      method: method,
      paidOn: paidOn,
      period: period,
    ));
    final id = 'evt-payment-${_m.recordedPayments.length}';
    // #3291 — mirror record_payment (0070): it files a PENDING payment
    // event; the account is credited only once it is confirmed.
    final events = _m.eventRepository;
    if (events != null) {
      final now = events.now();
      events.events.add(
        WorkspaceEvent(
          id: id,
          workspaceId: workspaceId,
          type: EventType.payment,
          action: EventAction.submitted,
          actorMemberId: events.respondingMemberId,
          subjectMemberId: memberId,
          payload: {
            'amount_cents': amountCents,
            'note': note,
            'method': method?.wireName ?? '',
            'paid_on': isoDay(paidOn ?? now),
            'period': period ?? yearMonth(now.year, now.month),
          },
          status: EventStatus.pending,
          createdAt: now,
        ),
      );
    }
    return id;
  }

  @override
  Future<void> recordServiceCharge({
    required String workspaceId,
    required String subjectMemberId,
    required String serviceId,
    required int quantity,
    String? period,
  }) async {
    final service = _m.services.firstWhere(
      (s) => s.id == serviceId,
      orElse: () => throw StateError('unknown service'),
    );
    if (!service.active) throw StateError('service is inactive');
    if (quantity < 1 || quantity > 999) {
      throw StateError('quantity must be between 1 and 999');
    }
    _m.recordedServiceCharges.add((
      workspaceId: workspaceId,
      subjectMemberId: subjectMemberId,
      serviceId: serviceId,
      quantity: quantity,
      period: period,
    ));
    // Mirror the record_service_charge RPC: it only files a PENDING
    // service_charge event — the ledger charge appears on confirmation.
    final events = _m.eventRepository;
    if (events != null) {
      final now = events.now();
      events.events.add(
        WorkspaceEvent(
          id: 'evt-service-${_m.recordedServiceCharges.length}',
          workspaceId: workspaceId,
          type: EventType.serviceCharge,
          action: EventAction.submitted,
          // The signed-in viewer records the charge, exactly like the RPC
          // stamps auth.uid()'s member as the actor.
          actorMemberId: events.respondingMemberId,
          subjectMemberId: subjectMemberId,
          payload: {
            'service_id': serviceId,
            'name': service.name,
            'price_cents': service.priceCents,
            'quantity': quantity,
            'amount_cents': service.priceCents * quantity,
            'vat_percent': _vatPercentOf(service.vatRateId),
            'period': period ?? yearMonth(now.year, now.month),
          },
          status: EventStatus.pending,
          createdAt: now,
        ),
      );
    }
  }

  @override
  Future<String> buyPackage(String workspaceId, String packageId) async {
    _m.boughtPackages.add((workspaceId, packageId));
    return 'ext-${_m.boughtPackages.length}';
  }

  @override
  Future<String> requestUsageCorrection(
    String recordId, {
    String reason = '',
  }) async {
    final index = _m.usageRecords.indexWhere((r) => r.id == recordId);
    if (index < 0) throw StateError('unknown usage record');
    final record = _m.usageRecords[index];
    if (record.memberId != _m.usageMemberId) {
      throw StateError('only the member concerned may ask for this');
    }
    if (record.isCorrected) throw StateError('already corrected');
    if (record.actualMinutes == null || record.checkedOutAt == null) {
      throw StateError('no check-out to correct to');
    }
    if (record.actualMinutes! >= record.reservedMinutes) {
      throw StateError('nothing to reduce');
    }
    // With a rule the correction waits for somebody else; without one it
    // stands at once, exactly as the RPC does.
    if (!_m.usagePolicyConfigured) {
      _m.usageRecords[index] = UsageRecord(
        id: record.id,
        memberId: record.memberId,
        reservationId: record.reservationId,
        period: record.period,
        reservedFrom: record.reservedFrom,
        reservedTo: record.reservedTo,
        checkedInAt: record.checkedInAt,
        checkedOutAt: record.checkedOutAt,
        countedMinutes: record.actualMinutes!,
        reservedMinutes: record.reservedMinutes,
        actualMinutes: record.actualMinutes,
        basis: UsageBasis.corrected,
        correctedFromMinutes: record.countedMinutes,
        correctedAt: _m.clock(),
        spaceLabel: record.spaceLabel,
      );
    }
    return 'usage-event-${_m.usageRecords.length}';
  }

  @override
  Future<String> requestUsageRecordDelete(
    String recordId, {
    String reason = '',
  }) async {
    if (!_m.usagePolicyConfigured) {
      _m.usageRecords.removeWhere((r) => r.id == recordId);
    }
    return 'usage-delete-event';
  }

  double _vatPercentOf(String vatRateId) => vatRateId.isEmpty
      ? _m.defaultVatPercent
      : _m.vatRates
                .where((r) => r.id == vatRateId)
                .map((r) => r.percent)
                .firstOrNull ??
            _m.defaultVatPercent;
}

/// #3556 — the claims of the Demo's payments, as 0797 keeps them: the
/// invoices each payment names, an online order's by its order id and a
/// declared payment's by its event id, and the online payments whose claim
/// the member withdrew; and the money fake's commands on them.
mixin DemoClaimsStore {
  final claims = <String, List<String>>{};
  final withdrawnClaims = <String>[];

  DemoMemberAccountCommands get accountCommands;
  DemoPaymentGateway get paymentGateway;

  Future<PaymentOrderStart> resumeClaimOrder({
    required String workspaceId,
    required String memberId,
    required String paymentId,
  }) => paymentGateway.resumeClaimOrder(
    workspaceId: workspaceId, memberId: memberId, paymentId: paymentId,
  );

  Future<String> declareInvoicesPaid({
    required String workspaceId,
    required String memberId,
    required InvoiceClaim claim,
  }) => accountCommands.declareInvoicesPaid(
    workspaceId: workspaceId,
    memberId: memberId,
    claim: claim,
  );

  Future<PaymentOrderStart> createClaimOrder({
    required PaymentProvider provider,
    required String workspaceId,
    required String memberId,
    required String currencyCode,
    required InvoiceClaim claim,
    String? requestId,
  }) => paymentGateway.createClaimOrder(
    provider: provider,
    workspaceId: workspaceId,
    memberId: memberId,
    currencyCode: currencyCode,
    claim: claim,
    requestId: requestId,
  );

  Future<void> withdrawPaymentClaim({
    required String workspaceId,
    required String paymentId,
  }) => accountCommands.withdrawPaymentClaim(
    workspaceId: workspaceId,
    paymentId: paymentId,
  );

  Future<void> withdrawPaymentDeclaration({
    required String workspaceId,
    required String eventId,
  }) => accountCommands.withdrawPaymentDeclaration(
    workspaceId: workspaceId,
    eventId: eventId,
  );
}

/// #3556 — a claim refused as 0797 refuses it: invoices of another member
/// or unknown, several months, another month than the payment's, another
/// currency, an invoice already in an open claim, an amount other than what
/// they still owe.
void checkDemoClaim(
  FakeMoneyRepository m, {
  required String memberId,
  required InvoiceClaim claim,
  required String currency,
}) {
  final ids = claim.invoiceIds;
  if (ids.isEmpty) throw const ClaimRefused(ClaimRefusal.empty);
  // a fake that holds no invoices at all (a unit test's) checks nothing;
  // the Demo always holds them
  if (m.invoices.isEmpty) return;
  final invoices = [
    for (final id in ids) ...m.invoices.where((i) => i.id == id),
  ];
  if (invoices.length != ids.length ||
      invoices.any((i) => i.memberId != memberId)) {
    throw const ClaimRefused(ClaimRefusal.notYours);
  }
  // #4165 — a month's invoices and invoices without one are paid apart (0820
  // answers DKC14 on the monthly path, 0901 DKC16 on the standalone one)
  if (claim.standalone) {
    if (invoices.any((i) => i.period != null)) {
      throw const ClaimRefused(ClaimRefusal.monthlyInStandalone);
    }
  } else {
    if (invoices.any((i) => i.period == null)) {
      throw const ClaimRefused(ClaimRefusal.standaloneInMonthly);
    }
    if ({for (final i in invoices) i.period}.length > 1) {
      throw const ClaimRefused(ClaimRefusal.months);
    }
    if (invoices.first.period != claim.period) {
      throw const ClaimRefused(ClaimRefusal.otherMonth);
    }
  }
  if (invoices.any((i) => i.currency.toUpperCase() != currency.toUpperCase())) {
    throw const ClaimRefused(ClaimRefusal.currency);
  }
  final open = {for (final c in m.claims.values) ...c};
  if (ids.any(open.contains)) {
    throw const ClaimRefused(ClaimRefusal.alreadyInPayment);
  }
  final due = invoices.fold<int>(
    0,
    (sum, i) => sum + i.totalCents - (m.invoiceMatchesStore[i.id]?.paidCents ?? 0),
  );
  if (due != claim.amountCents) throw const ClaimRefused(ClaimRefusal.amount);
}
