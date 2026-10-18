// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../features/money/domain/workspace_asset.dart';

/// #2576 — the equipment register in memory, with the server's rules that the
/// screen shows: a line is registered once, capitalising needs a known cost,
/// an expensed item has no date of availability for use, a decided asset is
/// not decided again, and the same request answers the same asset.
class FakeWorkspaceAssetRepository implements WorkspaceAssetRepository {
  FakeWorkspaceAssetRepository({
    Iterable<WorkspaceAsset> assets = const [],
    Iterable<AssetCandidateLine> lines = const [],
  }) : assets = [...assets],
       candidates = [...lines];

  final List<WorkspaceAsset> assets;
  final List<AssetCandidateLine> candidates;
  final Map<String, WorkspaceAsset> _answers = {};
  var _next = 1;

  @override
  Future<List<WorkspaceAsset>> fetchAssets(String workspaceId) async => [...assets];

  @override
  Future<List<AssetCandidateLine>> fetchCandidateLines(String workspaceId) async =>
      [...candidates];

  @override
  Future<WorkspaceAsset> register(
    String workspaceId, {
    required String purchaseId,
    required int lineNo,
    required String description,
    required String requestId,
  }) async {
    final replay = _answers[requestId];
    if (replay != null) return replay;
    final i = candidates.indexWhere((c) => c.purchaseId == purchaseId && c.lineNo == lineNo);
    if (i < 0) throw StateError('this line is already registered');
    final line = candidates.removeAt(i);
    final asset = WorkspaceAsset(
      id: 'demo-asset-${_next++}',
      revision: 1,
      assetNumber: assets.length + 1,
      description: description.isEmpty ? line.description : description,
      currency: line.currency,
      acquisitionCostCents: line.grossCents,
      supplierName: line.supplierName,
      originalReference: line.originalReference,
      decision: AssetDecision.pending,
      state: AssetState.candidate,
      purchaseId: line.purchaseId,
      lineNo: line.lineNo,
    );
    assets.add(asset);
    return _answers[requestId] = asset;
  }

  @override
  Future<WorkspaceAsset> decide(
    String workspaceId,
    AssetDecisionCommand command,
  ) async {
    final replay = _answers[command.requestId];
    if (replay != null) return replay;
    final i = assets.indexWhere((a) => a.id == command.assetId);
    if (i < 0) throw StateError('unknown asset');
    final a = assets[i];
    if (a.revision != command.revision) throw StateError('stale revision');
    if (!a.isCandidate) throw StateError('a decided asset is corrected in the open period');
    if (command.basis.trim().isEmpty) throw StateError('state the basis of the decision');
    if (command.decision == AssetDecision.capitalise && a.acquisitionCostCents == null) {
      throw StateError('qualify the deductible share first');
    }
    final capitalise = command.decision == AssetDecision.capitalise;
    final next = WorkspaceAsset(
      id: a.id,
      revision: a.revision + 1,
      assetNumber: a.assetNumber,
      description: a.description,
      currency: a.currency,
      acquisitionCostCents: a.acquisitionCostCents,
      supplierName: a.supplierName,
      originalReference: a.originalReference,
      decision: command.decision,
      decisionBasis: command.basis.trim(),
      state: !capitalise
          ? AssetState.expensed
          : command.availableForUseOn == null
          ? AssetState.candidate
          : AssetState.inUse,
      availableForUseOn: command.availableForUseOn,
      custodianMemberId: command.custodianMemberId,
      externalAssetId: command.externalAssetId,
      purchaseId: a.purchaseId,
      lineNo: a.lineNo,
    );
    assets[i] = next;
    return _answers[command.requestId] = next;
  }
}
