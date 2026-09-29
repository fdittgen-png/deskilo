// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/mcp_connection.dart';
import '../domain/mcp_usage.dart';

/// #1615 — the consent RPCs (0276) and Auth's OAuth 2.1 server consent API.
class SupabaseMcpConnectionRepository implements McpConnectionRepository {
  const SupabaseMcpConnectionRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<AuthorizationRequest> authorization(String authorizationId) async {
    final answer = await _client.auth.oauth.getAuthorizationDetails(
      authorizationId,
    );
    return switch (answer) {
      OAuthAuthorizationRedirectResponse(:final redirectUrl) =>
        AuthorizationRequest(
          authorizationId: authorizationId,
          alreadyRedirectTo: redirectUrl,
        ),
      OAuthAuthorizationDetailsResponse(:final client) => AuthorizationRequest(
        authorizationId: authorizationId,
        clientId: client.clientId,
        clientName: client.clientName ?? client.clientId,
      ),
    };
  }

  @override
  Future<ConsentOptions> options() async => ConsentOptions.fromJson(
    await _client.rpc<Object?>('mcp_consent_options'),
  );

  @override
  Future<void> prepare(
    String clientId,
    String authorizationId,
    Map<String, List<String>> scopes, {
    Map<String, List<String>> optionalFields = const {},
  }) => _client.rpc<Object?>(
    'mcp_prepare_connection',
    params: {
      'p_client_id': clientId,
      'p_authorization_id': authorizationId,
      'p_scopes': [
        for (final e in scopes.entries)
          {
            'workspace_id': e.key,
            'operations': e.value,
            'optional_fields': optionalFields[e.key] ?? const <String>[],
          },
      ],
    },
  );

  @override
  Future<String?> approve(String authorizationId) async =>
      (await _client.auth.oauth.approveAuthorization(
        authorizationId,
      )).redirectUrl;

  @override
  Future<void> finalize(String authorizationId) => _client.rpc<Object?>(
    'mcp_finalize_connection',
    params: {'p_authorization_id': authorizationId},
  );

  @override
  Future<String?> deny(String authorizationId) async =>
      (await _client.auth.oauth.denyAuthorization(authorizationId)).redirectUrl;

  @override
  Future<List<McpConnectionInfo>> connections() async =>
      McpConnectionInfo.listFromJson(
        await _client.rpc<Object?>('my_mcp_connections'),
      );

  @override
  Future<McpRevocation> revokeScope(
    String clientId,
    String workspaceId,
  ) async => McpRevocation.fromJson(
    await _client.rpc<Object?>(
      'revoke_mcp_workspace_scope',
      params: {'p_client_id': clientId, 'p_workspace_id': workspaceId},
    ),
  );

  @override
  Future<McpRevocation> disconnect(String clientId) async {
    final ended = McpRevocation.fromJson(
      await _client.rpc<Object?>(
        'revoke_mcp_connection',
        params: {'p_client_id': clientId},
      ),
    );
    await _client.auth.oauth.revokeGrant(clientId);
    return ended;
  }

  @override
  Future<List<McpClientUsage>> myUsage() async => McpClientUsage.listFromJson(
    await _client.rpc<Object?>('mcp_usage_summary_mine'),
  );
}
