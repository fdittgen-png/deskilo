// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3963 — the Demo is itself sample data: the invented people, bookings and
// payments of its space are the one batch it holds, counted from the space.
// Filling answers that batch (the contract's "or answers the batch it
// already holds"), so the Demo loads no more; clearing it is refused as the
// server refuses a clear that did not happen: the batch comes back not
// cleared, and the card says so and offers to try again.
import '../../../features/workspace/domain/sample_data.dart';

class DemoSampleDataRepository implements SampleDataRepository {
  DemoSampleDataRepository({required this.counts, required this.since});

  /// The rows of the space by table, as the Demo holds them now.
  final Map<String, int> Function() counts;

  /// When the Demo's day began: the batch's date.
  final DateTime since;

  SampleDataBatch get _batch => SampleDataBatch(
    id: 'demo-sample-batch',
    createdAt: since,
    counts: counts(),
  );

  @override
  Future<SampleDataBatch?> status(String workspaceId) async => _batch;

  @override
  Future<SampleDataBatch> fill(String workspaceId, String requestId) async =>
      _batch;

  @override
  Future<SampleDataBatch> clear(String workspaceId, String batchId) async =>
      _batch;
}
