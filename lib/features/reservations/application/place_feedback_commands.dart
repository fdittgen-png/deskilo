// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2185 — marking a place as a favourite and rating it. The screens say what
// the person did; this decides what is written and what is read again, so
// none of them resolves the repository (ADR 0024, the layering ratchet).
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../workspace/providers/workspace_providers.dart';
import '../domain/place_feedback.dart';
import '../providers/place_feedback_providers.dart';

Future<void> setPlaceFavorite(
  WidgetRef ref, {
  required PlaceKind kind,
  required String id,
  required bool on,
}) async {
  final workspace = await ref.read(currentWorkspaceProvider.future);
  if (workspace == null) return;
  await ref
      .read(placeFeedbackRepositoryProvider)
      .setFavorite(workspace.id, kind, id, on: on);
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
  final workspace = await ref.read(currentWorkspaceProvider.future);
  if (workspace == null) return;
  await ref
      .read(placeFeedbackRepositoryProvider)
      .setRating(workspace.id, kind, id, stars);
  ref
    ..invalidate(placeFeedbackProvider(kind, id))
    ..invalidate(myFavoritePlacesProvider);
}
