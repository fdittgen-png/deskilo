// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo/core/demo/data/fixture_clock.dart';
import 'package:deskilo/core/time/date_text.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/money/domain/member_account_commands.dart';
import 'package:deskilo/features/money/domain/payment_method.dart';
import 'package:deskilo/features/money/domain/usage_record.dart';

import '../money_repository.dart';

/// #2591 — what is recorded against a member's account, in the demo: answered
/// from one space's in-memory money store ([FakeMoneyRepository]); every other
/// port of that space reads and writes the same store.
class DemoMemberAccountCommands implements MemberAccountCommands {
  DemoMemberAccountCommands(this._m);

  final FakeMoneyRepository _m;

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
    return 'evt-payment-${_m.recordedPayments.length}';
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
      final now = kTestNow;
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
        correctedAt: kTestNow,
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
