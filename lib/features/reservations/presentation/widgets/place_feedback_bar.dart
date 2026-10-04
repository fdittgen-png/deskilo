// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2185 — a heart and five stars on a bookable place: favourite it, rate it
// from 0 to 5, and read what everybody gave on average. Shown only where
// the workspace has favourites and ratings on and the person may use
// reservations; a failed write says so and changes nothing.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/place_feedback_commands.dart';
import '../../domain/place_feedback.dart';
import '../../providers/place_feedback_providers.dart';

class PlaceFeedbackBar extends ConsumerWidget {
  const PlaceFeedbackBar({super.key, required this.kind, required this.id});

  final PlaceKind kind;
  final String id;

  static Key heartKey(String id) => ValueKey('place-heart-$id');
  static Key starKey(String id, int n) => ValueKey('place-star-$id-$n');
  static Key zeroKey(String id) => ValueKey('place-zero-$id');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(placeFeedbackAvailableProvider)) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final feedback = ref.watch(placeFeedbackProvider(kind, id)).value ??
        const PlaceFeedback();

    Future<void> run(Future<void> Function() action) => runGuarded(
          context,
          domain: 'reservations',
          message: 'place feedback failed',
          errorText: l10n?.placeFeedbackFailed ?? 'Could not save. Please try again.',
          action: action,
        );

    final mine = feedback.mine;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.xs,
        children: [
          IconButton(
            key: heartKey(id),
            tooltip: feedback.favorite
                ? (l10n?.placeFeedbackUnfavorite ?? 'Remove from favourites')
                : (l10n?.placeFeedbackFavorite ?? 'Add to favourites'),
            isSelected: feedback.favorite,
            icon: const Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite, color: theme.colorScheme.error),
            onPressed: () => run(() => setPlaceFavorite(ref,
                kind: kind, id: id, on: !feedback.favorite)),
          ),
          TextButton(
            key: zeroKey(id),
            onPressed: () => run(() => setPlaceRating(ref,
                kind: kind, id: id, stars: mine == 0 ? null : 0)),
            child: Text(l10n?.placeFeedbackZero ?? '0 stars'),
          ),
          for (var n = 1; n <= 5; n++)
            IconButton(
              key: starKey(id, n),
              visualDensity: VisualDensity.compact,
              tooltip: l10n?.placeFeedbackStars(n) ?? '$n stars',
              icon: Icon(
                (mine ?? 0) >= n ? Icons.star : Icons.star_border,
                color: (mine ?? 0) >= n ? theme.colorScheme.tertiary : null,
              ),
              // The same star again takes the rating back.
              onPressed: () => run(() => setPlaceRating(ref,
                  kind: kind, id: id, stars: mine == n ? null : n)),
            ),
          Text(
            feedback.count == 0
                ? (l10n?.placeFeedbackNoRating ?? 'No rating yet')
                : (l10n?.placeFeedbackAverage(
                        feedback.average!.toStringAsFixed(1), feedback.count) ??
                    '${feedback.average!.toStringAsFixed(1)} · ${feedback.count}'),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
