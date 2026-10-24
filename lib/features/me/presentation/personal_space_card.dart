// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2554 — one card of My spaces: a lone space, or both sides of a
// test/production pair of this server with the test side inside it. The
// card is not a button: its actions are, each its own target — the main
// action its state allows, the favourite heart, My review, and Move
// up/down where the person orders the list by hand. Favourite, review and
// order are kept on this device (SpacePrefs), under the same key the
// legacy list used, so nothing chosen there is lost.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/space_entry.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/storage/space_prefs_store.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/personal_theme.dart';
import '../../../core/time/clock.dart';
import '../../../l10n/app_localizations.dart';
import '../../workspace/domain/workspace.dart';
import '../application/personal_spaces_view.dart';
import '../domain/personal_workspace_refs.dart';
import '../domain/space_pairs.dart';
import '../providers/space_prefs_provider.dart';
import 'personal_refs_section.dart';
import 'space_row_controls.dart';

/// Move up and Move down of a card; a null side is at its end.
typedef PersonalSpaceMove = ({VoidCallback? up, VoidCallback? down});

/// The minimum height of every target on the card.
const Size _target = Size(0, PersonalShellMetrics.minTarget);

class PersonalSpaceCard extends ConsumerWidget {
  const PersonalSpaceCard({super.key, required this.row, this.move});

  final PersonalSpaceRow row;

  /// Null hides Move up/down (the Overview's preview).
  final PersonalSpaceMove? move;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tokens = PersonalTheme.of(context);
    final theme = Theme.of(context);
    final prefs = ref.watch(spacePrefsProvider).value ?? SpacePrefs.empty;
    final main = row.main;
    final id = main.ref.networkId;
    final unverified = main.ref.freshness == RefFreshness.unavailable;
    final favorite = prefs.favorites.contains(row.key);
    final test = row.testSide;
    return Card(
      key: ValueKey('my-space-$id'),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: PersonalShellMetrics.cardRadiusAll,
        side: BorderSide(color: tokens.decorativeBorder),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  unverified
                      ? Icons.cloud_off_outlined
                      : Icons.meeting_room_outlined,
                  color: tokens.secondaryText,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    main.ref.label ?? l10n.meRefUnnamed,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.strong,
                  ),
                ),
                // Saved on my account (#2563): not the heart of this device.
                if (row.sides.any((s) => s.ref.isFavorite))
                  Icon(
                    Icons.bookmark_outline,
                    color: tokens.secondaryText,
                    semanticLabel: l10n.mySpacesSavedOnAccount,
                  ),
                IconButton(
                  key: ValueKey('my-space-favorite-${row.key}'),
                  tooltip: favorite
                      ? l10n.spaceFavoriteRemove
                      : l10n.spaceFavoriteAdd,
                  isSelected: favorite,
                  icon: const Icon(Icons.favorite_border),
                  selectedIcon: Icon(Icons.favorite, color: tokens.danger),
                  onPressed: () => unawaited(
                    ref
                        .read(spacePrefsProvider.notifier)
                        .toggleFavorite(row.key),
                  ),
                ),
              ],
            ),
            Text(
              main.host == PersonalSpaceHost.here
                  ? l10n.mySpacesHostHere
                  : l10n.mySpacesHostElsewhere,
              key: ValueKey('my-space-host-$id'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: tokens.secondaryText,
              ),
            ),
            Text(
              _state(l10n, main),
              key: ValueKey('my-space-state-$id'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: unverified ? tokens.warning : tokens.secondaryText,
              ),
            ),
            if (test != null) _TestSide(entry: test),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ?_action(context, ref, main, l10n),
                _Review(rowKey: row.key, rating: prefs.ratings[row.key]),
                if (move case final move?) ...[
                  IconButton(
                    key: ValueKey('my-space-up-${row.key}'),
                    tooltip: l10n.spaceMoveUp,
                    icon: const Icon(Icons.arrow_upward),
                    onPressed: move.up,
                  ),
                  IconButton(
                    key: ValueKey('my-space-down-${row.key}'),
                    tooltip: l10n.spaceMoveDown,
                    icon: const Icon(Icons.arrow_downward),
                    onPressed: move.down,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _state(AppLocalizations l10n, PersonalSpaceEntry entry) => [
  if (entry.verified) l10n.mySpacesVerified,
  PersonalRefsSection.detail(l10n, entry.ref),
  if (entry.isTest) l10n.mySpacesTestSpace,
].join(' · ');

void _open(WidgetRef ref, BuildContext context, Workspace space) {
  // The "recently used" order remembers when I went in.
  unawaited(
    ref
        .read(spacePrefsProvider.notifier)
        .touch(spaceRowKeyOf(space), ref.read(clockProvider).now()),
  );
  unawaited(enterSpace(context, ref, space));
}

/// The one action [entry]'s state allows, or null.
Widget? _action(
  BuildContext context,
  WidgetRef ref,
  PersonalSpaceEntry entry,
  AppLocalizations l10n,
) {
  final id = entry.ref.networkId;
  final local = entry.local;
  return switch (entry.action) {
    PersonalSpaceAction.open when local != null =>
      entry.isTest
          ? OutlinedButton(
              key: ValueKey('my-space-open-$id'),
              style: OutlinedButton.styleFrom(minimumSize: _target),
              onPressed: () => _open(ref, context, local),
              child: Text(l10n.mySpacesOpenTest),
            )
          : FilledButton.tonal(
              key: ValueKey('my-space-open-$id'),
              style: FilledButton.styleFrom(minimumSize: _target),
              onPressed: () => _open(ref, context, local),
              child: Text(l10n.mySpacesOpen),
            ),
    PersonalSpaceAction.requestStatus => OutlinedButton(
      key: ValueKey('my-space-request-$id'),
      style: OutlinedButton.styleFrom(minimumSize: _target),
      onPressed: () => context.push('/applications'),
      child: Text(l10n.mySpacesRequestStatus),
    ),
    _ => null,
  };
}

/// The test side of a pair, inside its card: what it is, its state and its
/// own action.
class _TestSide extends ConsumerWidget {
  const _TestSide({required this.entry});

  final PersonalSpaceEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tokens = PersonalTheme.of(context);
    final theme = Theme.of(context);
    final id = entry.ref.networkId;
    return Container(
      key: ValueKey('my-space-test-$id'),
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: tokens.subtle,
        borderRadius: PersonalShellMetrics.cardRadiusAll,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _state(l10n, entry),
              key: ValueKey('my-space-state-$id'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: tokens.secondaryText,
              ),
            ),
          ),
          ?_action(context, ref, entry, l10n),
        ],
      ),
    );
  }
}

/// My review: my own stars for the space, kept on this device — a choice
/// of its own, never the favourite.
class _Review extends ConsumerWidget {
  const _Review({required this.rowKey, required this.rating});

  final String rowKey;
  final int? rating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final key = 'my-space-review-$rowKey';
    final stars = rating;
    return PopupMenuButton<int>(
      key: ValueKey(key),
      tooltip: l10n.mySpacesReview,
      onSelected: (n) => unawaited(
        ref.read(spacePrefsProvider.notifier).rate(rowKey, n == 0 ? null : n),
      ),
      itemBuilder: (_) => [
        for (var n = 5; n >= 1; n--)
          PopupMenuItem(
            key: ValueKey('$key-$n'),
            value: n,
            child: SpaceStars(n),
          ),
        PopupMenuItem(
          key: ValueKey('$key-clear'),
          value: 0,
          child: Text(l10n.spaceRatingClear),
        ),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: PersonalShellMetrics.minTarget,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                stars == null ? Icons.star_outline_rounded : Icons.star_rounded,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                stars == null
                    ? l10n.mySpacesReview
                    : l10n.mySpacesReviewed(stars),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
