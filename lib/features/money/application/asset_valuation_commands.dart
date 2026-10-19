// SPDX-License-Identifier: AGPL-3.0-or-later
import '../domain/asset_valuation.dart';

/// #2576 — what is sent for the accountant's valuations. A command sends
/// nothing when the entry cannot be right (the server decides again on every
/// write); null tells the caller nothing was sent.
class AssetValuationCommands {
  const AssetValuationCommands(this._repository);

  final AssetValuationRepository _repository;

  /// A file with a problem, no source named, or no rows is not staged.
  Future<ValuationBatch?> stage(
    String workspaceId, {
    required ValuationCsv file,
    required ValuationSource source,
    required String requestId,
  }) async {
    if (!file.usable || source.system.trim().isEmpty) return null;
    return _repository.stage(
      workspaceId,
      file: file,
      source: ValuationSource(
        system: source.system.trim(),
        reference: source.reference.trim(),
        movements: source.movements,
        completeScope: source.completeScope,
      ),
      requestId: requestId,
    );
  }

  /// Only a staged batch whose rows balance is confirmed; replacing a batch
  /// states why.
  Future<ValuationBatch?> confirm(
    String workspaceId, {
    required ValuationBatch batch,
    required String requestId,
    String? supersedes,
    String reason = '',
  }) async {
    if (batch.status != ValuationStatus.staged ||
        batch.mismatches > 0 ||
        (supersedes != null && reason.trim().isEmpty)) {
      return null;
    }
    return _repository.confirm(
      workspaceId,
      batch: batch,
      requestId: requestId,
      supersedes: supersedes,
      reason: reason.trim(),
    );
  }
}
