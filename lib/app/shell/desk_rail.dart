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
import '../../features/workspace/domain/workspace.dart';
import '../../features/workspace/presentation/widgets/workspace_avatar.dart';
import 'house_switch.dart';
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
    this.current,
    this.houses = const [],
    this.onHouse,
    super.key,
  });

  final List<DrawerEntry> destinations;
  final List<NavGroup> groups;
  final List<DrawerEntry> account;
  final String path;
  final int Function(DrawerEntry) badgeOf;
  final VoidCallback onBackToMe;

  /// #4129 -- the business one is in, listed first among the houses where
  /// there are other houses, and marked as the current one.
  final Workspace? current;

  /// #4006 — the other houses of the organisation, one tap away.
  final List<Workspace> houses;
  final ValueChanged<Workspace>? onHouse;

  bool _current(DrawerEntry e) => entryIsCurrent(e, path);

  /// A house: its name in whole words, announced and explained as
  /// `Name — Country · CUR`.
  Widget _houseItem(
    BuildContext context,
    Workspace house, {
    bool selected = false,
  }) {
    final full = houseLabel(context.l10n, house);
    return _RailItem(
      key: ValueKey('rail-house-${house.id}'),
      icon: WorkspaceAvatar(workspace: house, radius: 12),
      label: full,
      shown: _WholeWords(text: house.name),
      selected: selected,
      onTap: onHouse == null || selected ? null : () => onHouse!(house),
    );
  }

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
        // Not a ListView: a lazy list drops its first items once Tab has walked
        // past its cache, and a focus stop that was disposed can no longer be
        // the one Tab comes back to (#4279). Every item stays built.
        child: SingleChildScrollView(
          padding: AppSpacing.xsAll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RailItem(
                key: const ValueKey('rail-back-to-me'),
                icon: const PersonalAvatar(),
                label: context.l10n.spaceBackToMe,
                onTap: onBackToMe,
              ),
              if (houses.isNotEmpty && current != null)
                _houseItem(context, current!, selected: true),
              for (final house in houses) _houseItem(context, house),
              const Divider(),
              for (final e in destinations) item(e),
              const Divider(),
              for (final g in groups)
                if (!g.isEmpty) _RailGroup(group: g, path: path),
              const Divider(),
              for (final e in account) item(e),
            ],
          ),
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
    this.shown,
    this.selected = false,
    this.badge = 0,
    super.key,
  });

  final Widget icon;
  final String label;

  /// What is drawn under the icon when it is not [label] as plain text; the
  /// tooltip and the assistive name stay [label] (#4129).
  final Widget? shown;
  final VoidCallback? onTap;
  final bool selected;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final item = Semantics(
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
              shown ??
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
    return shown == null
        ? item
        : Tooltip(message: label, excludeFromSemantics: true, child: item);
  }
}

/// #4129 -- [text] in at most two lines of whole words: a word that does not
/// fit its line is scaled down, never cut, and what does not fit two lines is
/// left out with an ellipsis after the last whole word. The full name is the
/// item's tooltip and its name to assistive technology.
class _WholeWords extends StatelessWidget {
  const _WholeWords({required this.text});

  static const int lines = 2;
  static const String ellipsis = '…';

  final String text;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        double width(String line) {
          final painter = TextPainter(
            text: TextSpan(text: line, style: style),
            textDirection: direction,
            textScaler: scaler,
          )..layout();
          final w = painter.width;
          painter.dispose();
          return w;
        }

        final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
        final rows = <String>[];
        var rest = words.toList();
        while (rest.isNotEmpty && rows.length < lines) {
          var row = rest.first;
          var used = 1;
          while (used < rest.length &&
              width('$row ${rest[used]}') <= constraints.maxWidth) {
            row = '$row ${rest[used]}';
            used++;
          }
          rest = rest.sublist(used);
          rows.add(row);
        }
        if (rest.isNotEmpty) rows[rows.length - 1] = '${rows.last}$ellipsis';
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, row) in rows.indexed)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  row,
                  key: ValueKey('rail-house-line-$i'),
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.center,
                  style: style,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A group: its icon and title open its entries (and sub-groups) beside
/// the rail.
class _RailGroup extends StatelessWidget {
  const _RailGroup({required this.group, required this.path});

  final NavGroup group;
  final String path;

  bool _active(NavGroup g) =>
      groupIsCurrent(g.id, g.entries, path) || g.sub.any(_active);

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
    style: const MenuStyle(alignment: AlignmentDirectional.topEnd),
    menuChildren: _children(group),
    builder: (context, controller, _) => _RailItem(
      key: ValueKey('rail-group-${group.id}'),
      icon: Icon(group.icon),
      label: group.title,
      selected: _active(group),
      onTap: () => controller.isOpen ? controller.close() : controller.open(),
    ),
  );
}
