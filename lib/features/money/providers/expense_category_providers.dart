// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4512 -- the expense categories of the current business, for the pickers and for the editor on the Master data page. The Demo
// overrides the repository.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/expense_category_commands.dart';
import '../data/supabase_expense_category_repository.dart';
import '../domain/expense_category.dart';
import 'credit_providers.dart' show moneyClientProvider;

export '../data/in_memory_expense_category_repository.dart' show InMemoryExpenseCategories;

/// The repository of the categories. The Demo overrides it.
final expenseCategoryRepositoryProvider = Provider<ExpenseCategoryRepository>(
  (ref) => SupabaseExpenseCategoryRepository(ref.watch(moneyClientProvider)),
);

/// Every category of [workspaceId], active and retired, in the business's order.
final expenseCategoriesProvider = FutureProvider.autoDispose.family<List<ExpenseCategory>, String>(
  (ref, workspaceId) => ref.watch(expenseCategoryRepositoryProvider).categories(workspaceId),
  retry: (_, _) => null,
);

/// What the owner does to the categories.
final expenseCategoryCommandsProvider = Provider<ExpenseCategoryCommands>(
  (ref) => ExpenseCategoryCommands(ref.watch(expenseCategoryRepositoryProvider)),
);
