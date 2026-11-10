// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3550 — the active kinds of public.business_kinds, readable by everyone
// signed in (0703).
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/business_kind.dart';

class SupabaseBusinessKindRepository implements BusinessKindRepository {
  const SupabaseBusinessKindRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<BusinessKind>> kinds() async {
    final rows = await _client
        .from('business_kinds')
        .select('code, sort_order, feature_profile')
        .eq('active', true)
        .order('sort_order');
    return [for (final r in rows) BusinessKind.fromJson(r)];
  }

  @override
  Future<void> setKind(
    String workspaceId, {
    required String kind,
    required List<String> moreKinds,
  }) => _client.rpc<Object?>(
    'set_business_kind',
    params: {
      'p_workspace': workspaceId,
      'p_kind': kind,
      'p_more_kinds': moreKinds.join(','),
    },
  );
}
