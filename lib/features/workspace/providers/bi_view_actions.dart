// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1923 C / #2579 — the writes the saved-views bar and the report editor
// make. Each re-reads the list afterwards, so what is shown is what the
// server holds.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/ids/request_id.dart';
import '../domain/bi_saved_view.dart';
import 'bi_providers.dart';

/// The writes a views bar makes; each re-reads the list afterwards, so
/// what is shown is what the server holds.
class BiViewActions {
  BiViewActions(this._ref);

  final Ref _ref;

  BiViewRepository get _repo => _ref.read(biViewRepositoryProvider);

  /// Saves against the revision of [over] (a new view: 0). [requestId] names
  /// the write: the editor keeps it while it retries the same draft, so a
  /// lost answer is never a second revision; without one a fresh id is used.
  /// An answer that arrives once the reader has moved to another server or
  /// identity is not theirs any more and is dropped as refused.
  Future<BiSavedView> save(
    String workspaceId, {
    BiSavedView? over,
    required BiViewScope scope,
    required String name,
    required BiViewDefinition definition,
    String? requestId,
  }) async {
    final repo = _repo;
    try {
      final saved = await repo.save(
        workspaceId,
        id: over?.id,
        scope: scope,
        name: name,
        definition: definition,
        expectedRevision: over?.revision ?? 0,
        requestId: requestId ?? newRequestId(),
      );
      if (!identical(repo, _ref.read(biViewRepositoryProvider))) {
        throw const BiViewRefused(BiViewFailure.forbidden);
      }
      return saved;
    } finally {
      _ref.invalidate(biViewsProvider(workspaceId));
    }
  }

  Future<void> delete(String workspaceId, BiSavedView view) async {
    try {
      await _repo.delete(workspaceId, view.id, view.revision);
    } finally {
      _ref.invalidate(biViewsProvider(workspaceId));
    }
  }

  Future<void> setDefault(
    String workspaceId,
    BiViewScope scope,
    String? id,
  ) async {
    try {
      await _repo.setDefault(workspaceId, scope, id);
    } finally {
      _ref.invalidate(biViewsProvider(workspaceId));
    }
  }
}
