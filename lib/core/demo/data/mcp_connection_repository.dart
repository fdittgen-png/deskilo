// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../features/mcp/domain/mcp_connection.dart';

/// #1615 — in-memory consent for tests and Demo (which connects nothing:
/// the visitor is not eligible, so no request reaches Auth).
class FakeMcpConnectionRepository implements McpConnectionRepository {
  FakeMcpConnectionRepository({
    this.request,
    this.consent = const ConsentOptions(eligible: false, workspaces: []),
  });

  AuthorizationRequest? request;
  ConsentOptions consent;
  final calls = <String>[];
  final prepared = <Map<String, List<String>>>[];
  final live = <McpConnectionInfo>[];
  bool failFinalize = false;

  @override
  Future<AuthorizationRequest> authorization(String authorizationId) async =>
      request ?? AuthorizationRequest(authorizationId: authorizationId);

  @override
  Future<ConsentOptions> options() async => consent;

  @override
  Future<void> prepare(
    String clientId,
    String authorizationId,
    Map<String, List<String>> scopes,
  ) async {
    calls.add('prepare');
    prepared.add(scopes);
  }

  @override
  Future<String?> approve(String authorizationId) async {
    calls.add('approve');
    return 'https://assistant.test/callback?code=1';
  }

  @override
  Future<void> finalize(String authorizationId) async {
    calls.add('finalize');
    if (failFinalize) throw StateError('finalize');
  }

  @override
  Future<String?> deny(String authorizationId) async {
    calls.add('deny');
    return 'https://assistant.test/callback?error=access_denied';
  }

  @override
  Future<List<McpConnectionInfo>> connections() async => List.of(live);

  @override
  Future<void> revokeScope(String clientId, String workspaceId) async =>
      calls.add('revokeScope:$clientId:$workspaceId');

  @override
  Future<void> disconnect(String clientId) async {
    calls.add('disconnect:$clientId');
    live.removeWhere((c) => c.clientId == clientId);
  }
}
