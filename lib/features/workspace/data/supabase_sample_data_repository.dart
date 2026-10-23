// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/sample_data.dart';

/// create_sample_data, clear_sample_data and sample_data_status (0546).
class SupabaseSampleDataRepository implements SampleDataRepository {
  const SupabaseSampleDataRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<SampleDataBatch?> status(String workspaceId) async =>
      SampleDataBatch.fromJson(
        await _client.rpc<Object?>(
          'sample_data_status',
          params: {'p_workspace_id': workspaceId},
        ),
      );

  @override
  Future<SampleDataBatch> fill(String workspaceId, String requestId) async =>
      _required(
        await _client.rpc<Object?>(
          'create_sample_data',
          params: {'p_workspace_id': workspaceId, 'p_request_id': requestId},
        ),
      );

  @override
  Future<SampleDataBatch> clear(String workspaceId, String batchId) async =>
      _required(
        await _client.rpc<Object?>(
          'clear_sample_data',
          params: {'p_workspace_id': workspaceId, 'p_batch_id': batchId},
        ),
      );

  static SampleDataBatch _required(Object? json) =>
      SampleDataBatch.fromJson(json) ??
      (throw const FormatException('the server named no sample data batch'));
}
