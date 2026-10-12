// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1615 — connecting an assistant: what Auth says it asks, what this person
// may offer it (per workspace, per operation), and the connections that
// exist. The assistant never widens its own consent: every call here runs
// from the app's own session.
import '../../../core/data/json_reader.dart';
import 'mcp_admin.dart' show mcpKnownOptionalFields;
import 'mcp_context.dart';
import 'mcp_usage.dart';

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
    this.optionalFields = const [],
  });
  final String id;
  final String name;
  final List<String> operations;

  /// #1809 — the optional fields offered here (the workspace policy
  /// within the installation maximum), or, on a connection, consented.
  final List<String> optionalFields;
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
    // Fail-closed (#2387): a malformed field reads as absent, and a
    // workspace without an id is left out.
    final r = JsonReader.of(json, context: 'consent_options');
    return ConsentOptions(
      eligible: r.textOrAbsent('eligibility') == 'eligible',
      workspaces: workspacesFrom(r.listOrAbsent('workspaces')),
    );
  }

  /// The workspaces of a consent answer; one without an id is left out.
  static List<ConsentWorkspace> workspacesFrom(List<Object?> rows) => [
    for (final raw in rows)
      if (JsonReader.orEmpty(raw, context: 'consent_workspace') case final w
          when w.textOrAbsent('workspace_id') != null)
        ConsentWorkspace(
          id: w.textOrAbsent('workspace_id')!,
          name: w.textOrAbsent('name') ?? '',
          operations: [for (final o in w.listOrAbsent('operations')) '$o'],
          optionalFields: mcpKnownOptionalFields(w.listOrAbsent('optional_fields')),
        ),
  ];
}

class McpConnectionInfo {
  const McpConnectionInfo({
    required this.clientId,
    required this.clientName,
    required this.workspaces,
    this.connectedAt,
    this.scope,
  });

  final String clientId;
  final String clientName;
  final List<ConsentWorkspace> workspaces;
  final DateTime? connectedAt;

  /// #1625 — the installation and account this connection lives on; a
  /// disconnect goes there, whatever the app shows by then.
  final McpInstanceRef? scope;

  McpConnectionInfo withScope(McpInstanceRef scope) => McpConnectionInfo(
    clientId: clientId,
    clientName: clientName,
    workspaces: workspaces,
    connectedAt: connectedAt,
    scope: scope,
  );

  static List<McpConnectionInfo> listFromJson(Object? json) => [
    for (final raw in json is List ? json : const [])
      ?_fromRow(raw),
  ];

  // Fail-closed (#2387): a row without a client id is left out.
  static McpConnectionInfo? _fromRow(Object? raw) {
    final c = JsonReader.orEmpty(raw, context: 'mcp_connection');
    final id = c.textOrAbsent('client_id');
    if (id == null) return null;
    return McpConnectionInfo(
      clientId: id,
      clientName: c.textOrAbsent('client_name') ?? id,
      connectedAt: DateTime.tryParse(c.textOrAbsent('connected_at') ?? '')
          ?.toUtc(),
      workspaces: ConsentOptions.workspacesFrom(c.listOrAbsent('workspaces')),
    );
  }
}

/// #1631 — what one revocation ended, as the server answered it: the
/// installation it ran on and the workspaces whose consent it revoked
/// there. A client invalidates exactly these context keys; it never
/// assumes the list it was showing, and never a blanket "this user".
class McpRevocation {
  const McpRevocation({
    required this.installationId,
    this.workspaces = const {},
    this.connectionEnded = false,
  });

  /// Null when the answer did not name one: then it is nobody's answer.
  final String? installationId;
  final Set<String> workspaces;

  /// The whole connection ended, not only some of its workspaces.
  final bool connectionEnded;

  static McpRevocation fromJson(Object? json) {
    final m = JsonReader.orEmpty(json, context: 'mcp_revocation');
    return McpRevocation(
      installationId: m.textOrAbsent('installation_id')?.toLowerCase(),
      workspaces: {
        for (final w in m.listOrAbsent('workspaces'))
          if (w is String) w,
      },
      connectionEnded: (m.intOrAbsent('connections') ?? 0) > 0,
    );
  }
}

abstract interface class McpConnectionRepository {
  Future<AuthorizationRequest> authorization(String authorizationId);
  Future<ConsentOptions> options();

  /// Records the chosen subset: workspace id → operations, and #1809
  /// workspace id → the optional fields consented there (none if absent).
  Future<void> prepare(
    String clientId,
    String authorizationId,
    Map<String, List<String>> scopes, {
    Map<String, List<String>> optionalFields = const {},
  });

  /// Tells Auth yes; answers where to send the browser.
  Future<String?> approve(String authorizationId);

  /// Makes the prepared connection usable, after Auth approved.
  Future<void> finalize(String authorizationId);

  /// Tells Auth no; answers where to send the browser.
  Future<String?> deny(String authorizationId);

  Future<List<McpConnectionInfo>> connections();

  /// #1631 — answers what the server actually ended.
  Future<McpRevocation> revokeScope(String clientId, String workspaceId);

  /// This database's connection and the provider grant.
  Future<McpRevocation> disconnect(String clientId);

  /// #1630 — this person's own usage today, per assistant.
  Future<List<McpClientUsage>> myUsage();
}
