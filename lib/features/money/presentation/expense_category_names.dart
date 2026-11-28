// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4512 -- how an expense category reads, and which are on offer. A category with a label of its own reads as the business wrote it;
// a built-in one that was never renamed reads in the app's words, in the member's language.
import '../../../l10n/app_localizations.dart';
import '../domain/expense_category.dart';

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
