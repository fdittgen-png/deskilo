// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1608/#1611 — what the signed-in person may do on THIS database, apart
// from any workspace: whether they administer it, whether they may add
// administrators, and whether MCP eligibility was approved for them. None
// of it is a workspace role, a membership or a consent.

enum McpEligibility {
  eligible,
  requested,
  notRequested,
  expired,

  /// No verified identity binding (#1647): nothing can be asked yet.
  noIdentity,

  /// The server predates 0270 or answered something unreadable.
  unavailable,
}

class DatabaseCapabilities {
  const DatabaseCapabilities({
    required this.eligibility,
    this.databaseAdministrator = false,
    this.canProvision = false,
    this.runtimeEnabled = false,
    this.eligibleUntil,
  });

  final McpEligibility eligibility;
  final bool databaseAdministrator;
  final bool canProvision;
  final bool runtimeEnabled;
  final DateTime? eligibleUntil;

  static const unavailable =
      DatabaseCapabilities(eligibility: McpEligibility.unavailable);

  /// Unknown words and missing fields fall to [unavailable]; a flag that
  /// is not literally `true` is false.
  factory DatabaseCapabilities.fromJson(Object? json) {
    if (json is! Map) return unavailable;
    final eligibility = switch (json['mcp_eligibility']) {
      'eligible' => McpEligibility.eligible,
      'requested' => McpEligibility.requested,
      'not_requested' => McpEligibility.notRequested,
      'expired' => McpEligibility.expired,
      'no_identity' => McpEligibility.noIdentity,
      _ => McpEligibility.unavailable,
    };
    if (eligibility == McpEligibility.unavailable) return unavailable;
    final until = DateTime.tryParse('${json['eligible_until']}');
    if (eligibility == McpEligibility.eligible && until == null) return unavailable;
    return DatabaseCapabilities(
      eligibility: eligibility,
      databaseAdministrator: json['database_administrator'] == true,
      canProvision: json['database_administrator'] == true && json['can_provision'] == true,
      runtimeEnabled: json['runtime_enabled'] == true,
      eligibleUntil: until?.toUtc(),
    );
  }
}
