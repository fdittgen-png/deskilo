// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'supabase_money_repository.dart';

// #2386 — part 2 of SupabaseMoneyRepository, split out of supabase_money_repository.dart so no
// file holds the whole class.
extension _SupabaseMoneyRepositoryPart2 on SupabaseMoneyRepository {

  Future<Map<String, String>> _fetchDunningHoldsImpl(String workspaceId) async {
    final rows = await _client
        .from('invoice_dunning_holds')
        .select('invoice_id, reason')
        .eq('workspace_id', workspaceId)
        .isFilter('released_at', null);
    return {
      for (final row in rows)
        row['invoice_id'] as String: row['reason'] as String,
    };
  }

  Future<void> _placeDunningHoldImpl(
    String invoiceId, {
    required String reason,
    String note = '',
  }) =>
      _client.rpc<void>('place_dunning_hold', params: {
        'p_invoice_id': invoiceId,
        'p_reason': reason,
        'p_note': note,
      });

  Future<void> _releaseDunningHoldImpl(String invoiceId) => _client.rpc<void>(
      'release_dunning_hold', params: {'p_invoice_id': invoiceId});

  Future<List<PaymentIntent>> _fetchPaymentIntentsImpl(String workspaceId) async {
    // #1310 S2 — paged.
    final rows = await fetchAllPages(
      table: 'payment_intents',
      build: () => _client
          .from('payment_intents')
          .select()
          .eq('workspace_id', workspaceId)
          .order('created_at', ascending: false)
          .order('id', ascending: true),
    );
    return rows
        .map((row) => PaymentIntent.fromRow(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<String> _recordPaymentImpl({
    required String workspaceId,
    required String memberId,
    required int amountCents,
    String note = '',
    PaymentMethod? method,
    DateTime? paidOn,
    String? period,
  }) async {
    final result = await _client.rpc<dynamic>('record_payment', params: {
      'p_workspace_id': workspaceId,
      'p_member_id': memberId,
      'p_amount_cents': amountCents,
      'p_note': note,
      'p_method': method?.wireName ?? '',
      // 0070 — a date, not a timestamp: what matters is the DAY the money
      // moved, in the payer's own calendar.
      'p_paid_on': paidOn == null
          ? null
          : isoDay(paidOn),
      'p_period': period,
    });
    return result as String;
  }

  Future<void> _recordServiceChargeImpl({
    required String workspaceId,
    required String subjectMemberId,
    required String serviceId,
    required int quantity,
    String? period,
  }) async {
    await _client.rpc<dynamic>('record_service_charge', params: {
      'p_workspace_id': workspaceId,
      'p_subject_member_id': subjectMemberId,
      'p_service_id': serviceId,
      'p_quantity': quantity,
      'p_period': ?period,
    });
  }

}
