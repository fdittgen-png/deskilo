// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1827 B — what the instance operator sees and switches for the whole
// installation's assistants (0341 `instance_mcp_overview`): readiness and
// its blockers, the database administrators, who could become one (an
// active identity binding), and the assistants' OAuth clients.
// #2145 (0356) — each client's recognised family and redirect hosts, the
// loopback switch and the published endpoint.
// #2145 (0357) — the active grants (marking an operator's and a
// self-grant), whether the operator may grant, the Google session and the
// latest endpoint probe.

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

  factory InstanceMember.fromJson(Map<String, dynamic> j) => InstanceMember(
    userId: j['user_id'] as String,
    name: j['name'] as String? ?? '',
    me: j['me'] == true,
    canProvision: j['can_provision'] == true,
  );
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

  factory InstanceClient.fromJson(Map<String, dynamic> j) => InstanceClient(
    clientId: j['client_id'] as String,
    name: j['name'] as String? ?? '',
    status: j['status'] as String? ?? 'waiting',
    registeredAt: DateTime.tryParse(j['registered_at'] as String? ?? ''),
    family: j['family'] is String ? j['family'] as String : null,
    redirectHosts: [
      for (final h in j['redirect_hosts'] is List
          ? j['redirect_hosts'] as List
          : const [])
        '$h',
    ],
  );
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

  factory InstanceEligibleUser.fromJson(Map<String, dynamic> j) =>
      InstanceEligibleUser(
        userId: j['user_id'] as String,
        name: j['name'] as String? ?? '',
        expiresAt: DateTime.tryParse(j['expires_at'] as String? ?? ''),
        grantedByOperator: j['granted_by'] == 'operator',
        selfGrant: j['self_grant'] == true,
        me: j['me'] == true,
      );
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
    List<Map<String, dynamic>> rows(String key) => [
      for (final r in (j[key] as List? ?? const []))
        Map<String, dynamic>.from(r as Map),
    ];
    return InstanceMcpOverview(
      enabled: j['enabled'] == true,
      blockers: [for (final b in (j['blockers'] as List? ?? const [])) '$b'],
      secondFactor: j['second_factor'] == true,
      administrators: rows('administrators')
          .map(InstanceMember.fromJson)
          .toList(),
      candidates: rows('candidates').map(InstanceMember.fromJson).toList(),
      clients: rows('clients').map(InstanceClient.fromJson).toList(),
      allowLoopbackClients: j['allow_loopback_clients'] == true,
      endpoint: McpEndpointInfo.fromJson(j['endpoint']),
      endpointProbe: j['endpoint_probe'] == null
          ? EndpointProbe.missing
          : EndpointProbe.fromJson(j['endpoint_probe']),
      eligibleUsers: rows('eligible_users')
          .map(InstanceEligibleUser.fromJson)
          .toList(),
      operatorGrantAvailable: j['operator_grant_available'] == true,
      googleSession: j['google_session'] == true,
    );
  }
}
