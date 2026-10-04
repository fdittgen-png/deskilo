// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/domain/workspace_permission.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../data/supabase_place_feedback_repository.dart';
import '../domain/place_feedback.dart';

part 'place_feedback_providers.g.dart';

@Riverpod(keepAlive: true)
PlaceFeedbackRepository placeFeedbackRepository(Ref ref) =>
    SupabasePlaceFeedbackRepository(Supabase.instance.client);

/// Whether the active workspace shows favourites and ratings to this
/// person: the feature is on and they may use reservations.
@riverpod
bool placeFeedbackAvailable(Ref ref) =>
    ref.watch(enabledFeaturesSyncProvider).contains(WorkspaceFeature.placeFeedback) &&
    ref.watch(myPermissionsProvider).contains(WorkspacePermission.makeReservations);

/// One place's feedback, in the active workspace.
@riverpod
Future<PlaceFeedback> placeFeedback(Ref ref, PlaceKind kind, String id) async {
  final repository = ref.watch(placeFeedbackRepositoryProvider);
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const PlaceFeedback();
  return repository.fetch(workspace.id, kind, id);
}

/// The favourites of the active workspace.
@riverpod
Future<List<FavoritePlace>> myFavoritePlaces(Ref ref) async {
  final repository = ref.watch(placeFeedbackRepositoryProvider);
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  return repository.favorites(workspace.id);
}
