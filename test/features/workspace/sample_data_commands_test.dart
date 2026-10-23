// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2872 — a fill is one intent under one request id, and an answer naming
// a cleared batch leaves nothing open; a clear is done only when the
// server answers that same batch cleared, and a refusal propagates.
import 'package:deskilo/features/workspace/application/sample_data_commands.dart';
import 'package:deskilo/features/workspace/domain/sample_data.dart';
import 'package:flutter_test/flutter_test.dart';

class _Answers implements SampleDataRepository {
  _Answers({required this.filled, required this.cleared});
  final SampleDataBatch filled;
  final SampleDataBatch Function() cleared;
  final requestIds = <String>[];

  @override
  Future<SampleDataBatch?> status(String workspaceId) async => null;

  @override
  Future<SampleDataBatch> fill(String workspaceId, String requestId) async {
    requestIds.add(requestId);
    return filled;
  }

  @override
  Future<SampleDataBatch> clear(String workspaceId, String batchId) async =>
      cleared();
}

final _done = DateTime.utc(2026, 10, 22);

void main() {
  test('a fill sends its request id and answers the open batch', () async {
    final repository = _Answers(
      filled: const SampleDataBatch(id: 'b1', counts: {'members': 6}),
      cleared: () => throw UnimplementedError(),
    );
    final commands = SampleDataCommands(repository, requestId: () => 'r-1');
    final batch = await commands.fill('ws');
    expect(repository.requestIds, ['r-1']);
    expect(batch?.members, 6);
  });

  test('a fill answered by a cleared batch leaves nothing open', () async {
    final commands = SampleDataCommands(
      _Answers(
        filled: SampleDataBatch(id: 'b1', clearedAt: _done),
        cleared: () => throw UnimplementedError(),
      ),
    );
    expect(await commands.fill('ws'), isNull);
  });

  test('a clear is done only when the same batch comes back cleared', () async {
    Future<bool> clearWith(SampleDataBatch answer) => SampleDataCommands(
      _Answers(
        filled: const SampleDataBatch(id: 'b1'),
        cleared: () => answer,
      ),
    ).clear('ws', const SampleDataBatch(id: 'b1'));

    expect(
      await clearWith(SampleDataBatch(id: 'b1', clearedAt: _done)),
      isTrue,
    );
    expect(await clearWith(const SampleDataBatch(id: 'b1')), isFalse);
    expect(
      await clearWith(SampleDataBatch(id: 'b2', clearedAt: _done)),
      isFalse,
    );
  });

  test('a refused clear propagates', () async {
    final commands = SampleDataCommands(
      _Answers(
        filled: const SampleDataBatch(id: 'b1'),
        cleared: () => throw StateError('sample data not cleared'),
      ),
    );
    expect(
      commands.clear('ws', const SampleDataBatch(id: 'b1')),
      throwsStateError,
    );
  });

  test('the server answer reads counts by table, and null as none', () {
    final batch = SampleDataBatch.fromJson({
      'batch_id': 'b1',
      'created_at': '2026-10-22T08:00:00Z',
      'cleared_at': null,
      'counts': {'members': 6, 'reservations': 40, 'ledger_entries': 3},
    })!;
    expect((batch.members, batch.bookings, batch.payments), (6, 40, 3));
    expect(batch.isCleared, isFalse);
    expect(SampleDataBatch.fromJson(null), isNull);
  });
}
