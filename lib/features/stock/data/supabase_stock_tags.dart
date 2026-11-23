// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/stock_bulk_read.dart';
import '../domain/stock_tags.dart';
import 'stock_rpc.dart';

/// #4363 -- `stock_tags_v1`, `stock_tag_bind_v1` and `stock_tag_retire_v1` behind the port. An answer of the
/// wrong shape throws: it is never shown as "no tags".
class SupabaseStockTags implements StockTags {
  SupabaseStockTags(this._client);

  final SupabaseClient _client;

  Future<Object?> _call(String fn, Map<String, Object?> params) => StockRpc(_client).run(fn, params);

  @override
  Future<List<StockTag>> tags(String workspaceId, TagOwner owner) async {
    final answer = await _call('stock_tags_v1', {'p_workspace_id': workspaceId, 'p_owner': owner.filter});
    if (answer is! List) throw const FormatException('stock_tags_v1 did not answer a list');
    return [for (final row in answer) StockTag.fromJson(row)];
  }

  @override
  Future<TagBound> bind(String workspaceId, {required String requestId, required String code, required TagOwner owner}) async =>
      TagBound.fromJson(
        await _call('stock_tag_bind_v1', {
          'p_workspace_id': workspaceId,
          'p_request_id': requestId,
          'p_tag': {'code': code, 'owner': owner.toJson()},
        }),
      );

  @override
  Future<void> retire(String workspaceId, {required String requestId, required String code, required String reason}) async {
    await _call('stock_tag_retire_v1', {
      'p_workspace_id': workspaceId,
      'p_request_id': requestId,
      'p_code': code,
      'p_reason': reason,
    });
  }

  @override
  Future<BulkResolution> resolveCodes(String workspaceId, List<String> codes) async => BulkResolution.fromJson(
    await StockRpc(_client).object('stock_resolve_codes_v1', {'p_workspace_id': workspaceId, 'p_codes': codes}),
  );
}
