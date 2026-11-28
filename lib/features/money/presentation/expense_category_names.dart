// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4512 -- how an expense category reads, and which are on offer. A category with a label of its own reads as the business wrote it;
// a built-in one that was never renamed reads in the app's words, in the member's language.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/ui/app_snack.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/expense_category.dart';
import '../providers/expense_category_providers.dart';

/// The categories a new expense may be filed under, in the business's order.
List<ExpenseCategory> activeExpenseCategories(List<ExpenseCategory> all) => [
  for (final c in all)
    if (!c.retired) c,
];

/// The name of [category] as the member reads it.
String expenseCategoryName(AppLocalizations l10n, ExpenseCategory category) {
  final own = category.label.trim();
  if (own.isNotEmpty) return own;
  return switch (category.code) {
    BuiltInExpenseCategory.coffee => l10n.expenseCategoryCoffee,
    BuiltInExpenseCategory.supplies => l10n.expenseCategorySupplies,
    BuiltInExpenseCategory.equipment => l10n.expenseCategoryEquipment,
    BuiltInExpenseCategory.scheduled => l10n.expenseCategoryScheduled,
    _ => l10n.expenseCategoryOther,
  };
}

/// The categories a new expense may be filed under in [workspaceId], read before its sheet opens; with none on offer says so on
/// [context] and answers null.
Future<List<ExpenseCategory>?> expenseCategoriesOnOffer(BuildContext context, WidgetRef ref, String workspaceId) async {
  final active = activeExpenseCategories(await ref.read(expenseCategoriesProvider(workspaceId).future));
  if (active.isNotEmpty) return active;
  if (context.mounted) AppSnack.error(context, context.l10n.expenseCategoriesEmpty);
  return null;
}
