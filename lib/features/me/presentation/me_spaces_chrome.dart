// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Me › Home — the controls around my list of spaces: the search, sort and
// new-group line above it, and each group's header.
import 'package:flutter/material.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/storage/space_prefs_store.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Search, sort and a new group, on one line.
class MeSpacesToolbar extends StatelessWidget {
  const MeSpacesToolbar({
    super.key,
    required this.sort,
    required this.onQuery,
    required this.onSort,
    required this.onAddGroup,
  });
  final SpaceSort sort;
  final ValueChanged<String> onQuery;
  final ValueChanged<SpaceSort> onSort;
  final VoidCallback onAddGroup;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String label(SpaceSort s) => switch (s) {
      SpaceSort.byHand => l10n.meSortHand,
      SpaceSort.recent => l10n.meSortRecent,
      SpaceSort.rating => l10n.meSortRating,
      SpaceSort.alphabet => l10n.meSortAlphabet,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('me-spaces-search'),
              onChanged: onQuery,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.meSpacesSearch,
                filled: true,
                border: const OutlineInputBorder(
                  borderRadius: AppRadius.xlAll,
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          PopupMenuButton<SpaceSort>(
            key: const ValueKey('me-spaces-sort'),
            tooltip: l10n.meSortTooltip,
            icon: const Icon(Icons.sort),
            style: IconButton.styleFrom(side: BorderSide.none),
            initialValue: sort,
            onSelected: onSort,
            itemBuilder: (_) => [
              for (final s in SpaceSort.values)
                CheckedPopupMenuItem(
                  key: ValueKey('me-spaces-sort-${s.wire}'),
                  value: s,
                  checked: s == sort,
                  child: Text(label(s)),
                ),
            ],
          ),
          IconButton(
            key: const ValueKey('me-spaces-add-group'),
            tooltip: l10n.meGroupAdd,
            style: IconButton.styleFrom(side: BorderSide.none),
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: onAddGroup,
          ),
        ],
      ),
    );
  }
}

/// A group's header: fold it, see its count, rename or remove my own.
class MeGroupHeader extends StatelessWidget {
  const MeGroupHeader({
    super.key,
    required this.id,
    required this.title,
    required this.count,
    required this.folded,
    required this.own,
    required this.onToggle,
    required this.onRename,
    required this.onDelete,
  });
  final String id, title;
  final int count;
  final bool folded, own;
  final VoidCallback onToggle, onRename, onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              key: ValueKey('me-group-$id'),
              borderRadius: AppRadius.mdAll,
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.sm,
                  horizontal: AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    AnimatedRotation(
                      turns: folded ? -0.25 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: const Icon(Icons.expand_more),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    if (id == SpaceGroup.favoritesGroup) ...[
                      Icon(
                        Icons.favorite,
                        size: 16,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.strong,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '$count',
                      key: ValueKey('me-group-count-$id'),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (own)
            PopupMenuButton<String>(
              key: ValueKey('me-group-menu-$id'),
              style: IconButton.styleFrom(side: BorderSide.none),
              onSelected: (v) => v == 'rename' ? onRename() : onDelete(),
              itemBuilder: (_) => [
                PopupMenuItem(
                  key: ValueKey('me-group-rename-$id'),
                  value: 'rename',
                  child: Text(l10n.meGroupRename),
                ),
                PopupMenuItem(
                  key: ValueKey('me-group-delete-$id'),
                  value: 'delete',
                  child: Text(l10n.meGroupDelete),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
