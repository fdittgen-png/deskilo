// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2493 — the two widgets the drawer is made of: one destination and one
// collapsible group of them. They were closures inside ShellDrawer.build.
import 'package:flutter/material.dart';

import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import 'shell_drawer_entries.dart';

bool _isCurrent(DrawerEntry e, String path) =>
    e.selected || path == e.route || path.startsWith('${e.route}/');

/// One destination. #2313 — one line per entry: a label that wraps onto
/// three lines in a sidebar reads as fragments; it is cut with an ellipsis
/// instead and the tooltip-free full name stays in the semantics label.
class DrawerTile extends StatelessWidget {
  const DrawerTile({
    required this.entry,
    required this.path,
    required this.badge,
    super.key,
  });

  final DrawerEntry entry;
  final String path;

  /// The count that badges the entry; 0 for none.
  final int badge;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    return ListTile(
      key: ValueKey(e.key),
      leading: Icon(e.icon),
      title: Text(e.label, maxLines: 1, overflow: TextOverflow.ellipsis),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      horizontalTitleGap: AppSpacing.md,
      minLeadingWidth: 24,
      selected:
          e.selected ||
          (e.route != null &&
              (path == e.route || path.startsWith('${e.route}/'))),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
      selectedColor: Theme.of(context).colorScheme.onSecondaryContainer,
      trailing: badge > 0 ? Badge.count(count: badge, maxCount: 99) : null,
      onTap: e.onTap,
    );
  }
}

/// A titled group of [entries], open while one of them is the current
/// screen; nothing at all when it has none.
class DrawerGroup extends StatelessWidget {
  const DrawerGroup({
    required this.id,
    required this.title,
    required this.icon,
    required this.entries,
    required this.path,
    required this.tile,
    super.key,
  });

  final String id;
  final String title;
  final IconData icon;
  final List<DrawerEntry> entries;
  final String path;
  final Widget Function(DrawerEntry) tile;

  @override
  Widget build(BuildContext context) {
    final active = entries.any((e) => _isCurrent(e, path));
    if (entries.isEmpty) return const SizedBox.shrink();
    return ExpansionTile(
      key: PageStorageKey('drawer-group-$id-$active'),
      initiallyExpanded: active,
      tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      leading: Icon(icon),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      shape: const Border(),
      collapsedShape: const Border(),
      children: [for (final e in entries) tile(e)],
    );
  }
}
