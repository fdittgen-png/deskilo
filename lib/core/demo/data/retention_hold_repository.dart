// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../features/money/domain/retention_hold.dart';

/// Retention holds in memory, released as the server releases them: the
/// row stays, with when and why.
class FakeRetentionHoldRepository implements RetentionHoldRepository {
  FakeRetentionHoldRepository({required this.now});

  /// The session's clock: a hold is placed and released at its time.
  final DateTime Function() now;

  final List<RetentionHold> holds = [];

  @override
  Future<List<RetentionHold>> fetchHolds(String workspaceId) async => [
    for (final h in holds)
      if (h.workspaceId == workspaceId && h.active) h,
    for (final h in holds)
      if (h.workspaceId == workspaceId && !h.active) h,
  ];

  @override
  Future<RetentionHold> placeHold({
    required String workspaceId,
    String? issuerSiteId,
    String? docClass,
    required String reason,
  }) async {
    final hold = RetentionHold(
      id: 'hold-${holds.length + 1}',
      workspaceId: workspaceId,
      issuerSiteId: issuerSiteId,
      docClass: docClass,
      reason: reason.trim(),
      placedAt: now(),
    );
    holds.add(hold);
    return hold;
  }

  @override
  Future<RetentionHold> releaseHold(String holdId, String reason) async {
    final i = holds.indexWhere((h) => h.id == holdId && h.active);
    if (i < 0) throw StateError('no active hold $holdId');
    final h = holds[i];
    return holds[i] = RetentionHold(
      id: h.id,
      workspaceId: h.workspaceId,
      issuerSiteId: h.issuerSiteId,
      docClass: h.docClass,
      reason: h.reason,
      placedAt: h.placedAt,
      releasedAt: now(),
      releaseReason: reason.trim(),
    );
  }
}
