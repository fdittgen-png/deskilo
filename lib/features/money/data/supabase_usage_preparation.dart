// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/json_reader.dart';
import '../domain/usage_record.dart';

/// `prepare_usage_period_v1` (0477): the explicit business command around the
/// idempotent materialiser of a month's usage records.
class SupabaseUsagePreparation implements UsagePreparation {
  const SupabaseUsagePreparation(this._client);

  final SupabaseClient _client;

  @override
  Future<int> prepare(
    String workspaceId,
    String period,
    String requestId,
  ) async {
    final json = await _client.rpc<Object?>(
      'prepare_usage_period_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_period': period,
        'p_request_id': requestId,
      },
    );
    return JsonReader.of(json, context: 'prepare_usage_period_v1')
        .integer('prepared');
  }
}
