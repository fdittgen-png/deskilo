// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1827 B — what the instance operator sees and switches for the whole
// installation's assistants (0341 `instance_mcp_overview`): readiness and
// its blockers, the database administrators, who could become one (an
// active identity binding), and the assistants' OAuth clients.
// #2145 (0359) — each client's recognised family and redirect hosts, the
// loopback switch and the published endpoint.
// #2145 (0360) — the active grants (marking an operator's and a
// self-grant), whether the operator may grant, the Google session and the
// latest endpoint probe.

import '../../../core/data/json_reader.dart';
import 'mcp_onboarding.dart';

class InstanceMember {
  const InstanceMember({
    required this.userId,
    required this.name,
    this.me = false,
    this.canProvision = false,
  });

  final String userId;
  final String name;
  final bool me;
  final bool canProvision;

  factory InstanceMember.fromJson(Map<String, dynamic> j) {
    final r = JsonReader(j, context: 'instance_member');
    return InstanceMember(
      userId: r.string('user_id'),
      name: r.stringOr('name'),
      me: r.boolOr('me', false),
      canProvision: r.boolOr('can_provision', false),
    );
  }
}

/// An assistant's OAuth client: `waiting` (registered itself, not yet
/// approved), `active` or `revoked`.
class InstanceClient {
  const InstanceClient({
    required this.clientId,
    required this.name,
    required this.status,
    this.registeredAt,
    this.family,
    this.redirectHosts = const [],
  });

  final String clientId;
  final String name;
  final String status;
  final DateTime? registeredAt;

  /// `claude`, `chatgpt` or `loopback` when every registered redirect is
  /// exactly that family's; null for anything else.
  final String? family;

  /// Where the client's answers go, as hosts (with ports).
  final List<String> redirectHosts;

  bool get approved => status == 'active';

  factory InstanceClient.fromJson(Map<String, dynamic> j) {
    final r = JsonReader(j, context: 'instance_client');
    return InstanceClient(
      clientId: r.string('client_id'),
      name: r.stringOr('name'),
      status: r.stringOr('status', 'waiting'),
      registeredAt: r.dateTimeOrNull('registered_at'),
      family: r.textOrAbsent('family'),
      redirectHosts: [for (final h in r.listOrAbsent('redirect_hosts')) '$h'],
    );
  }
}

/// An active assistant-access grant, as the console lists it.
class InstanceEligibleUser {
  const InstanceEligibleUser({
    required this.userId,
    required this.name,
    this.expiresAt,
    this.grantedByOperator = false,
    this.selfGrant = false,
    this.me = false,
  });

  final String userId;
  final String name;
  final DateTime? expiresAt;

  /// Granted by the instance operator (S3), not a database administrator.
  final bool grantedByOperator;

  /// The operator granted themselves: "Self-approved by operator".
  final bool selfGrant;
  final bool me;

  factory InstanceEligibleUser.fromJson(Map<String, dynamic> j) {
    final r = JsonReader(j, context: 'instance_eligible_user');
    return InstanceEligibleUser(
      userId: r.string('user_id'),
      name: r.stringOr('name'),
      expiresAt: r.dateTimeOrNull('expires_at'),
      grantedByOperator: r.stringOrNull('granted_by') == 'operator',
      selfGrant: r.boolOr('self_grant', false),
      me: r.boolOr('me', false),
    );
  }
}

class InstanceMcpOverview {
  const InstanceMcpOverview({
    required this.enabled,
    required this.blockers,
    required this.secondFactor,
    required this.administrators,
    required this.candidates,
    required this.clients,
    this.allowLoopbackClients = false,
    this.endpoint = const McpEndpointInfo(source: McpEndpointSource.unknown),
    this.endpointProbe = EndpointProbe.missing,
    this.eligibleUsers = const [],
    this.operatorGrantAvailable = false,
    this.googleSession = false,
  });

  final bool enabled;
  final List<String> blockers;

  /// This session holds the second factor (aal2) every change needs.
  final bool secondFactor;
  final List<InstanceMember> administrators;
  final List<InstanceMember> candidates;
  final List<InstanceClient> clients;

  /// "Allow desktop and command-line assistants" (loopback redirects).
  final bool allowLoopbackClients;

  /// The endpoint assistants are given.
  final McpEndpointInfo endpoint;

  /// The latest probe of the deployed endpoint; Turn on needs a fresh,
  /// deployed one.
  final EndpointProbe endpointProbe;
  final List<InstanceEligibleUser> eligibleUsers;

  /// No other database administrator exists, so the operator may grant.
  final bool operatorGrantAvailable;

  /// This session was opened with Google, which a grant needs.
  final bool googleSession;

  bool get ready => blockers.isEmpty;

  factory InstanceMcpOverview.fromJson(Map<String, dynamic> j) {
    final r = JsonReader(j, context: 'instance_mcp_overview');
    return InstanceMcpOverview(
      enabled: r.boolOr('enabled', false),
      blockers: [for (final b in r.list('blockers')) '$b'],
      secondFactor: r.boolOr('second_factor', false),
      administrators: r.objects(
        'administrators',
        (row) => InstanceMember.fromJson(row.json),
      ),
      candidates:
          r.objects('candidates', (row) => InstanceMember.fromJson(row.json)),
      clients: r.objects('clients', (row) => InstanceClient.fromJson(row.json)),
      allowLoopbackClients: r.boolOr('allow_loopback_clients', false),
      endpoint: McpEndpointInfo.fromJson(r.json['endpoint']),
      endpointProbe: r.json['endpoint_probe'] == null
          ? EndpointProbe.missing
          : EndpointProbe.fromJson(r.json['endpoint_probe']),
      eligibleUsers: r.objects(
        'eligible_users',
        (row) => InstanceEligibleUser.fromJson(row.json),
      ),
      operatorGrantAvailable: r.boolOr('operator_grant_available', false),
      googleSession: r.boolOr('google_session', false),
    );
  }
}
