// SPDX-License-Identifier: AGPL-3.0-or-later
import '../domain/retention_hold.dart';

/// What became of placing or releasing a hold.
enum RetentionHoldOutcome {
  done,

  /// The reason is empty or too long; nothing sent.
  reasonInvalid,
}

/// Placing and releasing holds: never sends a reason the server refuses.
class RetentionHolds {
  const RetentionHolds(this._repository);

  final RetentionHoldRepository _repository;

  /// Throws whatever the repository throws; the caller reports it.
  Future<RetentionHoldOutcome> place({
    required String workspaceId,
    String? issuerSiteId,
    String? docClass,
    required String reason,
  }) async {
    if (!retentionHoldReasonValid(reason)) return RetentionHoldOutcome.reasonInvalid;
    await _repository.placeHold(
      workspaceId: workspaceId,
      issuerSiteId: issuerSiteId,
      docClass: docClass,
      reason: reason.trim(),
    );
    return RetentionHoldOutcome.done;
  }

  /// Throws whatever the repository throws; the caller reports it.
  Future<RetentionHoldOutcome> release(String holdId, String reason) async {
    if (!retentionHoldReasonValid(reason)) return RetentionHoldOutcome.reasonInvalid;
    await _repository.releaseHold(holdId, reason.trim());
    return RetentionHoldOutcome.done;
  }
}
