// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/data/json_reader.dart';
import 'asset_valuation_csv.dart';
import 'asset_valuation_types.dart';

export 'asset_valuation_csv.dart';
export 'asset_valuation_types.dart';

/// #2576 (C2) — the accountant's valuations of the equipment
/// (`asset_valuation_batches`, `asset_valuation_rows`, 0500): a read model next
/// to the register. Nothing here posts anything; a blank figure is UNKNOWN and
/// stays unknown.

/// Where a batch stands.
class ValuationBatch {
  const ValuationBatch({
    required this.id,
    required this.revision,
    required this.basis,
    required this.sourceSystem,
    required this.periodFrom,
    required this.periodTo,
    required this.currency,
    required this.movements,
    required this.completeScope,
    required this.status,
    this.sourceReference = '',
    this.rowCount = 0,
    this.mismatches = 0,
    this.reason = '',
  });

  factory ValuationBatch.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'valuation batch');
    return ValuationBatch(
      id: r.string('id'),
      revision: r.integer('revision'),
      basis: ValuationBasis.of(r.stringOrNull('basis')) ?? ValuationBasis.book,
      sourceSystem: r.stringOr('source_system'),
      sourceReference: r.stringOr('source_reference'),
      periodFrom: DateTime.parse(r.string('period_from')),
      periodTo: DateTime.parse(r.string('period_to')),
      currency: r.stringOr('currency'),
      movements: r.stringOr('movements', 'period'),
      completeScope: r.boolOr('complete_scope', fallback: false),
      status: ValuationStatus.of(r.stringOrNull('status')),
      rowCount: r.intOrNull('rows') ?? 0,
      mismatches: r.intOrNull('mismatches') ?? 0,
      reason: r.stringOr('reason'),
    );
  }

  final String id;
  final int revision;
  final ValuationBasis basis;
  final String sourceSystem;
  final String sourceReference;
  final DateTime periodFrom;
  final DateTime periodTo;
  final String currency;

  /// `period` or `ytd`: how the movements of its rows are stated.
  final String movements;
  final bool completeScope;
  final ValuationStatus status;
  final int rowCount;
  final int mismatches;
  final String reason;
}

/// One asset's stored figures; null is unknown, never zero.
class ValuationRow {
  const ValuationRow({
    required this.assetId,
    required this.assetNumber,
    required this.description,
    required this.bridge,
    this.externalReference = '',
    this.openingMinor,
    this.additionsMinor,
    this.disposalsMinor,
    this.depreciationMinor,
    this.impairmentMinor,
    this.closingMinor,
  });

  factory ValuationRow.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'valuation row');
    return ValuationRow(
      assetId: r.string('asset_id'),
      assetNumber: r.integer('asset_number'),
      description: r.stringOr('description'),
      externalReference: r.stringOr('external_reference'),
      openingMinor: r.intOrNull('opening_minor'),
      additionsMinor: r.intOrNull('additions_minor'),
      disposalsMinor: r.intOrNull('disposals_minor'),
      depreciationMinor: r.intOrNull('depreciation_minor'),
      impairmentMinor: r.intOrNull('impairment_minor'),
      closingMinor: r.intOrNull('closing_minor'),
      bridge: switch (r.stringOr('bridge')) {
        'ok' => ValuationBridge.ok,
        'mismatch' => ValuationBridge.mismatch,
        _ => ValuationBridge.unknown,
      },
    );
  }

  final String assetId;
  final int assetNumber;
  final String description;
  final String externalReference;
  final int? openingMinor;
  final int? additionsMinor;
  final int? disposalsMinor;
  final int? depreciationMinor;
  final int? impairmentMinor;
  final int? closingMinor;
  final ValuationBridge bridge;
}

/// The metadata the person states beside the file.
class ValuationSource {
  const ValuationSource({
    required this.system,
    required this.movements,
    required this.completeScope,
    this.reference = '',
  });

  final String system;
  final String reference;

  /// `period` or `ytd`.
  final String movements;
  final bool completeScope;
}

/// The valuations of one space; every write goes through an RPC.
abstract class AssetValuationRepository {
  Future<List<ValuationBatch>> fetchBatches(String workspaceId);

  Future<List<ValuationRow>> fetchRows(String workspaceId, String batchId);

  /// Stores the file as a staged batch; the same bytes answer the same batch.
  Future<ValuationBatch> stage(
    String workspaceId, {
    required ValuationCsv file,
    required ValuationSource source,
    required String requestId,
  });

  /// Makes a staged batch the evidence of its period; [supersedes] names the
  /// confirmed batch it replaces, with [reason].
  Future<ValuationBatch> confirm(
    String workspaceId, {
    required ValuationBatch batch,
    required String requestId,
    String? supersedes,
    String reason = '',
  });
}
