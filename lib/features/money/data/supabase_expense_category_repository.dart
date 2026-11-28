// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4512 -- the expense categories of a business, read from the table and kept through the two commands (0998).
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/paged_fetch.dart';
import '../domain/expense_category.dart';

class SupabaseExpenseCategoryRepository implements ExpenseCategoryRepository {
  SupabaseExpenseCategoryRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<ExpenseCategory>> categories(String workspaceId) async {
    final rows = await fetchAllPages(table: 'expense_categories', build: () => _client.from('expense_categories')
        .select('id, code, label, sort_order, built_in, retired_at')
        .eq('workspace_id', workspaceId)
        .order('sort_order', ascending: true)
        .order('code', ascending: true));
    return [for (final row in rows) ExpenseCategory.fromJson(row)];
  }

  @override
  Future<ExpenseCategory> save(String workspaceId, {String? id, required String label, int? sortOrder, required String requestId}) async {
    final raw = await _client.rpc<Object?>('expense_category_save_v1', params: {
      'p_workspace_id': workspaceId,
      'p_request_id': requestId,
      'p_category': <String, Object?>{'id': ?id, 'label': label, 'sort_order': ?sortOrder},
    });
    return ExpenseCategory.fromJson(raw);
  }

  @override
  Future<void> setRetired(String workspaceId, String id, {required bool retired, required String requestId}) async {
    await _client.rpc<Object?>('expense_category_retire_v1', params: {
      'p_workspace_id': workspaceId,
      'p_request_id': requestId,
      'p_id': id,
      'p_retired': retired,
    });
  }
}
