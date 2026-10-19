// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart' show FutureProvider, Provider;
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/trace/trace_logger.dart';
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/domain/workspace_permission.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../data/supabase_place_feedback_repository.dart';
import '../data/supabase_room_offer_repository.dart';
import '../domain/place_feedback.dart';
import '../domain/room_offer.dart';

part 'place_feedback_providers.g.dart';

@Riverpod(keepAlive: true)
PlaceFeedbackRepository placeFeedbackRepository(Ref ref) =>
    SupabasePlaceFeedbackRepository(ref.watch(selectedWorkspaceClientProvider));

/// Whether the active workspace shows favourites and ratings to this
/// person: the feature is on and they may use reservations.
@riverpod
bool placeFeedbackAvailable(Ref ref) =>
    ref.watch(enabledFeaturesSyncProvider).contains(WorkspaceFeature.placeFeedback) &&
    ref.watch(myPermissionsProvider).contains(WorkspacePermission.makeReservations);

/// Whether the directory can show a workspace's feedback: it lives on this
/// installation (a workspace of another server has no feedback here).
@Riverpod(keepAlive: true)
bool Function(String source) directorySourceIsLocal(Ref ref) {
  String? origin;
  try {
    origin = Uri.parse(ref.read(selectedWorkspaceClientProvider).rest.url).host;
  } on Object catch (e, st) {
    // Not initialised: nothing is local (tests override it).
    TraceLogger.instance.warn('directory', 'no backend to compare a workspace source with',
        error: e, stackTrace: st);
    origin = null;
  }
  return (source) => origin != null && Uri.tryParse(source)?.host == origin;
}

/// Asks for places' feedback one request per screenful: every row of a list
/// asks for its own, and the asks of one moment travel together.
class PlaceFeedbackBatcher {
  PlaceFeedbackBatcher(this._repository);

  final PlaceFeedbackRepository _repository;
  final Map<String, Map<String, Completer<PlaceFeedback>>> _pending = {};

  Future<PlaceFeedback> get(String workspaceId, PlaceKind kind, String id) {
    final key = '$workspaceId|${kind.name}';
    final group = _pending.putIfAbsent(key, () {
      // One microtask, not a timer: every row of a frame asks while it
      // builds, so they all reach the group before it is sent.
      scheduleMicrotask(() => _flush(key, workspaceId, kind));
      return {};
    });
    return (group[id] ??= Completer<PlaceFeedback>()).future;
  }

  Future<void> _flush(String key, String workspaceId, PlaceKind kind) async {
    final group = _pending.remove(key);
    if (group == null) return;
    try {
      final answer =
          await _repository.fetchMany(workspaceId, kind, group.keys.toList());
      for (final entry in group.entries) {
        entry.value.complete(answer[entry.key] ?? const PlaceFeedback());
      }
    } catch (e, st) {
      // trace-exempt: handed to every asker, whose own provider reports it.
      for (final c in group.values) {
        c.completeError(e, st);
      }
    }
  }
}

@Riverpod(keepAlive: true)
PlaceFeedbackBatcher placeFeedbackBatcher(Ref ref) =>
    PlaceFeedbackBatcher(ref.watch(placeFeedbackRepositoryProvider));

/// One place's feedback, in the active workspace.
@riverpod
Future<PlaceFeedback> placeFeedback(Ref ref, PlaceKind kind, String id) async {
  final batcher = ref.watch(placeFeedbackBatcherProvider);
  // A workspace's own feedback needs no active workspace: it is the
  // person's, wherever they are.
  if (kind == PlaceKind.workspace) return batcher.get(id, kind, id);
  // Read, not awaited: the ask is made while the row builds, which is what
  // lets a screenful travel as one request. It asks again when the
  // workspace loads.
  final workspace = ref.watch(currentWorkspaceProvider).value;
  if (workspace == null) return const PlaceFeedback();
  return batcher.get(workspace.id, kind, id);
}

/// The favourites of the active workspace.
@riverpod
Future<List<FavoritePlace>> myFavoritePlaces(Ref ref) async {
  final repository = ref.watch(placeFeedbackRepositoryProvider);
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  return repository.favorites(workspace.id);
}

/// #2575 — what a rented room costs the member, read beside its booking
/// sheet. The seam tests and the demo replace.
@visibleForTesting
final roomOfferRepositoryProvider = Provider<RoomOfferRepository>(
  (ref) => SupabaseRoomOfferRepository(ref.watch(selectedWorkspaceClientProvider)),
);

/// The offer of one room for the signed-in member. An error — the room is not
/// offered to them, or rented rooms are off — is shown as nothing at all.
final roomOfferProvider = FutureProvider.autoDispose
    .family<RoomOfferView, ({String workspaceId, String officeId})>((ref, key) {
      if (!ref
          .watch(enabledFeaturesSyncProvider)
          .contains(WorkspaceFeature.externalRooms)) {
        throw StateError('rented rooms are switched off');
      }
      return ref
          .watch(roomOfferRepositoryProvider)
          .fetch(key.workspaceId, key.officeId);
    });
