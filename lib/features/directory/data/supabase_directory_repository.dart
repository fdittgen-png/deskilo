// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/backend_settings.dart';
import '../../../core/backend/connected_installations.dart';
import '../../../core/trace/trace_logger.dart';
import '../domain/public_workspace.dart';

class SupabaseDirectoryRepository implements DirectoryRepository {
  SupabaseDirectoryRepository(this.active, this.connections);
  final SupabaseClient active;
  final ConnectedInstallations? connections;
  @override
  Future<DirectoryPage> search(
    String query, {
    int sourcePage = 0,
    int workspacePage = 0,
  }) async {
    final origin = Uri.parse(active.rest.url).origin;
    final sources = await active
        .from('public_directory_sources')
        .select('origin,publishable_key')
        .order('origin')
        .range(sourcePage * 20, sourcePage * 20 + 19);
    final endpoints = <String, String>{
      origin: active.auth.headers['apikey']!,
      for (final row in sources)
        row['origin'] as String: row['publishable_key'] as String,
    };
    final failures = <String>[];
    var more = false;
    final results = await Future.wait(
      endpoints.entries.map((entry) async {
        if (validateBackendEndpoint(entry.key, entry.value) != null) {
          failures.add(entry.key);
          return <PublicWorkspace>[];
        }
        // Always anonymous, including preview/search of the current server. A
        // user's active bearer must never accompany catalogue fan-out requests.
        final client = SupabaseClient(
          entry.key,
          entry.value,
          httpClient: OriginOnlyClient(entry.key, http.Client()),
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );
        try {
          var request = client
              .from('public_workspace_cards')
              .select('workspace_id,name,document,updated_at');
          if (query.trim().isNotEmpty) {
            request = request.ilike(
              'search_text',
              '%${query.trim().replaceAll('%', '\\%').replaceAll('_', '\\_')}%',
            );
          }
          final rows = await request
              .order('name')
              .order('workspace_id')
              .range(workspacePage * 25, workspacePage * 25 + 24)
              .timeout(const Duration(seconds: 12));
          if (rows.length == 25) more = true;
          return [
            for (final row in rows)
              PublicWorkspace(
                row['workspace_id'] as String,
                entry.key,
                entry.value,
                Map<String, dynamic>.from(row['document'] as Map),
              ),
          ];
        } catch (e, st) {
          // Never include remote request headers or response bodies in diagnostics.
          TraceLogger.instance.warn(
            'directory',
            'public directory unavailable',
            error: e.runtimeType,
            stackTrace: st,
          );
          failures.add(entry.key);
          return <PublicWorkspace>[];
        } finally {
          await client.dispose();
        }
      }),
    );
    return DirectoryPage(
      results.expand((r) => r).toList(),
      unavailable: failures,
      moreSources: sources.length == 20,
      moreWorkspaces: more,
    );
  }

  @override
  Future<Map<String, dynamic>> ownPage(String workspace) => active.rpc(
    'my_workspace_public_page',
    params: {'p_workspace': workspace},
  );
  @override
  Future<Map<String, dynamic>> savePage(
    String workspace,
    Map<String, String> document,
    bool published,
  ) => active.rpc(
    'save_workspace_public_page',
    params: {
      'p_workspace': workspace,
      'p_document': document,
      'p_published': published,
    },
  );
  @override
  Future<void> register(String origin, String key) async {
    if (validateBackendEndpoint(origin, key) != null) {
      throw StateError('invalid public endpoint');
    }
    final client = SupabaseClient(
      origin,
      key,
      httpClient: OriginOnlyClient(origin, http.Client()),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    try {
      await client
          .from('public_workspace_cards')
          .select('workspace_id')
          .limit(1)
          .timeout(const Duration(seconds: 12));
    } finally {
      await client.dispose();
    }
    await active.rpc<void>(
      'register_public_directory',
      params: {'p_origin': canonicalBackendUrl(origin), 'p_key': key},
    );
  }

  @override
  Future<void> apply(PublicWorkspace workspace) async {
    final registry = connections;
    if (registry == null) throw StateError('sign in required');
    await registry.use(
      workspace.source,
      (client) => client.rpc<void>(
        'request_public_workspace_profile',
        params: {'p_workspace': workspace.id},
      ),
    );
  }
}
