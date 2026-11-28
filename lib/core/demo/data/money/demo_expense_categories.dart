// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4512 -- the Demo's expense categories: the five a business starts with (scheduled retired), kept in memory with the rules the
// server applies: a name is required for one that is not built in, an active name is kept once (case-folded), a code never moves,
// nothing is deleted.
import 'package:deskilo/features/money/domain/expense_category.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

class DemoExpenseCategories implements ExpenseCategoryRepository {
  final Map<String, List<ExpenseCategory>> _byWorkspace = {};
  int _next = 0;

  List<ExpenseCategory> _of(String workspaceId) => _byWorkspace.putIfAbsent(workspaceId, () => [
    for (final (i, code) in const ['coffee', 'supplies', 'equipment', 'other', 'scheduled'].indexed)
      ExpenseCategory(id: '$workspaceId-cat-$code', code: code, label: '', sortOrder: (i + 1) * 10, builtIn: true, retired: code == 'scheduled'),
  ]);

  PostgrestException _refused(String detail) => PostgrestException(message: 'expense category: $detail', code: 'DKX01', details: detail);

  @override
  Future<List<ExpenseCategory>> categories(String workspaceId) async => [
    for (final c in [..._of(workspaceId)]..sort((a, b) => a.sortOrder != b.sortOrder ? a.sortOrder.compareTo(b.sortOrder) : a.code.compareTo(b.code))) c,
  ];

  @override
  Future<ExpenseCategory> save(String workspaceId, {String? id, required String label, int? sortOrder, required String requestId}) async {
    final all = _of(workspaceId);
    final at = id == null ? -1 : all.indexWhere((c) => c.id == id);
    if (id != null && at < 0) throw _refused('expense_category_unknown');
    final name = label.trim();
    final builtIn = at >= 0 && all[at].builtIn;
    if (name.length > 80) throw _refused('label_too_long');
    if (name.isEmpty && !builtIn) throw _refused('label_required');
    if (name.isNotEmpty && all.any((c) => !c.retired && c.id != id && c.label.trim().toLowerCase() == name.toLowerCase())) {
      throw _refused('label_taken');
    }
    if (at >= 0) return all[at] = all[at].copyWith(label: name, sortOrder: sortOrder);
    final made = ExpenseCategory(
      id: '$workspaceId-cat-${_next++}',
      code: 'c_${(_next + 1000).toRadixString(16)}',
      label: name,
      sortOrder: sortOrder ?? 1000,
      builtIn: false,
      retired: false,
    );
    all.add(made);
    return made;
  }

  @override
  Future<ExpenseCategory> setRetired(String workspaceId, String id, {required bool retired, required String requestId}) async {
    final all = _of(workspaceId);
    final at = all.indexWhere((c) => c.id == id);
    if (at < 0) throw _refused('expense_category_unknown');
    final c = all[at];
    if (!retired && c.retired && c.label.trim().isNotEmpty && all.any((o) => !o.retired && o.id != id && o.label.trim().toLowerCase() == c.label.trim().toLowerCase())) {
      throw _refused('label_taken');
    }
    return all[at] = c.copyWith(retired: retired);
  }
}
