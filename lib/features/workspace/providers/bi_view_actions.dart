// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1923 C / #2579 — the writes the saved-views bar and the report editor
// make. Each re-reads the list afterwards, so what is shown is what the
// server holds.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/ids/request_id.dart';
import '../../../core/trace/trace_logger.dart';
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

  /// #4340 -- the analyses a person last chose, and their order, kept as their OWN default view
  /// ([name]; the same view is found again by any of [knownNames], the name in each language), so
  /// the page opens on them next time on any device. Private to the person and the business; the
  /// server's own default rule applies (a bare /bi opens it, an address or an opened view wins).
  Future<void> rememberCards(
    String workspaceId,
    List<String> cards, {
    required String name,
    required Set<String> knownNames,
  }) async {
    final mine = await _myCardsView(workspaceId, knownNames);
    final saved = await save(
      workspaceId,
      over: mine,
      scope: BiViewScope.private,
      name: mine?.name ?? name,
      definition: BiViewDefinition(cards: cards),
    );
    await setDefault(workspaceId, BiViewScope.private, saved.id);
  }

  /// #4340 -- what a change of the analyses shown does to the person's own default: the choice is
  /// remembered, the standard clears it, a change of anything else leaves it. True when the default
  /// is in step; false when the server could not be asked (said by the caller, never silent).
  Future<bool> keepCards(
    String workspaceId, {
    required List<String> before,
    required List<String> after,
    required String name,
    required Set<String> knownNames,
  }) async {
    if (before.length == after.length && [for (var i = 0; i < after.length; i++) before[i] == after[i]].every((s) => s)) {
      return true;
    }
    try {
      if (after.isEmpty) {
        await forgetCards(workspaceId, knownNames: knownNames);
      } else {
        await rememberCards(workspaceId, after, name: name, knownNames: knownNames);
      }
      return true;
    } on Object catch (e, st) {
      TraceLogger.instance.warn('bi', 'the analyses default was not kept: $e', stackTrace: st);
      return false;
    }
  }

  /// #4340 -- "Back to the standard": the person's own default is cleared, and the view that held it
  /// (the one [rememberCards] made) goes with it.
  Future<void> forgetCards(String workspaceId, {required Set<String> knownNames}) async {
    final mine = await _myCardsView(workspaceId, knownNames);
    await setDefault(workspaceId, BiViewScope.private, null);
    if (mine != null) await delete(workspaceId, mine);
  }

  Future<BiSavedView?> _myCardsView(String workspaceId, Set<String> knownNames) async {
    final views = await _repo.list(workspaceId);
    return views
        .where((v) => v.scope == BiViewScope.private && v.mine && knownNames.contains(v.name))
        .firstOrNull;
  }
}
