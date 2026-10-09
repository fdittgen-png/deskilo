// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2185 — a heart and five stars on a bookable place: favourite it, rate it
// from 0 to 5, and read what everybody gave on average. Shown only where
// the workspace has favourites and ratings on and the person may use
// reservations; a failed write says so and changes nothing.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_radius.dart';
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
    if (!placeFeedbackShown(ref, kind)) return const SizedBox.shrink();
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
    // Round, borderless: the icon-button theme's outlined box (the title
    // bar's look) made six boxes in a row here.
    final round = IconButton.styleFrom(shape: const CircleBorder());
    final summary = Text(
      feedback.count == 0
          ? (l10n?.placeFeedbackNoRating ?? 'No rating yet')
          : (l10n?.placeFeedbackAverage(
                  feedback.average!.toStringAsFixed(1), feedback.count) ??
              '${feedback.average!.toStringAsFixed(1)} · ${feedback.count}'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall
          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
    );
    // #2313 — two lines that never break: the heart and the five stars on
    // one (shrunk a little rather than wrapped on a narrow screen with
    // large text), the average and the 0-star choice on the next. A Wrap
    // used to push the fifth star and the average onto a line of their
    // own on a phone.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                key: heartKey(id),
                style: round,
                tooltip: feedback.favorite
                    ? (l10n?.placeFeedbackUnfavorite ?? 'Remove from favourites')
                    : (l10n?.placeFeedbackFavorite ?? 'Add to favourites'),
                isSelected: feedback.favorite,
                icon: const Icon(Icons.favorite_border),
                selectedIcon:
                    Icon(Icons.favorite, color: theme.colorScheme.error),
                onPressed: () => run(() => setPlaceFavorite(ref,
                    kind: kind, id: id, on: !feedback.favorite)),
              ),
              const SizedBox(width: AppSpacing.sm),
              for (var n = 1; n <= 5; n++)
                IconButton(
                  key: starKey(id, n),
                  style: round,
                  tooltip: l10n?.placeFeedbackStars(n) ?? '$n stars',
                  icon: Icon(
                    (mine ?? 0) >= n ? Icons.star : Icons.star_border,
                    color: (mine ?? 0) >= n ? theme.colorScheme.tertiary : null,
                  ),
                  // The same star again takes the rating back.
                  onPressed: () => run(() => setPlaceRating(ref,
                      kind: kind, id: id, stars: mine == n ? null : n)),
                ),
            ]),
          ),
          Row(children: [
            const SizedBox(width: AppSpacing.md),
            Expanded(child: summary),
            Flexible(
              child: TextButton(
                key: zeroKey(id),
                onPressed: () => run(() => setPlaceRating(ref,
                    kind: kind, id: id, stars: mine == 0 ? null : 0)),
                child: Text(l10n?.placeFeedbackZero ?? '0 stars',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

/// Whether favourites and ratings show for [kind]: a workspace's are the
/// person's own, wherever they are; any other resource follows the active
/// workspace's flag and the permission to use reservations.
bool placeFeedbackShown(WidgetRef ref, PlaceKind kind) =>
    kind == PlaceKind.workspace || ref.watch(placeFeedbackAvailableProvider);

/// The compact face for a list row or a card: a heart and the average with
/// its count. Tapping the heart toggles the favourite; tapping the rating
/// opens the full bar in a sheet, so rating is one tap from anywhere.
class PlaceFeedbackChip extends ConsumerWidget {
  const PlaceFeedbackChip({super.key, required this.kind, required this.id, this.title});

  final PlaceKind kind;
  final String id;
  final String? title;

  static Key heartKey(String id) => ValueKey('place-chip-heart-$id');
  static Key rateKey(String id) => ValueKey('place-chip-rate-$id');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!placeFeedbackShown(ref, kind)) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final feedback = ref.watch(placeFeedbackProvider(kind, id)).value ??
        const PlaceFeedback();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
        key: heartKey(id),
        visualDensity: VisualDensity.compact,
        tooltip: feedback.favorite
            ? (l10n?.placeFeedbackUnfavorite ?? 'Remove from favourites')
            : (l10n?.placeFeedbackFavorite ?? 'Add to favourites'),
        isSelected: feedback.favorite,
        icon: const Icon(Icons.favorite_border),
        selectedIcon: Icon(Icons.favorite, color: theme.colorScheme.error),
        onPressed: () => runGuarded(
          context,
          domain: 'reservations',
          message: 'place feedback failed',
          errorText: l10n?.placeFeedbackFailed ?? 'Could not save. Please try again.',
          action: () => setPlaceFavorite(ref,
              kind: kind, id: id, on: !feedback.favorite),
        ),
      ),
      InkWell(
        key: rateKey(id),
        borderRadius: AppRadius.lgAll,
        onTap: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (_) => SafeArea(
            child: Padding(
              padding: AppSpacing.lgAll,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (title != null)
                  Text(title!, style: theme.textTheme.titleMedium),
                PlaceFeedbackBar(kind: kind, id: id),
              ]),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              (feedback.mine ?? 0) > 0 ? Icons.star : Icons.star_border,
              size: 18,
              color: (feedback.mine ?? 0) > 0 ? theme.colorScheme.tertiary : null,
            ),
            const SizedBox(width: 2),
            Text(
              feedback.count == 0
                  ? '–'
                  : '${feedback.average!.toStringAsFixed(1)} (${feedback.count})',
              style: theme.textTheme.labelMedium,
            ),
          ]),
        ),
      ),
    ]);
  }
}
