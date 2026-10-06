// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Me › Home — what a person does with a row of their own list: star it, give
// it stars, move it up or down. Kept on this device (SpacePrefs). The heart
// and the stars given stay visible beside the name; the choices sit in one
// menu so the row keeps its height.
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

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
  });

  final String rowKey, name;
  final bool favorite;
  final int? rating;
  final VoidCallback onFavorite;
  final ValueChanged<int?> onRate;

  /// Null when the row cannot move that way.
  final VoidCallback? onUp, onDown;

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
            size: 18,
            color: scheme.error,
          ),
        if (rating != null) ...[
          Icon(Icons.star, size: 18, color: Colors.amber.shade700),
          Text('$rating', key: ValueKey('space-rating-$rowKey')),
        ],
        PopupMenuButton<String>(
          key: ValueKey(key),
          tooltip: l10n?.spaceOptions(name) ?? 'Options for $name',
          onSelected: (v) {
            switch (v) {
              case 'favorite':
                onFavorite();
              case 'up':
                onUp?.call();
              case 'down':
                onDown?.call();
              case 'clear':
                onRate(null);
              default:
                onRate(int.parse(v));
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
                child: Text('${'★' * n}${'☆' * (5 - n)}'),
              ),
            PopupMenuItem(
              key: ValueKey('$key-clear'),
              value: 'clear',
              child: Text(l10n?.spaceRatingClear ?? 'No rating'),
            ),
          ],
        ),
      ],
    );
  }
}
