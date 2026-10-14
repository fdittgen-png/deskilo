// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2493 — the shell's destinations as data: the title of every branch and
// the bar destination (icon, selected icon, label, badge) of each one. They
// were closures inside ShellScreen.build.

import 'package:flutter/material.dart';

import '../../core/l10n/lexicon.dart';
import '../../l10n/app_localizations.dart';
import 'shell_bottom_bar.dart';
import 'shell_destinations.dart';

/// A destination icon — Messages (#687), and Calendar when it carries the
/// decisions (#1306) — badged only when there is something to badge. The count comes from the SAME query the list renders,
/// so the badge cannot disagree with the screen it points at.
Widget _badgedIcon(IconData icon, int count) => count > 0
    ? Badge.count(count: count, maxCount: 99, child: Icon(icon))
    : Icon(icon);

/// The title of every branch, indexed by [ShellBranch].
List<String> shellTabTitles(BuildContext context, AppLocalizations l10n) => [
  // #687 — the first destination is Messages now; the plan lives on
  // Réserver, which draws the same canvas.
  // Discussions moved to Me › Messages: this destination is the
  // workspace's alerts.
  l10n.inboxAlertsTab,
  lexiconText(context, key: 'tabCalendar', fallback: l10n.tabCalendar),
  lexiconText(context, key: 'directoryTitle', fallback: l10n.directoryTitle),
  lexiconText(context, key: 'tabMoney', fallback: l10n.tabMoney),
  // The centre button's branch (#reserve-as-branch): not a bar
  // destination, but it owns the app-bar title while active.
  lexiconText(
    context,
    key: 'shellReserveButton',
    fallback: l10n.shellReserveButton,
  ),
];

/// The bar destination of [branch], with the badge counts the shell watches.
ShellDestination shellDestinationFor(
  int branch, {
  required List<String> tabTitles,
  required int calendarBadge,
  required int moneyBadge,
  required int unreadMessages,
}) => switch (branch) {
  // #1306 S2 — with the bell off, the pending decisions badge the
  // Calendar, which opens on them.
  ShellBranch.calendar => ShellDestination(
    icon: _badgedIcon(shellBranchIcon(branch), calendarBadge),
    selectedIcon: _badgedIcon(
      shellBranchIcon(branch, selected: true),
      calendarBadge,
    ),
    label: tabTitles[ShellBranch.calendar],
  ),
  ShellBranch.directory => ShellDestination(
    icon: Icon(shellBranchIcon(branch)),
    selectedIcon: Icon(shellBranchIcon(branch, selected: true)),
    label: tabTitles[ShellBranch.directory],
  ),
  ShellBranch.money => ShellDestination(
    icon: _badgedIcon(shellBranchIcon(branch), moneyBadge),
    selectedIcon: _badgedIcon(
      shellBranchIcon(branch, selected: true),
      moneyBadge,
    ),
    label: tabTitles[ShellBranch.money],
  ),
  // #687 — the messaging centre, carrying its own unread count.
  // The count comes from the SAME query the list renders, so the
  // badge cannot disagree with the screen it points at.
  // No unread, NO BADGE WIDGET — not a hidden one. An
  // always-present badge with isLabelVisible:false renders
  // nothing and still answers find.byType(Badge), which is a
  // widget in the tree lying about an empty inbox.
  _ => ShellDestination(
    icon: _badgedIcon(shellBranchIcon(branch), unreadMessages),
    selectedIcon: _badgedIcon(
      shellBranchIcon(branch, selected: true),
      unreadMessages,
    ),
    label: tabTitles[ShellBranch.messages],
  ),
};
