// SPDX-License-Identifier: 0BSD
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/trace/traced.dart';
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/expense_schedule.dart';
import 'money_providers.dart';

part 'expense_schedule_providers.g.dart';

/// #767 — my recurring expense schedules (or the workspace's, for the
/// finance/expense permissions — RLS decides what comes back).
@riverpod
Future<List<ExpenseSchedule>> expenseSchedules(Ref ref, String workspaceId) =>
    ref.watch(moneyRepositoryProvider).fetchExpenseSchedules(workspaceId);

/// The member's materialised occurrences — the awaiting and rejected
/// ones are what the Payments face presents for confirmation.
@riverpod
Future<List<ExpenseOccurrence>> expenseOccurrences(
  Ref ref,
  String workspaceId,
) =>
    ref.watch(moneyRepositoryProvider).fetchExpenseOccurrences(workspaceId);

/// #767 — the client-side clock for scheduled expenses: the first member
/// who opens Finances in a session materialises what is due (the
/// morning cron is the other clock). Idempotent — the sweep only fills
/// gaps up to today.
@Riverpod(keepAlive: true)
Future<int> expenseScheduleSweep(Ref ref, String workspaceId) async {
  final features = ref.read(enabledFeaturesSyncProvider);
  if (!features.contains(WorkspaceFeature.scheduledExpenses)) return 0;
  return traced(
    'money',
    'sweep expense schedules',
    () => ref.read(moneyRepositoryProvider).sweepExpenseSchedules(workspaceId),
  );
}
