// SPDX-License-Identifier: 0BSD
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/trace/traced.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/expense_repartition.dart';
import 'money_providers.dart';

part 'expense_repartition_providers.g.dart';

/// #828 — the workspace's distributions, newest first.
@riverpod
Future<List<ExpenseRepartition>> expenseRepartitions(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  return traced(
    'money',
    'expense repartitions',
    () => ref.read(moneyRepositoryProvider).fetchExpenseRepartitions(workspace.id),
  );
}
