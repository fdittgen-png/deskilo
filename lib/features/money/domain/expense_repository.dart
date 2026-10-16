// SPDX-License-Identifier: AGPL-3.0-or-later
import 'expense_repartition.dart';
import 'expense_schedule.dart';

/// #2591 C4 — the narrow adapter the expense and schedule commands use
/// until the purchase repository (#2573) takes their source bridge:
/// submit an expense, share one, and run recurring expenses.
/// Nothing is added here — a new purchase capability belongs to #2573.
abstract interface class ExpenseRepository {
  /// #828 — distributes [amountCents] (negative = a reversal) over the
  /// members in [shares], as adjustment ledger rows on [period] that the
  /// period's usage invoice picks up — through the validation framework
  /// (RPC `distribute_expense`, 0147). Returns the repartition id.
  Future<String> distributeExpense({
    required String workspaceId,
    required String title,
    required int amountCents,
    required RepartitionMethod method,
    required String period,
    required List<RepartitionShare> shares,
    String? sourceEventId,
  });

  /// The workspace's distributions, newest first (0147).
  Future<List<ExpenseRepartition>> fetchExpenseRepartitions(String workspaceId);

  /// #767 — my recurring expense schedules (admins with the expense or
  /// finance permission see the workspace's, per RLS).
  Future<List<ExpenseSchedule>> fetchExpenseSchedules(String workspaceId);

  /// Schedules a recurring expense; the schedule itself awaits the
  /// `expense_schedule` validation rules. Returns the schedule id.
  Future<String> createExpenseSchedule({
    required String workspaceId,
    required String title,
    required int amountCents,
    required DateTime startsOn,
    required ScheduleUnit unit,
    int every,
    int? repeatCount,
    DateTime? endsOn,
    String description,
  });

  /// Ends a schedule (the member's own, or with approveExpenses).
  Future<void> cancelExpenseSchedule(String scheduleId);

  /// #2357 — the VAT every occurrence of a schedule carries ({percent,
  /// deductible_pct, asset}); null clears it.
  Future<void> setExpenseScheduleVat(
    String scheduleId,
    Map<String, Object?>? vat,
  );

  /// Materialises every due occurrence (any active member; the morning
  /// cron is the other clock). Returns how many it created.
  Future<int> sweepExpenseSchedules(String workspaceId);

  /// My occurrences (awaiting, pending, added, rejected — client sorts).
  Future<List<ExpenseOccurrence>> fetchExpenseOccurrences(String workspaceId);

  /// Answers a presented occurrence: at the validated amount it lands
  /// settled; at a different amount [reason] is mandatory and the
  /// expense validation decides. A rejected one is resent the same way.
  Future<void> confirmExpenseOccurrence({
    required String occurrenceId,
    required int amountCents,
    String reason,
    String? note,
  });

  /// Submits a community expense (spec §9); another admin must approve
  /// before the credit exists. Returns the pending event id.
  Future<String> submitExpense({
    required String workspaceId,
    required int amountCents,
    required String category,
    String description,

    /// #731 — when the expense is a SUPPLY for the space: name (or
    /// service_id of an existing item), quantity, unit_price_cents.
    Map<String, Object?>? supply,

    /// #2357 — input VAT: {percent, deductible_pct}; null without VAT.
    Map<String, Object?>? vat,
  });
}
