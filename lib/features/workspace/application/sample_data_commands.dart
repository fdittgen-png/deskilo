// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Filling and clearing the sample data of a test space (0546). A fill is
// one intent under one request id, so the server answers a repeated tap
// with the batch it already made. A clear counts as done only when the
// server answers the batch cleared: anything else is "not cleared".
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/ids/request_id.dart';
import '../domain/sample_data.dart';
import '../providers/sample_data_providers.dart';

part 'sample_data_commands.g.dart';

class SampleDataCommands {
  const SampleDataCommands(this._repository, {String Function()? requestId})
    : _requestId = requestId ?? newRequestId;
  final SampleDataRepository _repository;
  final String Function() _requestId;

  /// The space's open batch after the fill; null when the answer names a
  /// batch that is already cleared, so nothing is open.
  Future<SampleDataBatch?> fill(String workspaceId) async {
    final batch = await _repository.fill(workspaceId, _requestId());
    return batch.isCleared ? null : batch;
  }

  /// Whether [batch] is gone. False — never a silent success — when the
  /// server answers it still open; a refusal propagates.
  Future<bool> clear(String workspaceId, SampleDataBatch batch) async {
    final after = await _repository.clear(workspaceId, batch.id);
    return after.id == batch.id && after.isCleared;
  }
}

/// 0546 — the sample data commands of the selected server.
@riverpod
SampleDataCommands sampleDataCommands(Ref ref) =>
    SampleDataCommands(ref.watch(sampleDataRepositoryProvider));
