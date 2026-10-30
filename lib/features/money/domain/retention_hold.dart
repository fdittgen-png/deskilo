// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A legal or audit hold over a space's records (`retention_holds`): it keeps
// them past every retention clock, with no end date, until someone releases
// it with a reason. A released hold stays readable.
import '../../../core/data/json_reader.dart';

/// The permission whose holder places and releases a hold, by its wire
/// name: the server checks the same one.
const retentionHoldPermission = 'manageBilling';

/// The longest reason a hold or its release may give (the server's bound).
const retentionHoldReasonMax = 500;

class RetentionHold {
  const RetentionHold({
    required this.id,
    required this.workspaceId,
    this.issuerSiteId,
    this.docClass,
    required this.reason,
    required this.placedAt,
    this.releasedAt,
    this.releaseReason,
  });

  factory RetentionHold.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'retention_holds');
    return RetentionHold(
      id: r.string('id'),
      workspaceId: r.string('workspace_id'),
      issuerSiteId: r.stringOrNull('issuer_site_id'),
      docClass: r.stringOrNull('class'),
      reason: r.string('reason'),
      placedAt: r.dateTime('placed_at'),
      releasedAt: r.dateTimeOrNull('released_at'),
      releaseReason: r.stringOrNull('release_reason'),
    );
  }

  final String id;
  final String workspaceId;

  /// The issuer (a site) it holds; null: every issuer of the space.
  final String? issuerSiteId;

  /// The class of record it holds; null: every class.
  final String? docClass;
  final String reason;
  final DateTime placedAt;
  final DateTime? releasedAt;
  final String? releaseReason;

  bool get active => releasedAt == null;
}

/// True when [reason] is one the server accepts for a hold or a release.
bool retentionHoldReasonValid(String reason) {
  final trimmed = reason.trim();
  return trimmed.isNotEmpty && trimmed.length <= retentionHoldReasonMax;
}

/// Where holds are read, placed and released: `retention_holds`,
/// `place_retention_hold` and `release_retention_hold` on a server, a list
/// in the demo and tests.
abstract class RetentionHoldRepository {
  /// Every hold of [workspaceId], the active ones first.
  Future<List<RetentionHold>> fetchHolds(String workspaceId);

  Future<RetentionHold> placeHold({
    required String workspaceId,
    String? issuerSiteId,
    String? docClass,
    required String reason,
  });

  Future<RetentionHold> releaseHold(String holdId, String reason);
}
