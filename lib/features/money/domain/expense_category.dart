// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4512 (FIN-06) -- a category an expense or a receipt is filed under: the business's own record. A built-in one (coffee,
// supplies, equipment, other) has no label of its own until the owner renames it, and then reads in the app's words; an
// expense keeps the label its category had when it was filed, so a rename or a retirement changes nothing already filed.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

/// One category of a business.
class ExpenseCategory {
  const ExpenseCategory({
    required this.id,
    required this.code,
    required this.label,
    required this.sortOrder,
    required this.builtIn,
    required this.retired,
  });

  factory ExpenseCategory.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'expense_categories');
    return ExpenseCategory(
      id: r.string('id'),
      code: r.string('code'),
      label: r.stringOr('label'),
      sortOrder: r.integer('sort_order'),
      builtIn: r.isTrue('built_in'),
      retired: r.isTrue('retired') || r.stringOrNull('retired_at') != null,
    );
  }

  final String id;

  /// The stable key of the category: never changes.
  final String code;

  /// The business's own words; empty for a built-in one that keeps the app's.
  final String label;
  final int sortOrder;
  final bool builtIn;

  /// Retired: not offered for a new expense, kept on what was filed under it.
  final bool retired;

  ExpenseCategory copyWith({String? label, int? sortOrder, bool? retired}) => ExpenseCategory(
    id: id,
    code: code,
    label: label ?? this.label,
    sortOrder: sortOrder ?? this.sortOrder,
    builtIn: builtIn,
    retired: retired ?? this.retired,
  );
}

/// Reads and keeps the expense categories of a business.
abstract interface class ExpenseCategoryRepository {
  /// Every category, active and retired, in the order the business set.
  Future<List<ExpenseCategory>> categories(String workspaceId);

  /// A new category (no [id]), or a rename and a new place of [id]. An empty [label] on a built-in one gives it the app's words back.
  Future<ExpenseCategory> save(String workspaceId, {String? id, required String label, int? sortOrder, required String requestId});

  /// Retires [id], or brings it back.
  Future<ExpenseCategory> setRetired(String workspaceId, String id, {required bool retired, required String requestId});
}
