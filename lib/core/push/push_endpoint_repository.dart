// SPDX-License-Identifier: MIT
import 'package:supabase_flutter/supabase_flutter.dart';

/// Server-side registry of this device's push endpoint, one row per
/// membership (pushes are member-scoped, spec §8). RLS restricts rows to
/// the signed-in user's own members.
abstract class PushEndpointRepository {
  Future<void> saveEndpoint({
    required List<String> memberIds,
    required String endpoint,
  });

  Future<void> removeEndpoint(String endpoint);
}

class SupabasePushEndpointRepository implements PushEndpointRepository {
  SupabasePushEndpointRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> saveEndpoint({
    required List<String> memberIds,
    required String endpoint,
  }) async {
    if (memberIds.isEmpty) return;
    await _client.from('push_endpoints').upsert(
      [
        for (final memberId in memberIds)
          {'member_id': memberId, 'endpoint': endpoint},
      ],
      onConflict: 'member_id,endpoint',
    );
  }

  @override
  Future<void> removeEndpoint(String endpoint) async {
    await _client.from('push_endpoints').delete().eq('endpoint', endpoint);
  }
}
