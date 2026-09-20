// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../features/workspace/domain/workspace_feature.dart';

/// Branch indices of the stateful shell (order = bottom-bar order).
///
/// The integers never move: `StatefulShellRoute` keeps each branch's state
/// by index, so renumbering would hand one destination another's history.
/// #1306 — the names say what the branches ARE today; `plan` rendered the
/// Messages destination since #687 moved the plan to the Reserve hub.
abstract final class ShellBranch {
  /// The messaging centre (#687). Core: never feature-gated.
  static const int messages = 0;
  static const int calendar = 1;

  /// The member directory (#230).
  static const int directory = 2;
  static const int money = 3;

  /// The raised centre button's branch — not a bar destination, but a
  /// branch so the bar stays visible and functional on the hub. Core
  /// like Messages: never feature-gated, active by default.
  static const int reserve = 4;
}

/// #1306 — THE list of bar destinations for a workspace's features, in bar
/// order. The bottom bar and the web drawer both render this one list, so
/// they cannot drift apart, and no feature combination can produce a
/// duplicate or an empty slot. The Reserve hub is the centre button, not a
/// bar destination, and is never in the list.
List<int> visibleShellBranches(Set<WorkspaceFeature> features) => [
      ShellBranch.messages,
      if (features.contains(WorkspaceFeature.calendarTab)) ShellBranch.calendar,
      // #707 — Members left of Finances (owner's call): a roster you
      // consult, not a thing that arrives.
      if (features.contains(WorkspaceFeature.membersDirectory))
        ShellBranch.directory,
      if (features.contains(WorkspaceFeature.moneyTab)) ShellBranch.money,
    ];

/// The icon a destination shows, outlined or filled when [selected] — one
/// table for the bar and the drawer.
IconData shellBranchIcon(int branch, {bool selected = false}) =>
    switch (branch) {
      ShellBranch.calendar =>
        selected ? Icons.calendar_month : Icons.calendar_month_outlined,
      ShellBranch.directory => selected ? Icons.people : Icons.people_outline,
      ShellBranch.money => selected
          ? Icons.account_balance_wallet
          : Icons.account_balance_wallet_outlined,
      ShellBranch.reserve =>
        selected ? Icons.event_seat : Icons.event_seat_outlined,
      _ => selected ? Icons.forum : Icons.forum_outlined,
    };

/// #1306 S2 — where a pending decision is signalled.
///
/// The events bell carries it while `eventsTab` is on. A workspace that
/// switches the bell off — the association's profile does, to calm the
/// menu — would otherwise have NO path to a decision at all. When the
/// Calendar destination shows decisions on its timeline
/// (`calendarValidations`, which needs the calendar hub), the pending count
/// moves there instead: the Calendar badge counts them and the calendar
/// opens on them. One home, never also a banner. [effective] is the
/// workspace's effective feature set, so a stored child under a switched-
/// off parent does not claim the signal.
bool decisionSignalOnCalendar(Set<WorkspaceFeature> effective) =>
    !effective.contains(WorkspaceFeature.eventsTab) &&
    effective.contains(WorkspaceFeature.calendarTab) &&
    effective.contains(WorkspaceFeature.calendarValidations);
