// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2185 — marking a place as a favourite and rating it. The screens say what
// the person did; this decides what is written and what is read again, so
// none of them resolves the repository (ADR 0024, the layering ratchet).
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../workspace/providers/workspace_providers.dart';
import '../domain/place_feedback.dart';
import '../providers/place_feedback_providers.dart';

/// The workspace a write is made in: the active one for a resource of it;
/// a workspace is its own scope.
Future<String?> _scopeOf(WidgetRef ref, PlaceKind kind, String id) async {
  if (kind == PlaceKind.workspace) return id;
  return (await ref.read(currentWorkspaceProvider.future))?.id;
}

Future<void> setPlaceFavorite(
  WidgetRef ref, {
  required PlaceKind kind,
  required String id,
  required bool on,
}) async {
  final scope = await _scopeOf(ref, kind, id);
  if (scope == null) return;
  await ref
      .read(placeFeedbackRepositoryProvider)
      .setFavorite(scope, kind, id, on: on);
  ref
    ..invalidate(placeFeedbackProvider(kind, id))
    ..invalidate(myFavoritePlacesProvider);
}

/// 0-5 stars; null takes the person's rating back.
Future<void> setPlaceRating(
  WidgetRef ref, {
  required PlaceKind kind,
  required String id,
  required int? stars,
}) async {
  final scope = await _scopeOf(ref, kind, id);
  if (scope == null) return;
  await ref
      .read(placeFeedbackRepositoryProvider)
      .setRating(scope, kind, id, stars);
  ref
    ..invalidate(placeFeedbackProvider(kind, id))
    ..invalidate(myFavoritePlacesProvider);
}
