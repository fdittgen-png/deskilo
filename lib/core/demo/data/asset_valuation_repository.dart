// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../features/money/domain/asset_valuation.dart';

/// #2576 — the accountant's valuations in memory, with the server's rules the
/// screen shows: the same bytes answer the same batch, a row that does not
/// balance cannot be confirmed, and an overlapping period needs the batch it
/// replaces and why.
class FakeAssetValuationRepository implements AssetValuationRepository {
  FakeAssetValuationRepository({
    Iterable<ValuationBatch> batches = const [],
    Map<String, List<ValuationRow>> rows = const {},
  }) : batches = [...batches],
       rows = {...rows};

  final List<ValuationBatch> batches;
  final Map<String, List<ValuationRow>> rows;
  final Map<String, String> _hashes = {};
  final Map<String, ValuationBatch> _answers = {};
  var _next = 1;

  @override
  Future<List<ValuationBatch>> fetchBatches(String workspaceId) async => [
    ...batches,
  ];

  @override
  Future<List<ValuationRow>> fetchRows(
    String workspaceId,
    String batchId,
  ) async => [...?rows[batchId]];

  @override
  Future<ValuationBatch> stage(
    String workspaceId, {
    required ValuationCsv file,
    required ValuationSource source,
    required String requestId,
  }) async {
    final replay = _answers[requestId];
    if (replay != null) return replay;
    final held = _hashes['${file.basis?.wire}:${file.sha256Hex}'];
    if (held != null) {
      return _answers[requestId] = batches.firstWhere((b) => b.id == held);
    }
    if (!file.usable) throw StateError('the file has problems');
    final batch = ValuationBatch(
      id: 'demo-valuation-${_next++}',
      revision: 1,
      basis: file.basis!,
      sourceSystem: source.system,
      sourceReference: source.reference,
      periodFrom: file.periodFrom!,
      periodTo: file.periodTo!,
      currency: file.currency,
      movements: source.movements,
      completeScope: source.completeScope,
      status: ValuationStatus.staged,
      rowCount: file.rows.length,
      mismatches: file.mismatches,
    );
    batches.add(batch);
    rows[batch.id] = [
      for (final r in file.rows)
        ValuationRow(
          assetId: 'demo-asset-${r.assetNumber}',
          assetNumber: r.assetNumber,
          description: 'Asset ${r.assetNumber}',
          externalReference: r.externalReference,
          openingMinor: r.openingMinor,
          additionsMinor: r.additionsMinor,
          disposalsMinor: r.disposalsMinor,
          depreciationMinor: r.depreciationMinor,
          impairmentMinor: r.impairmentMinor,
          closingMinor: r.closingMinor,
          bridge: r.bridge,
        ),
    ];
    _hashes['${file.basis!.wire}:${file.sha256Hex}'] = batch.id;
    return _answers[requestId] = batch;
  }

  @override
  Future<ValuationBatch> confirm(
    String workspaceId, {
    required ValuationBatch batch,
    required String requestId,
    String? supersedes,
    String reason = '',
  }) async {
    final replay = _answers[requestId];
    if (replay != null) return replay;
    final i = batches.indexWhere((b) => b.id == batch.id);
    if (i < 0) throw StateError('unknown batch');
    final b = batches[i];
    if (b.revision != batch.revision) {
      throw StateError('the batch changed meanwhile');
    }
    if (b.status != ValuationStatus.staged) {
      throw StateError('only a staged batch is confirmed');
    }
    if (b.mismatches > 0) throw StateError('a row does not balance');
    final overlap = [
      for (final x in batches)
        if (x.id != b.id &&
            x.status == ValuationStatus.confirmed &&
            x.basis == b.basis &&
            x.currency == b.currency &&
            !x.periodTo.isBefore(b.periodFrom) &&
            !b.periodTo.isBefore(x.periodFrom))
          x.id,
    ];
    if (overlap.isNotEmpty) {
      if (supersedes == null ||
          overlap.length != 1 ||
          overlap.single != supersedes) {
        throw StateError('a confirmed batch already values these assets');
      }
      if (reason.trim().isEmpty) {
        throw StateError('say why the earlier batch is replaced');
      }
      final o = batches.indexWhere((x) => x.id == supersedes);
      batches[o] = _with(batches[o], status: ValuationStatus.superseded);
    }
    final next = _with(
      b,
      status: ValuationStatus.confirmed,
      revision: b.revision + 1,
      reason: reason.trim(),
    );
    batches[i] = next;
    return _answers[requestId] = next;
  }

  static ValuationBatch _with(
    ValuationBatch b, {
    ValuationStatus? status,
    int? revision,
    String? reason,
  }) => ValuationBatch(
    id: b.id,
    revision: revision ?? b.revision,
    basis: b.basis,
    sourceSystem: b.sourceSystem,
    sourceReference: b.sourceReference,
    periodFrom: b.periodFrom,
    periodTo: b.periodTo,
    currency: b.currency,
    movements: b.movements,
    completeScope: b.completeScope,
    status: status ?? b.status,
    rowCount: b.rowCount,
    mismatches: b.mismatches,
    reason: reason ?? b.reason,
  );
}
