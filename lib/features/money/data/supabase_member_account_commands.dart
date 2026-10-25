// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/time/date_text.dart';
import '../domain/member_account_commands.dart';
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
