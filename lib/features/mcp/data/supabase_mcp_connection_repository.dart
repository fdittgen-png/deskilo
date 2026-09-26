// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/mcp_connection.dart';

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
    Map<String, List<String>> scopes,
  ) => _client.rpc<Object?>(
    'mcp_prepare_connection',
    params: {
      'p_client_id': clientId,
      'p_authorization_id': authorizationId,
      'p_scopes': [
        for (final e in scopes.entries)
          {'workspace_id': e.key, 'operations': e.value},
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
  Future<void> revokeScope(String clientId, String workspaceId) =>
      _client.rpc<Object?>(
        'revoke_mcp_workspace_scope',
        params: {'p_client_id': clientId, 'p_workspace_id': workspaceId},
      );

  @override
  Future<void> disconnect(String clientId) async {
    await _client.rpc<Object?>(
      'revoke_mcp_connection',
      params: {'p_client_id': clientId},
    );
    await _client.auth.oauth.revokeGrant(clientId);
  }
}
