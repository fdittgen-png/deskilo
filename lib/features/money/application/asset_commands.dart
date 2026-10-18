// SPDX-License-Identifier: AGPL-3.0-or-later
import '../domain/workspace_asset.dart';

/// #2576 — what is sent for the equipment register. A command sends nothing
/// when the entry cannot be right (the server decides again on every write);
/// returning null tells the caller nothing was sent.
class AssetCommands {
  const AssetCommands(this._repository);

  final WorkspaceAssetRepository _repository;

  Future<WorkspaceAsset?> register(
    String workspaceId,
    AssetCandidateLine line,
    String description,
    String requestId,
  ) async {
    if (line.purchaseId.isEmpty || line.lineNo < 1) return null;
    return _repository.register(
      workspaceId,
      purchaseId: line.purchaseId,
      lineNo: line.lineNo,
      description: description.trim(),
      requestId: requestId,
    );
  }

  /// A decision states its basis; an expensed item has no date of availability
  /// for use; capitalising needs a known cost. The reviewer, not the app,
  /// chooses: nothing is inferred.
  Future<WorkspaceAsset?> decide(
    String workspaceId,
    WorkspaceAsset asset,
    AssetDecisionCommand command,
  ) async {
    if (!asset.isCandidate ||
        command.decision == AssetDecision.pending ||
        command.basis.trim().isEmpty ||
        (command.decision == AssetDecision.expense && command.availableForUseOn != null) ||
        (command.decision == AssetDecision.capitalise && asset.acquisitionCostCents == null)) {
      return null;
    }
    return _repository.decide(workspaceId, command);
  }
}
