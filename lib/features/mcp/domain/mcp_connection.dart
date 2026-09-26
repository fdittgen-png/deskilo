// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1615 — connecting an assistant: what Auth says it asks, what this person
// may offer it (per workspace, per operation), and the connections that
// exist. The assistant never widens its own consent: every call here runs
// from the app's own session.

/// An assistant's pending authorization request, as Auth describes it.
class AuthorizationRequest {
  const AuthorizationRequest({
    required this.authorizationId,
    this.clientId = '',
    this.clientName = '',
    this.alreadyRedirectTo,
  });

  final String authorizationId;
  final String clientId;
  final String clientName;

  /// Auth already has consent for this client: go straight here.
  final String? alreadyRedirectTo;
}

class ConsentWorkspace {
  const ConsentWorkspace({
    required this.id,
    required this.name,
    required this.operations,
  });
  final String id;
  final String name;
  final List<String> operations;
}

class ConsentOptions {
  const ConsentOptions({required this.eligible, required this.workspaces});

  /// This database approved MCP for the person (#1611).
  final bool eligible;
  final List<ConsentWorkspace> workspaces;

  factory ConsentOptions.fromJson(Object? json) {
    if (json is! Map) {
      return const ConsentOptions(eligible: false, workspaces: []);
    }
    return ConsentOptions(
      eligible: json['eligibility'] == 'eligible',
      workspaces: [
        for (final w
            in json['workspaces'] is List
                ? json['workspaces'] as List
                : const [])
          if (w is Map && w['workspace_id'] is String)
            ConsentWorkspace(
              id: w['workspace_id'] as String,
              name: '${w['name'] ?? ''}',
              operations: [
                for (final o in (w['operations'] as List? ?? const [])) '$o',
              ],
            ),
      ],
    );
  }
}

class McpConnectionInfo {
  const McpConnectionInfo({
    required this.clientId,
    required this.clientName,
    required this.workspaces,
    this.connectedAt,
  });

  final String clientId;
  final String clientName;
  final List<ConsentWorkspace> workspaces;
  final DateTime? connectedAt;

  static List<McpConnectionInfo> listFromJson(Object? json) => [
    for (final c in json is List ? json : const [])
      if (c is Map && c['client_id'] is String)
        McpConnectionInfo(
          clientId: c['client_id'] as String,
          clientName: '${c['client_name'] ?? c['client_id']}',
          connectedAt: DateTime.tryParse('${c['connected_at']}')?.toUtc(),
          workspaces: ConsentOptions.fromJson({
            'workspaces': c['workspaces'],
          }).workspaces,
        ),
  ];
}

abstract interface class McpConnectionRepository {
  Future<AuthorizationRequest> authorization(String authorizationId);
  Future<ConsentOptions> options();

  /// Records the chosen subset: workspace id → operations.
  Future<void> prepare(
    String clientId,
    String authorizationId,
    Map<String, List<String>> scopes,
  );

  /// Tells Auth yes; answers where to send the browser.
  Future<String?> approve(String authorizationId);

  /// Makes the prepared connection usable, after Auth approved.
  Future<void> finalize(String authorizationId);

  /// Tells Auth no; answers where to send the browser.
  Future<String?> deny(String authorizationId);

  Future<List<McpConnectionInfo>> connections();
  Future<void> revokeScope(String clientId, String workspaceId);

  /// This database's connection and the provider grant.
  Future<void> disconnect(String clientId);
}
