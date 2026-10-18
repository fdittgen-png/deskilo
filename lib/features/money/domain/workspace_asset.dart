// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/data/json_reader.dart';
import '../../../core/time/date_text.dart';

/// #2576 — the equipment register (`workspace_assets`, 0491). The server owns
/// every rule; these are the shapes it answers with and the commands it takes.

enum AssetDecision {
  pending('pending'),
  capitalise('capitalise'),
  expense('expense');

  const AssetDecision(this.wire);

  final String wire;

  static AssetDecision of(String? s) =>
      values.firstWhere((v) => v.wire == s, orElse: () => pending);
}

enum AssetState {
  candidate('candidate'),
  inUse('in_use'),
  disposed('disposed'),
  expensed('expensed');

  const AssetState(this.wire);

  final String wire;

  static AssetState of(String? s) =>
      values.firstWhere((v) => v.wire == s, orElse: () => candidate);
}

/// One registered piece of equipment: what the purchase line says it cost,
/// and the reviewer's treatment of it.
class WorkspaceAsset {
  const WorkspaceAsset({
    required this.id,
    required this.revision,
    required this.assetNumber,
    required this.description,
    required this.currency,
    required this.decision,
    required this.state,
    this.acquisitionCostCents,
    this.supplierName = '',
    this.originalReference = '',
    this.decisionBasis = '',
    this.availableForUseOn,
    this.custodianMemberId,
    this.externalAssetId = '',
    this.purchaseId = '',
    this.lineNo = 0,
  });

  factory WorkspaceAsset.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'workspace asset');
    return WorkspaceAsset(
      id: r.string('id'),
      revision: r.integer('revision'),
      assetNumber: r.integer('asset_number'),
      description: r.stringOr('description'),
      currency: r.stringOr('currency'),
      acquisitionCostCents: r.intOrNull('acquisition_cost_cents'),
      supplierName: r.stringOr('supplier_name'),
      originalReference: r.stringOr('original_reference'),
      decision: AssetDecision.of(r.stringOrNull('decision')),
      decisionBasis: r.stringOr('decision_basis'),
      state: AssetState.of(r.stringOrNull('state')),
      availableForUseOn: DateTime.tryParse(r.stringOr('available_for_use_on')),
      custodianMemberId: r.stringOrNull('custodian_member_id'),
      externalAssetId: r.stringOr('external_asset_id'),
      purchaseId: r.stringOr('purchase_id'),
      lineNo: r.intOrNull('line_no') ?? 0,
    );
  }

  final String id;
  final int revision;
  final int assetNumber;
  final String description;
  final String currency;

  /// Net plus the tax that is not recovered; null while the deductible share
  /// of the purchase is not qualified (never a guessed zero).
  final int? acquisitionCostCents;
  final String supplierName;
  final String originalReference;
  final AssetDecision decision;
  final String decisionBasis;
  final AssetState state;
  final DateTime? availableForUseOn;
  final String? custodianMemberId;
  final String externalAssetId;
  final String purchaseId;
  final int lineNo;

  /// Still waiting for (or for the date of) the reviewer's treatment.
  bool get isCandidate => state == AssetState.candidate;
}

/// A purchase line classified as long-lasting equipment that nobody has
/// registered yet.
class AssetCandidateLine {
  const AssetCandidateLine({
    required this.purchaseId,
    required this.lineNo,
    required this.description,
    required this.grossCents,
    required this.currency,
    this.supplierName = '',
    this.originalReference = '',
  });

  factory AssetCandidateLine.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'asset candidate line');
    return AssetCandidateLine(
      purchaseId: r.string('purchase_id'),
      lineNo: r.integer('line_no'),
      description: r.stringOr('description'),
      grossCents: r.integer('gross_cents'),
      currency: r.stringOr('currency'),
      supplierName: r.stringOr('supplier_name'),
      originalReference: r.stringOr('original_reference'),
    );
  }

  final String purchaseId;
  final int lineNo;
  final String description;
  final int grossCents;
  final String currency;
  final String supplierName;
  final String originalReference;
}

/// The reviewer's decision on one asset.
class AssetDecisionCommand {
  const AssetDecisionCommand({
    required this.assetId,
    required this.revision,
    required this.decision,
    required this.basis,
    required this.requestId,
    this.availableForUseOn,
    this.custodianMemberId,
    this.externalAssetId = '',
  });

  final String assetId;
  final int revision;
  final AssetDecision decision;
  final String basis;
  final DateTime? availableForUseOn;
  final String? custodianMemberId;
  final String externalAssetId;
  final String requestId;

  Map<String, Object?> toParams(String workspaceId) => {
    'p_workspace_id': workspaceId,
    'p_asset_id': assetId,
    'p_revision': revision,
    'p_decision': decision.wire,
    'p_basis': basis,
    'p_available_for_use_on': availableForUseOn == null ? null : isoDay(availableForUseOn!),
    'p_site_id': null,
    'p_custodian_member_id': custodianMemberId,
    'p_external_asset_id': externalAssetId,
    'p_request_id': requestId,
  };
}

/// The equipment register of a space; every write goes through an RPC.
abstract class WorkspaceAssetRepository {
  Future<List<WorkspaceAsset>> fetchAssets(String workspaceId);

  Future<List<AssetCandidateLine>> fetchCandidateLines(String workspaceId);

  /// Registers a line as a candidate; [description] names it (the line's own
  /// text when empty).
  Future<WorkspaceAsset> register(
    String workspaceId, {
    required String purchaseId,
    required int lineNo,
    required String description,
    required String requestId,
  });

  Future<WorkspaceAsset> decide(String workspaceId, AssetDecisionCommand command);
}
