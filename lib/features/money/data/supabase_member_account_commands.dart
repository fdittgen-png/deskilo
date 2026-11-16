// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/member_account_commands.dart';
import '../domain/payment_claims.dart';
import '../domain/payment_method.dart';

/// #2591 — payments, service charges, packages and usage requests recorded
/// against a member, with its own client. The bodies are the ones that lived in
/// the money repository and its part files.
class SupabaseMemberAccountCommands implements MemberAccountCommands {
  SupabaseMemberAccountCommands(this._client);

  final SupabaseClient _client;

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
    final result = await _client.rpc<dynamic>(
      'record_payment',
      params: {
        'p_workspace_id': workspaceId,
        'p_member_id': memberId,
        'p_amount_cents': amountCents,
        'p_note': note,
        'p_method': method?.wireName ?? '',
        // 0070 — a date, not a timestamp: what matters is the DAY the money
        // moved, in the payer's own calendar.
        'p_paid_on': paidOn == null ? null : isoDay(paidOn),
        'p_period': period,
      },
    );
    return result as String;
  }

  @override
  Future<String> declareInvoicesPaid({
    required String workspaceId,
    required String memberId,
    required InvoiceClaim claim,
  }) async {
    final result = await _claimed(
      () => _client.rpc<Object?>(
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
        },
      ),
    );
    return result as String;
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
