// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2145 — the server contracts behind "Connect an assistant" (0354):
// what the consent page learns at load (the client's approval status, its
// redirect host and who decides the first open step), the MCP endpoint the
// installation publishes, and the installation notices the instance
// operator receives. Every parser is fail-safe: a value this build does
// not know reads as unknown, never as approved.

/// The operator's decision on an assistant's OAuth client.
enum McpClientApproval {
  approved,
  waiting,
  blocked,
  unknown;

  static McpClientApproval parse(Object? raw) => switch (raw) {
    'approved' => approved,
    'waiting' => waiting,
    'blocked' => blocked,
    _ => unknown,
  };
}

/// The assistant a pending authorization names.
class ConsentClient {
  const ConsentClient({
    required this.clientId,
    required this.name,
    required this.status,
    this.redirectHost,
    this.family,
  });

  final String clientId;
  final String name;
  final McpClientApproval status;

  /// Where the assistant's answer is sent (host and port): the consent
  /// page shows it so the person can tell a lookalike.
  final String? redirectHost;

  /// The approved assistant family it was recognised as (`claude`,
  /// `chatgpt`, `loopback`), when the server knows one.
  final String? family;

  static ConsentClient? fromJson(Object? json) {
    if (json is! Map || json['client_id'] is! String) return null;
    return ConsentClient(
      clientId: json['client_id'] as String,
      name: json['name'] is String ? json['name'] as String : '',
      status: McpClientApproval.parse(json['status']),
      redirectHost: json['redirect_host'] as String?,
      family: json['family'] is String ? json['family'] as String : null,
    );
  }
}

enum McpDeciderKind { operator, admin }

/// Who decides the first open step someone else must take.
class ConsentDecider {
  const ConsentDecider({required this.kind, this.displayName, this.me = false});

  final McpDeciderKind kind;

  /// Null on an installation nobody answers for yet.
  final String? displayName;

  /// The decision is the caller's own (they are that operator).
  final bool me;

  static ConsentDecider? fromJson(Object? json) {
    if (json is! Map) return null;
    final kind = switch (json['kind']) {
      'operator' => McpDeciderKind.operator,
      'admin' => McpDeciderKind.admin,
      _ => null,
    };
    if (kind == null) return null;
    return ConsentDecider(
      kind: kind,
      displayName: json['display_name'] as String?,
      me: json['me'] == true,
    );
  }
}

/// `mcp_consent_options(p_authorization_id)` beyond the workspaces.
class ConsentStatus {
  const ConsentStatus({required this.eligibility, this.client, this.decider});

  /// `eligible`, `expired`, `requested`, `not_requested` or `no_identity`.
  final String eligibility;
  final ConsentClient? client;
  final ConsentDecider? decider;

  bool get clientApproved => client?.status == McpClientApproval.approved;

  factory ConsentStatus.fromJson(Object? json) {
    if (json is! Map) return const ConsentStatus(eligibility: 'unknown');
    return ConsentStatus(
      eligibility: json['eligibility'] is String
          ? json['eligibility'] as String
          : 'unknown',
      client: ConsentClient.fromJson(json['client']),
      decider: ConsentDecider.fromJson(json['decider']),
    );
  }
}

enum McpEndpointSource { published, configured, derived, unknown }

/// The canonical MCP resource an assistant is given (`mcp_endpoint()`).
class McpEndpointInfo {
  const McpEndpointInfo({
    this.resource,
    this.metadataUrl,
    required this.source,
  });

  final String? resource;
  final String? metadataUrl;
  final McpEndpointSource source;

  factory McpEndpointInfo.fromJson(Object? json) {
    if (json is! Map) {
      return const McpEndpointInfo(source: McpEndpointSource.unknown);
    }
    final resource = json['resource'];
    return McpEndpointInfo(
      resource: resource is String && resource.startsWith('https://')
          ? resource
          : null,
      metadataUrl: json['metadata_url'] as String?,
      source: switch (json['source']) {
        'published' => McpEndpointSource.published,
        'configured' => McpEndpointSource.configured,
        'derived' => McpEndpointSource.derived,
        _ => McpEndpointSource.unknown,
      },
    );
  }
}

enum EndpointProbeState {
  missing,
  pending,
  deployed,
  endpointNotDeployed,
  resourceMismatch,
  unavailable,
  unknown;

  static EndpointProbeState parse(Object? raw) => switch (raw) {
    'missing' => missing,
    'pending' => pending,
    'deployed' => deployed,
    'endpoint_not_deployed' => endpointNotDeployed,
    'resource_mismatch' => resourceMismatch,
    'unavailable' => unavailable,
    _ => unknown,
  };
}

/// What the database saw when it called the deployed endpoint (0357):
/// `deployed` only for 401 + `resource_metadata` and a metadata document
/// naming the resource. Turn on needs a deployed probe under 15 minutes old.
class EndpointProbe {
  const EndpointProbe({
    required this.state,
    this.reason,
    this.endpointUrl,
    this.publishedResource,
    this.requestedAt,
    this.fresh = false,
  });

  final EndpointProbeState state;

  /// `challenge_404`, `metadata_200`, `no_answer`, `no_pg_net`, …
  final String? reason;
  final String? endpointUrl;
  final String? publishedResource;
  final DateTime? requestedAt;

  /// Taken within the 15 minutes Turn on accepts (overview only).
  final bool fresh;

  static const missing = EndpointProbe(state: EndpointProbeState.missing);

  factory EndpointProbe.fromJson(Object? json) {
    if (json is! Map) {
      return const EndpointProbe(state: EndpointProbeState.unknown);
    }
    return EndpointProbe(
      state: EndpointProbeState.parse(json['state']),
      reason: json['reason'] as String?,
      endpointUrl: json['endpoint_url'] as String?,
      publishedResource: json['published_resource'] as String?,
      requestedAt: DateTime.tryParse('${json['requested_at'] ?? ''}'),
      fresh: json['fresh'] == true,
    );
  }
}

/// One installation notice addressed to the caller.
class InstanceNotice {
  const InstanceNotice({
    required this.id,
    required this.kind,
    required this.subject,
    this.payload = const {},
    this.createdAt,
    this.readAt,
  });

  final String id;

  /// `mcp_client_waiting`, … — a kind this build does not know is kept
  /// so the inbox can still count it.
  final String kind;
  final String subject;
  final Map<String, dynamic> payload;
  final DateTime? createdAt;
  final DateTime? readAt;

  bool get unread => readAt == null;

  static InstanceNotice? fromJson(Object? json) {
    if (json is! Map || json['id'] is! String || json['kind'] is! String) {
      return null;
    }
    return InstanceNotice(
      id: json['id'] as String,
      kind: json['kind'] as String,
      subject: '${json['subject'] ?? ''}',
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : const {},
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
      readAt: DateTime.tryParse('${json['read_at'] ?? ''}'),
    );
  }
}

class InstanceNotices {
  const InstanceNotices({required this.unread, required this.notices});

  final int unread;
  final List<InstanceNotice> notices;

  static const empty = InstanceNotices(unread: 0, notices: []);

  factory InstanceNotices.fromJson(Object? json) {
    if (json is! Map) return empty;
    return InstanceNotices(
      unread: json['unread'] is int ? json['unread'] as int : 0,
      notices: [
        for (final n
            in json['notices'] is List ? json['notices'] as List : const [])
          ?InstanceNotice.fromJson(n),
      ],
    );
  }
}

abstract interface class McpOnboardingRepository {
  /// The client, status and decider for one pending authorization.
  Future<ConsentStatus> consentStatus(String authorizationId);

  /// The endpoint to give an assistant; unknown when the server predates
  /// 0354 or the caller may not connect one here.
  Future<McpEndpointInfo> endpoint();

  /// The caller's installation notices, newest first.
  Future<InstanceNotices> notices();

  /// Marks one notice read, or every unread one when [id] is null.
  Future<int> markNoticeRead([String? id]);

  /// The operator sets (or with null clears) the published endpoint; aal2.
  Future<McpEndpointInfo> setEndpoint(String? url);

  /// The operator asks the deployed endpoint what an assistant would get;
  /// answers `pending` (pg_net is asynchronous: check a moment later).
  Future<EndpointProbe> probeEndpoint();

  /// The latest probe, settled once pg_net answered.
  Future<EndpointProbe> checkEndpoint();

  /// The instance operator grants assistant access while no other database
  /// administrator exists: 1 to 30 days, a reason, aal2 and a Google
  /// session. Answers the expiry.
  Future<DateTime?> grantEligibility({
    required String subjectId,
    required String reason,
    required int days,
  });

  /// Whoever manages this workspace's integrations switches its mcpAccess,
  /// against the value they read ([expected]); a stale read is refused.
  Future<bool> setWorkspaceMcpAccess(
    String workspaceId, {
    required bool enabled,
    bool? expected,
  });

  /// The operator's one switch for loopback (desktop and command-line)
  /// assistants; aal2, audited. Answers the switch as saved.
  Future<bool> setLoopbackClients({required bool allowed});
}
