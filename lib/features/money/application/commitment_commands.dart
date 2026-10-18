// SPDX-License-Identifier: AGPL-3.0-or-later
import '../domain/lease_commitment.dart';

/// #2575 — what is sent to match a bill to a lease's expected rent. Nothing is
/// sent for an entry that cannot be right (the server decides again).
class CommitmentCommands {
  const CommitmentCommands(this._repository);

  final LeaseCommitmentRepository _repository;

  /// True when the match was sent.
  Future<bool> match(
    String workspaceId,
    CommitmentMatchCommand command,
  ) async {
    if (command.allocations.isEmpty ||
        command.allocations.any((a) => a.cents <= 0)) {
      return false;
    }
    await _repository.matchCommitments(workspaceId, command);
    return true;
  }

  /// True when the reversal was sent; it needs its reason.
  Future<bool> reverse(
    String workspaceId, {
    required String matchId,
    required String reason,
    required String requestId,
  }) async {
    if (reason.trim().isEmpty) return false;
    await _repository.reverseMatch(
      workspaceId,
      matchId: matchId,
      reason: reason.trim(),
      requestId: requestId,
    );
    return true;
  }
}
