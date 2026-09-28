// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1630 — what the MCP facade counted (0298), read back as counts only
// (0300): a person's own assistants today, and a workspace's last 30 days
// for its owner. No argument, result or member identity ever reaches here.

int _int(Object? v) => v is int ? v : (v is num ? v.toInt() : 0);

/// Counts for one slice of usage: every answered call, the refused ones
/// (denied, invalid or over a limit), the mutations that applied, and the
/// answers still waiting for a person's validation.
class McpUsageCounts {
  const McpUsageCounts({
    this.requests = 0,
    this.refusals = 0,
    this.applied = 0,
    this.pendingValidation = 0,
  });

  final int requests;
  final int refusals;
  final int applied;
  final int pendingValidation;

  static const zero = McpUsageCounts();

  factory McpUsageCounts.fromJson(
    Map<Object?, Object?> m, {
    String? requestsKey,
  }) => McpUsageCounts(
    requests: _int(m[requestsKey ?? 'requests']),
    refusals: _int(m['refusals']),
    applied: _int(m['applied']),
    pendingValidation: _int(m['pending_validation']),
  );

  McpUsageCounts operator +(McpUsageCounts o) => McpUsageCounts(
    requests: requests + o.requests,
    refusals: refusals + o.refusals,
    applied: applied + o.applied,
    pendingValidation: pendingValidation + o.pendingValidation,
  );
}

/// One of the person's assistants: today's counts and its last use.
class McpClientUsage {
  const McpClientUsage({
    required this.clientId,
    required this.clientName,
    required this.today,
    this.lastUsedAt,
  });

  final String clientId;
  final String clientName;
  final McpUsageCounts today;
  final DateTime? lastUsedAt;

  static List<McpClientUsage> listFromJson(Object? json) {
    final clients = json is Map ? json['clients'] : null;
    return [
      for (final c in clients is List ? clients : const [])
        if (c is Map && c['client_id'] is String)
          McpClientUsage(
            clientId: c['client_id'] as String,
            clientName: '${c['client_name'] ?? c['client_id']}',
            today: McpUsageCounts.fromJson(c, requestsKey: 'requests_today'),
            lastUsedAt: DateTime.tryParse('${c['last_used_at']}')?.toUtc(),
          ),
    ];
  }
}

/// A workspace's usage over the last 30 days, per day and operation.
class McpWorkspaceUsage {
  const McpWorkspaceUsage({required this.workspaceId, required this.rows});

  final String workspaceId;
  final List<({DateTime? day, String operation, McpUsageCounts counts})> rows;

  McpUsageCounts get total =>
      rows.fold(McpUsageCounts.zero, (sum, r) => sum + r.counts);

  /// Totals per operation, busiest first.
  List<({String operation, McpUsageCounts counts})> get byOperation {
    final totals = <String, McpUsageCounts>{};
    for (final r in rows) {
      totals[r.operation] =
          (totals[r.operation] ?? McpUsageCounts.zero) + r.counts;
    }
    return [for (final e in totals.entries) (operation: e.key, counts: e.value)]
      ..sort((a, b) {
        final c = b.counts.requests.compareTo(a.counts.requests);
        return c != 0 ? c : a.operation.compareTo(b.operation);
      });
  }

  factory McpWorkspaceUsage.fromJson(Object? json) {
    final m = json is Map ? json : const <String, Object?>{};
    return McpWorkspaceUsage(
      workspaceId: '${m['workspace_id'] ?? ''}',
      rows: [
        for (final r in m['rows'] is List ? m['rows'] as List : const [])
          if (r is Map && r['operation'] is String)
            (
              day: DateTime.tryParse('${r['day']}'),
              operation: r['operation'] as String,
              counts: McpUsageCounts.fromJson(r),
            ),
      ],
    );
  }
}
