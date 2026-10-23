// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Sample data in the owner's own test space (ADR 0047 §9, 0546). One batch
// at a time: what the server generated, counted by table, until it is
// cleared. The server alone decides what a batch holds and removes exactly
// that; the app only shows the counts and asks.
import '../../../core/data/json_reader.dart';

/// One generation batch of sample data, as `create_sample_data` and
/// `sample_data_status` answer it.
class SampleDataBatch {
  const SampleDataBatch({
    required this.id,
    this.createdAt,
    this.clearedAt,
    this.counts = const {},
  });

  final String id;
  final DateTime? createdAt;

  /// Set once the batch is cleared; an open batch has none.
  final DateTime? clearedAt;

  /// Rows the batch recorded, by table.
  final Map<String, int> counts;

  bool get isCleared => clearedAt != null;
  int get members => counts['members'] ?? 0;
  int get bookings => counts['reservations'] ?? 0;
  int get payments => counts['ledger_entries'] ?? 0;

  /// The batch an answer names, or null for "no open batch".
  static SampleDataBatch? fromJson(Object? json) {
    if (json == null) return null;
    final row = JsonReader.of(json, context: 'sample_data');
    return SampleDataBatch(
      id: row.string('batch_id'),
      createdAt: row.dateTimeOrNull('created_at'),
      clearedAt: row.dateTimeOrNull('cleared_at'),
      counts: {
        for (final e in row.objectOrEmpty('counts').entries)
          if (e.value is num) e.key: (e.value! as num).toInt(),
      },
    );
  }
}

/// The three calls of 0546.
abstract class SampleDataRepository {
  /// The space's open batch, or null when it holds no sample data.
  Future<SampleDataBatch?> status(String workspaceId);

  /// Fills the space, or answers the batch it already holds.
  Future<SampleDataBatch> fill(String workspaceId, String requestId);

  /// Clears [batchId]; the answer is the batch as the server left it.
  Future<SampleDataBatch> clear(String workspaceId, String batchId);
}

/// Where no server answers (the demonstration): nothing to show, and no
/// sample data to make.
class UnavailableSampleDataRepository implements SampleDataRepository {
  const UnavailableSampleDataRepository();

  @override
  Future<SampleDataBatch?> status(String workspaceId) async =>
      throw UnsupportedError('no server in this mode');

  @override
  Future<SampleDataBatch> fill(String workspaceId, String requestId) async =>
      throw UnsupportedError('no server in this mode');

  @override
  Future<SampleDataBatch> clear(String workspaceId, String batchId) async =>
      throw UnsupportedError('no server in this mode');
}
