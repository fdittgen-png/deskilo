// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/template_search_page.dart';

/// #1659 — search_workspace_templates (0283).
class SupabaseTemplateSearchRepository implements TemplateSearchRepository {
  const SupabaseTemplateSearchRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<TemplateSearchPage> search({
    String query = '',
    List<String> required = const [],
    List<String> excluded = const [],
    int limit = 25,
    String? cursor,
  }) async => TemplateSearchPage.fromJson(
    await _client.rpc<Object?>(
      'search_workspace_templates',
      params: {
        'p_query': query,
        'p_required': required,
        'p_excluded': excluded,
        'p_limit': limit,
        'p_cursor': cursor,
      },
    ),
  );
}
