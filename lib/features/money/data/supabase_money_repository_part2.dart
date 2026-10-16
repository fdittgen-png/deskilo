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

  Future<List<ExpenseSchedule>> _fetchExpenseSchedulesImpl(String workspaceId) async {
    final rows = await _client
        .from('expense_schedules')
        .select()
        .eq('workspace_id', workspaceId)
        .order('created_at', ascending: false);
    return [
      for (final r in rows as List) ExpenseSchedule.fromDb(r as Map<String, dynamic>),
    ];
  }

  Future<String> _createExpenseScheduleImpl({
    required String workspaceId,
    required String title,
    required int amountCents,
    required DateTime startsOn,
    required ScheduleUnit unit,
    int every = 1,
    int? repeatCount,
    DateTime? endsOn,
    String description = '',
  }) async {
    final id = await _client.rpc<dynamic>('create_expense_schedule', params: {
      'p_workspace_id': workspaceId,
      'p_title': title,
      'p_amount_cents': amountCents,
      'p_starts_on': startsOn.toIso8601String().substring(0, 10),
      'p_unit': unit.name,
      'p_every': every,
      'p_repeat_count': repeatCount,
      'p_ends_on': endsOn?.toIso8601String().substring(0, 10),
      'p_description': description,
    });
    return id as String;
  }

  Future<void> _cancelExpenseScheduleImpl(String scheduleId) => _client
      .rpc('cancel_expense_schedule', params: {'p_schedule_id': scheduleId});

  Future<int> _sweepExpenseSchedulesImpl(String workspaceId) async {
    final n = await _client
        .rpc<void>('sweep_expense_schedules',
            params: {'p_workspace_id': workspaceId});
    return (n as num?)?.toInt() ?? 0;
  }

  Future<List<ExpenseOccurrence>> _fetchExpenseOccurrencesImpl(
      String workspaceId) async {
    final rows = await _client
        .from('expense_occurrences')
        .select('*, expense_schedules(title, amount_cents)')
        .eq('workspace_id', workspaceId)
        .order('due_on');
    return [
      for (final r in rows as List)
        ExpenseOccurrence.fromDb(r as Map<String, dynamic>),
    ];
  }

  Future<void> _confirmExpenseOccurrenceImpl({
    required String occurrenceId,
    required int amountCents,
    String reason = '',
    String? note,
  }) =>
      _client.rpc('confirm_expense_occurrence', params: {
        'p_occurrence_id': occurrenceId,
        'p_amount_cents': amountCents,
        'p_reason': reason,
        'p_note': note,
      });

  Future<String> _submitExpenseImpl({
    required String workspaceId,
    required int amountCents,
    required String category,
    String description = '',
    Map<String, Object?>? supply,
    Map<String, Object?>? vat,
  }) async {
    final result = await _client.rpc<dynamic>('submit_expense', params: {
      'p_workspace_id': workspaceId,
      'p_amount_cents': amountCents,
      'p_category': category,
      'p_description': description,
      // #731 — a supply: {name | service_id, quantity, unit_price_cents}.
      'p_supply': supply,
      // #2357 — sent only with VAT, so an older server still answers.
      'p_vat': ?vat,
    });
    return result as String;
  }

  Future<List<FeeBand>> _fetchFeeBandsImpl(String workspaceId) async {
    final rows = await _client
        .from('fee_bands')
        .select()
        .eq('workspace_id', workspaceId)
        .order('from_pct', ascending: true);
    return rows
        .map(
          (row) => FeeBand(
            system: SystemColumns.fromRow(row),
            id: row['id'] as String,
            workspaceId: row['workspace_id'] as String,
            fromPct: row['from_pct'] as int,
            toPct: row['to_pct'] as int,
            feeCents: row['fee_cents'] as int,
            overageFeeCents: row['overage_fee_cents'] as int,
          ),
        )
        .toList();
  }
}
