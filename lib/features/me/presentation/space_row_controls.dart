// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Me › Home — what a person does with a row of their own list: star it, give
// it stars, move it up or down. Kept on this device (SpacePrefs). The heart
// and the stars given stay visible beside the name; the choices sit in one
// menu so the row keeps its height.
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// One way out of a space: the menu lists one per side of the row.
class SpaceLeaveItem {
  const SpaceLeaveItem({
    required this.id,
    required this.label,
    required this.onLeave,
    this.enabled = true,
  });
  final String id, label;
  final VoidCallback onLeave;
  final bool enabled;
}

class SpaceRowControls extends StatelessWidget {
  const SpaceRowControls({
    super.key,
    required this.rowKey,
    required this.name,
    required this.favorite,
    required this.rating,
    required this.onFavorite,
    required this.onRate,
    this.onUp,
    this.onDown,
    this.leave = const [],
    this.onMoveToGroup,
  });

  final String rowKey, name;
  final bool favorite;
  final int? rating;
  final VoidCallback onFavorite;
  final ValueChanged<int?> onRate;

  /// Null when the row cannot move that way.
  final VoidCallback? onUp, onDown;

  /// The ways to leave, one per side; owners cannot (they hand over first).
  final List<SpaceLeaveItem> leave;

  /// Opens the choice of group; null hides the entry.
  final VoidCallback? onMoveToGroup;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final key = 'space-menu-$rowKey';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (favorite)
          Icon(
            Icons.favorite,
            key: ValueKey('space-favorite-$rowKey'),
            size: 16,
            color: scheme.error,
          ),
        if (rating != null) ...[
          const SizedBox(width: 6),
          Icon(Icons.star_rounded, size: 18, color: Colors.amber.shade700),
          const SizedBox(width: 2),
          Text(
            '$rating',
            key: ValueKey('space-rating-$rowKey'),
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
        PopupMenuButton<String>(
          style: IconButton.styleFrom(
            foregroundColor: scheme.onSurfaceVariant,
            backgroundColor: Colors.transparent,
            side: BorderSide.none,
          ),
          key: ValueKey(key),
          tooltip: l10n?.spaceOptions(name) ?? 'Options for $name',
          onSelected: (v) {
            switch (v) {
              case 'favorite':
                onFavorite();
              case 'group':
                onMoveToGroup?.call();
              case 'up':
                onUp?.call();
              case 'down':
                onDown?.call();
              case 'clear':
                onRate(null);
              default:
                if (v.startsWith('leave:')) {
                  leave.firstWhere((l) => 'leave:${l.id}' == v).onLeave();
                } else {
                  onRate(int.parse(v));
                }
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              key: ValueKey('$key-favorite'),
              value: 'favorite',
              child: Text(
                favorite
                    ? (l10n?.spaceFavoriteRemove ?? 'Remove from favorites')
                    : (l10n?.spaceFavoriteAdd ?? 'Add to favorites'),
              ),
            ),
            if (onMoveToGroup != null)
              PopupMenuItem(
                key: ValueKey('$key-group'),
                value: 'group',
                child: Text(l10n?.meGroupMove ?? 'Move to group…'),
              ),
            PopupMenuItem(
              key: ValueKey('$key-up'),
              value: 'up',
              enabled: onUp != null,
              child: Text(l10n?.spaceMoveUp ?? 'Move up'),
            ),
            PopupMenuItem(
              key: ValueKey('$key-down'),
              value: 'down',
              enabled: onDown != null,
              child: Text(l10n?.spaceMoveDown ?? 'Move down'),
            ),
            const PopupMenuDivider(),
            for (var n = 5; n >= 1; n--)
              PopupMenuItem(
                key: ValueKey('$key-rate-$n'),
                value: '$n',
                child: _Stars(n),
              ),
            PopupMenuItem(
              key: ValueKey('$key-clear'),
              value: 'clear',
              child: Text(l10n?.spaceRatingClear ?? 'No rating'),
            ),
            if (leave.isNotEmpty) const PopupMenuDivider(),
            // An owner cannot leave either side: say it once, not per side.
            for (final l in leave.every((l) => !l.enabled)
                ? leave.take(1)
                : leave)
              PopupMenuItem(
                key: ValueKey('$key-leave-${l.id}'),
                value: 'leave:${l.id}',
                enabled: l.enabled,
                child: Text(l.label),
              ),
          ],
        ),
      ],
    );
  }
}

/// n of 5 stars, the earned ones gold and filled, the rest plain outlines,
/// with the number beside them — so 3 and 4 cannot be mistaken in a menu.
class _Stars extends StatelessWidget {
  const _Stars(this.n);
  final int n;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '$n / 5',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 1; i <= 5; i++)
            Icon(
              i <= n ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 22,
              color: i <= n
                  ? Colors.amber.shade600
                  : scheme.onSurfaceVariant.withValues(alpha: .45),
            ),
          const SizedBox(width: 10),
          Text('$n', style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}
