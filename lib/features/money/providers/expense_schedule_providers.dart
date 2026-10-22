// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/navigation/event_sources.dart';
import '../../../core/trace/traced.dart';
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/expense_schedule.dart';
import '../presentation/purchase_source_opener.dart';
import 'money_providers.dart';
import 'purchase_providers.dart';

part 'expense_schedule_providers.g.dart';

/// #767 — my recurring expense schedules (or the workspace's, for the
/// finance/expense permissions — RLS decides what comes back).
@riverpod
Future<List<ExpenseSchedule>> expenseSchedules(Ref ref, String workspaceId) =>
    ref.watch(expenseRepositoryProvider).fetchExpenseSchedules(workspaceId);

/// The member's materialised occurrences — the awaiting and rejected
/// ones are what the Payments face presents for confirmation.
@riverpod
Future<List<ExpenseOccurrence>> expenseOccurrences(
  Ref ref,
  String workspaceId,
) =>
    ref.watch(expenseRepositoryProvider).fetchExpenseOccurrences(workspaceId);

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
    () => ref.read(expenseRepositoryProvider).sweepExpenseSchedules(workspaceId),
  );
}

/// #2573 — an expense request opens the purchase document it was filed as,
/// while purchases are on. Put in the scope's overrides by the composition
/// root (main and the demonstration).
final eventSourceOpenersFromMoney = eventSourceOpenersProvider.overrideWith(
  (ref) =>
      ref.watch(enabledFeaturesSyncProvider).contains(WorkspaceFeature.purchases)
      ? {'expense': PurchaseSourceOpener(ref.watch(purchaseRepositoryProvider))}
      : const <String, EventSourceOpener>{},
);
