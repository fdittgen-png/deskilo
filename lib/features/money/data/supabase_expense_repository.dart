// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/expense_repartition.dart';
import '../domain/expense_repository.dart';
import '../domain/expense_schedule.dart';

/// #2591 C4 — the legacy expense adapter, with its own client. The bodies
/// are the ones that lived in the money repository's part files.
class SupabaseExpenseRepository implements ExpenseRepository {
  SupabaseExpenseRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<String> distributeExpense({
    required String workspaceId,
    required String title,
    required int amountCents,
    required RepartitionMethod method,
    required String period,
    required List<RepartitionShare> shares,
    String? sourceEventId,
  }) async {
    final id = await _client.rpc<dynamic>(
      'distribute_expense',
      params: {
        'p_workspace_id': workspaceId,
        'p_title': title,
        'p_amount_cents': amountCents,
        'p_method': method.name,
        'p_period': period,
        'p_shares': [for (final s in shares) s.toJson()],
        'p_source_event_id': sourceEventId,
      },
    );
    return id as String;
  }

  @override
  Future<List<ExpenseRepartition>> fetchExpenseRepartitions(
    String workspaceId,
  ) async {
    final rows = await _client
        .from('expense_repartitions')
        .select()
        .eq('workspace_id', workspaceId)
        .order('created_at', ascending: false);
    return [
      for (final row in rows)
        ExpenseRepartition.fromJson(Map<String, dynamic>.from(row as Map)),
    ];
  }

  @override
  Future<List<ExpenseSchedule>> fetchExpenseSchedules(
    String workspaceId,
  ) async {
    final rows = await _client
        .from('expense_schedules')
        .select()
        .eq('workspace_id', workspaceId)
        .order('created_at', ascending: false);
    return [
      for (final r in rows as List)
        ExpenseSchedule.fromDb(r as Map<String, dynamic>),
    ];
  }

  @override
  Future<String> createExpenseSchedule({
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
    final id = await _client.rpc<dynamic>(
      'create_expense_schedule',
      params: {
        'p_workspace_id': workspaceId,
        'p_title': title,
        'p_amount_cents': amountCents,
        'p_starts_on': startsOn.toIso8601String().substring(0, 10),
        'p_unit': unit.name,
        'p_every': every,
        'p_repeat_count': repeatCount,
        'p_ends_on': endsOn?.toIso8601String().substring(0, 10),
        'p_description': description,
      },
    );
    return id as String;
  }

  @override
  Future<void> cancelExpenseSchedule(String scheduleId) => _client.rpc(
    'cancel_expense_schedule',
    params: {'p_schedule_id': scheduleId},
  );

  @override
  Future<void> setExpenseScheduleVat(
    String scheduleId,
    Map<String, Object?>? vat,
  ) => _client.rpc<void>(
    'set_expense_schedule_vat',
    params: {'p_schedule_id': scheduleId, 'p_vat': vat},
  );

  @override
  Future<int> sweepExpenseSchedules(String workspaceId) async {
    final n = await _client.rpc<void>(
      'sweep_expense_schedules',
      params: {'p_workspace_id': workspaceId},
    );
    return (n as num?)?.toInt() ?? 0;
  }

  @override
  Future<List<ExpenseOccurrence>> fetchExpenseOccurrences(
    String workspaceId,
  ) async {
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

  @override
  Future<void> confirmExpenseOccurrence({
    required String occurrenceId,
    required int amountCents,
    String reason = '',
    String? note,
  }) => _client.rpc(
    'confirm_expense_occurrence',
    params: {
      'p_occurrence_id': occurrenceId,
      'p_amount_cents': amountCents,
      'p_reason': reason,
      'p_note': note,
    },
  );

  @override
  Future<String> submitExpense({
    required String workspaceId,
    required int amountCents,
    required String category,
    String description = '',
    Map<String, Object?>? supply,
    Map<String, Object?>? vat,
  }) async {
    final result = await _client.rpc<dynamic>(
      'submit_expense',
      params: {
        'p_workspace_id': workspaceId,
        'p_amount_cents': amountCents,
        'p_category': category,
        'p_description': description,
        // #731 — a supply: {name | service_id, quantity, unit_price_cents}.
        'p_supply': supply,
        // #2357 — sent only with VAT, so an older server still answers.
        'p_vat': ?vat,
      },
    );
    return result as String;
  }
}
