// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/ids/request_id.dart';
import '../domain/member_account_commands.dart';
import '../domain/payment_claims.dart';
import '../domain/payment_method.dart';

/// #2591 — payments, service charges, packages and usage requests recorded
/// against a member, with its own client. The bodies are the ones that lived in
/// the money repository and its part files.
class SupabaseMemberAccountCommands implements MemberAccountCommands {
  SupabaseMemberAccountCommands(this._client);

  final SupabaseClient _client;

  /// One request id per confirmation (#4321). A declaration whose answer
  /// was lost is sent again under the id of its first attempt, so the
  /// server answers the one declaration it made. The id is forgotten once
  /// the server has answered, accepted or refused: the next confirmation
  /// of the same words is a new payment.
  final Map<String, String> _attempts = {};

  Future<String> _declared(String key, Future<Object?> Function(String id) send) async {
    final id = _attempts.putIfAbsent(key, newRequestId);
    try {
      final result = await send(id);
      _attempts.remove(key);
      return result! as String;
    } on PostgrestException {
      // trace-exempt: the server answered; the caller reads its refusal
      _attempts.remove(key);
      rethrow;
    }
    // Any other failure is a lost answer: the id stays for the next try.
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
    final day = paidOn == null ? null : isoDay(paidOn);
    return _declared(
      [workspaceId, memberId, amountCents, note, method?.wireName, day, period].join('|'),
      (id) => _client.rpc<dynamic>(
        'record_payment',
        params: {
          'p_workspace_id': workspaceId,
          'p_member_id': memberId,
          'p_amount_cents': amountCents,
          'p_note': note,
          'p_method': method?.wireName ?? '',
          // 0070 — a date, not a timestamp: what matters is the DAY the money
          // moved, in the payer's own calendar.
          'p_paid_on': day,
          'p_period': period,
          'p_request_id': id,
        },
      ),
    );
  }

  @override
  Future<String> declareInvoicesPaid({
    required String workspaceId,
    required String memberId,
    required InvoiceClaim claim,
  }) async {
    final ids = [...claim.invoiceIds]..sort();
    return _claimed(
      () => _declared(
        [workspaceId, memberId, claim.amountCents, claim.period, ...ids].join('|'),
        (id) => _client.rpc<Object?>(
          'record_payment',
          params: {
            'p_workspace_id': workspaceId,
            'p_member_id': memberId,
            'p_amount_cents': claim.amountCents,
            'p_note': '',
            'p_method': '',
            'p_paid_on': null,
            'p_period': claim.period,
            'p_invoice_ids': claim.invoiceIds,
            'p_request_id': id,
          },
        ),
      ),
    );
  }

  @override
  Future<void> withdrawPaymentClaim({
    required String workspaceId,
    required String paymentId,
  }) => _claimed(
    () => _client.rpc<void>(
      'withdraw_payment_claim',
      params: {'p_intent': paymentId},
    ),
  );

  @override
  Future<void> withdrawPaymentDeclaration({
    required String workspaceId,
    required String eventId,
  }) => _claimed(
    () => _client.rpc<void>(
      'withdraw_payment_declaration',
      params: {'p_event': eventId},
    ),
  );

  /// A claim the server refused, as its refusal (0797's DKC codes).
  Future<T> _claimed<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PostgrestException catch (e, st) {
      // trace-exempt: rethrown as the refusal the screen names, or as is
      final refusal = ClaimRefusal.of(e.code);
      if (refusal == null) rethrow;
      Error.throwWithStackTrace(ClaimRefused(refusal), st);
    }
  }

  @override
  Future<void> recordServiceCharge({
    required String workspaceId,
    required String subjectMemberId,
    required String serviceId,
    required int quantity,
    String? period,
  }) async {
    await _client.rpc<dynamic>(
      'record_service_charge',
      params: {
        'p_workspace_id': workspaceId,
        'p_subject_member_id': subjectMemberId,
        'p_service_id': serviceId,
        'p_quantity': quantity,
        'p_period': ?period,
      },
    );
  }

  @override
  Future<String> buyPackage(String workspaceId, String packageId) async {
    final result = await _client.rpc<dynamic>(
      'buy_package',
      params: {'p_workspace_id': workspaceId, 'p_package_id': packageId},
    );
    return result as String;
  }

  @override
  Future<String> requestUsageCorrection(
    String recordId, {
    String reason = '',
  }) async {
    final id = await _client.rpc<dynamic>(
      'request_usage_correction',
      params: {'p_record_id': recordId, 'p_reason': reason},
    );
    return id as String;
  }

  @override
  Future<String> requestUsageRecordDelete(
    String recordId, {
    String reason = '',
  }) async {
    final id = await _client.rpc<dynamic>(
      'request_usage_record_delete',
      params: {'p_record_id': recordId, 'p_reason': reason},
    );
    return id as String;
  }
}
