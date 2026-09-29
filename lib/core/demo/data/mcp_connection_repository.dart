// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../features/mcp/domain/mcp_connection.dart';
import '../../../features/mcp/domain/mcp_usage.dart';

/// #1615 — in-memory consent for tests and Demo (which connects nothing:
/// the visitor is not eligible, so no request reaches Auth).
class FakeMcpConnectionRepository implements McpConnectionRepository {
  FakeMcpConnectionRepository({
    this.request,
    this.consent = const ConsentOptions(eligible: false, workspaces: []),
    this.installationId,
  });

  /// #1631 — the installation this fake answers revocations for, as the
  /// server names its own; null answers for nobody.
  final String? installationId;

  /// The next revocation answer, when a test needs the server to say
  /// something other than what was asked.
  McpRevocation? nextRevocation;

  AuthorizationRequest? request;
  ConsentOptions consent;
  final calls = <String>[];
  final prepared = <Map<String, List<String>>>[];

  /// #1809 — the optional fields each prepare consented, per workspace.
  final preparedFields = <Map<String, List<String>>>[];
  final live = <McpConnectionInfo>[];
  bool failFinalize = false;

  /// #1630 — the person's usage per assistant; Demo has none.
  final usage = <McpClientUsage>[];

  @override
  Future<AuthorizationRequest> authorization(String authorizationId) async =>
      request ?? AuthorizationRequest(authorizationId: authorizationId);

  @override
  Future<ConsentOptions> options() async => consent;

  @override
  Future<void> prepare(
    String clientId,
    String authorizationId,
    Map<String, List<String>> scopes, {
    Map<String, List<String>> optionalFields = const {},
  }) async {
    calls.add('prepare');
    prepared.add(scopes);
    preparedFields.add(optionalFields);
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
  Future<McpRevocation> revokeScope(
    String clientId,
    String workspaceId,
  ) async {
    calls.add('revokeScope:$clientId:$workspaceId');
    return _answer(
      McpRevocation(installationId: installationId, workspaces: {workspaceId}),
    );
  }

  @override
  Future<McpRevocation> disconnect(String clientId) async {
    calls.add('disconnect:$clientId');
    final gone = live.where((c) => c.clientId == clientId).toList();
    live.removeWhere((c) => c.clientId == clientId);
    return _answer(
      McpRevocation(
        installationId: installationId,
        workspaces: {
          for (final c in gone)
            for (final w in c.workspaces) w.id,
        },
        connectionEnded: gone.isNotEmpty,
      ),
    );
  }

  McpRevocation _answer(McpRevocation asked) {
    final next = nextRevocation;
    nextRevocation = null;
    return next ?? asked;
  }

  @override
  Future<List<McpClientUsage>> myUsage() async => List.of(usage);
}
