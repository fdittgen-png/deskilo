// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1827 B — what the instance operator sees and switches for the whole
// installation's assistants (0340 `instance_mcp_overview`): readiness and
// its blockers, the database administrators, who could become one (an
// active identity binding), and the assistants' OAuth clients.

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
  });

  final String clientId;
  final String name;
  final String status;
  final DateTime? registeredAt;

  bool get approved => status == 'active';

  factory InstanceClient.fromJson(Map<String, dynamic> j) => InstanceClient(
    clientId: j['client_id'] as String,
    name: j['name'] as String? ?? '',
    status: j['status'] as String? ?? 'waiting',
    registeredAt: DateTime.tryParse(j['registered_at'] as String? ?? ''),
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
  });

  final bool enabled;
  final List<String> blockers;

  /// This session holds the second factor (aal2) every change needs.
  final bool secondFactor;
  final List<InstanceMember> administrators;
  final List<InstanceMember> candidates;
  final List<InstanceClient> clients;

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
    );
  }
}
