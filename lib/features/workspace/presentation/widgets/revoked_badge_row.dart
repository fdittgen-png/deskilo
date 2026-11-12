// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/kit/row_menu.dart';

/// A revoked badge's row: deleted for good (field request — a badge
/// history piles up otherwise) by a swipe RIGHT or from the row's menu
/// (#3611: ⋯, a right click, a long press, the context-menu key), both
/// through the one [RowAction].
class RevokedBadgeRow extends StatelessWidget {
  const RevokedBadgeRow({
    super.key,
    required this.badgeId,
    required this.onDelete,
    required this.child,
  });

  final String badgeId;

  /// Asks, deletes and takes the row out of the list; the swipe never
  /// removes it itself, so a failed delete cannot lie about it.
  final Future<void> Function() onDelete;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final delete = RowAction(
      id: 'delete',
      label: context.l10n.commonDelete,
      icon: Icons.delete_outline,
      destructive: true,
      // recorder-key-exempt: the RowMenu keys this entry <keyPrefix>-<id>
      onSelected: onDelete,
    );
    // parity: badge-menu-
    return Dismissible(
      key: ValueKey('badge-dismiss-$badgeId'),
      direction: DismissDirection.startToEnd,
      background: ColoredBox(
        color: colorScheme.errorContainer,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(
              start: RevokedBadgeRowMetrics.swipeInset,
            ),
            child: Icon(
              Icons.delete_outline,
              color: colorScheme.onErrorContainer,
            ),
          ),
        ),
      ),
      confirmDismiss: (_) async {
        await delete.onSelected();
        return false;
      },
      child: RowMenu(
        actions: [delete],
        keyPrefix: 'badge-menu-$badgeId',
        child: child,
      ),
    );
  }
}

/// The row's layout numbers.
abstract final class RevokedBadgeRowMetrics {
  /// The bin icon's distance from the edge the swipe uncovers.
  static const double swipeInset = 16;
}
