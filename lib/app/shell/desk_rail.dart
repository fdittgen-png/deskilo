// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3603 — the desk's rail: the business's navigation in a narrow column,
// each destination an icon over its short label, each group an icon that
// opens its entries as a flyout. The same destinations and groups as the
// drawer and the sidebar (shell_nav_groups.dart), never a second table.
import 'package:flutter/material.dart';

import '../../core/l10n/context_l10n.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/profile/presentation/widgets/personal_avatar.dart';
import 'shell_drawer_entries.dart';
import 'shell_nav_groups.dart';

/// The rail. [badgeOf] is the count an entry carries (0 for none).
class DeskRail extends StatelessWidget {
  const DeskRail({
    required this.destinations,
    required this.groups,
    required this.account,
    required this.path,
    required this.badgeOf,
    required this.onBackToMe,
    super.key,
  });

  final List<DrawerEntry> destinations;
  final List<NavGroup> groups;
  final List<DrawerEntry> account;
  final String path;
  final int Function(DrawerEntry) badgeOf;
  final VoidCallback onBackToMe;

  bool _current(DrawerEntry e) =>
      e.selected ||
      (e.route != null && (path == e.route || path.startsWith('${e.route}/')));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget item(DrawerEntry e) => _RailItem(
      key: ValueKey('rail-${e.key}'),
      icon: Icon(e.icon),
      label: e.label,
      selected: _current(e),
      badge: badgeOf(e),
      onTap: e.onTap,
    );
    return Material(
      key: const ValueKey('desk-rail'),
      color: theme.colorScheme.surfaceContainerLow,
      child: SafeArea(
        child: ListView(
          padding: AppSpacing.xsAll,
          children: [
            _RailItem(
              key: const ValueKey('rail-back-to-me'),
              icon: const PersonalAvatar(),
              label: context.l10n.spaceBackToMe,
              onTap: onBackToMe,
            ),
            const Divider(),
            for (final e in destinations) item(e),
            const Divider(),
            for (final g in groups)
              if (!g.isEmpty) _RailGroup(group: g, current: _current),
            const Divider(),
            for (final e in account) item(e),
          ],
        ),
      ),
    );
  }
}

/// One destination: the icon over its label, the whole cell one target.
class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.badge = 0,
    super.key,
  });

  final Widget icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: Padding(
          padding: AppSpacing.xsAll,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: selected ? scheme.secondaryContainer : null,
                  borderRadius: AppRadius.lgAll,
                ),
                child: Padding(
                  padding: AppSpacing.xsAll,
                  child: badge > 0
                      ? Badge.count(count: badge, maxCount: 99, child: icon)
                      : icon,
                ),
              ),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A group: its icon and title open its entries (and sub-groups) beside
/// the rail.
class _RailGroup extends StatelessWidget {
  const _RailGroup({required this.group, required this.current});

  final NavGroup group;
  final bool Function(DrawerEntry) current;

  bool _active(NavGroup g) =>
      g.entries.any(current) || g.sub.any(_active);

  List<Widget> _children(NavGroup g) => [
    for (final e in g.entries)
      MenuItemButton(
        key: ValueKey('rail-${e.key}'),
        leadingIcon: Icon(e.icon),
        onPressed: e.onTap,
        child: Text(e.label),
      ),
    for (final s in g.sub)
      if (!s.isEmpty)
        SubmenuButton(
          key: ValueKey('rail-group-${s.id}'),
          leadingIcon: Icon(s.icon),
          menuChildren: _children(s),
          child: Text(s.title),
        ),
  ];

  @override
  Widget build(BuildContext context) => MenuAnchor(
    alignmentOffset: const Offset(AppSpacing.xs, 0),
    style: const MenuStyle(
      alignment: AlignmentDirectional.topEnd,
    ),
    menuChildren: _children(group),
    builder: (context, controller, _) => _RailItem(
      key: ValueKey('rail-group-${group.id}'),
      icon: Icon(group.icon),
      label: group.title,
      selected: _active(group),
      onTap: () =>
          controller.isOpen ? controller.close() : controller.open(),
    ),
  );
}
