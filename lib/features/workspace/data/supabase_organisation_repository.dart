// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4006 — the reader's organisations, from the server's read (#4004).
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/organisation.dart';

class SupabaseOrganisationRepository implements OrganisationRepository {
  const SupabaseOrganisationRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Organisation>> myOrganisations() async {
    final rows = await _client.rpc<Object?>('my_organisations_v1');
    return [
      if (rows is List)
        for (final row in rows) Organisation.fromJson(row),
    ];
  }
}
