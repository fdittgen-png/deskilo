// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../features/workspace/domain/workspace_feature.dart';
import '../../features/workspace/domain/workspace_permission.dart';
import 'shell_branch.dart';

export 'shell_branch.dart';

/// #1306 — THE list of bar destinations for a workspace's features, in bar
/// order. The bottom bar and the web drawer both render this one list, so
/// they cannot drift apart, and no feature combination can produce a
/// duplicate or an empty slot. The Reserve hub is the centre button, not a
/// bar destination, and is never in the list.
/// The calendar hub is where alerts and events live (they were the Messages
/// destination): with it on, that destination leaves the bar and its path
/// opens the calendar. [effective] is the workspace's effective feature set.
bool calendarHoldsAlerts(Set<WorkspaceFeature> effective) =>
    effective.contains(WorkspaceFeature.calendarTab) &&
    effective.contains(WorkspaceFeature.calendarHub) &&
    // Nothing to merge while the alerts are switched off: the Messages
    // destination stays, as the door to the messenger.
    effective.contains(WorkspaceFeature.eventsTab);

@visibleForTesting
List<int> visibleShellBranches(
  Set<WorkspaceFeature> features,
  Set<WorkspacePermission> permissions,
) =>
    [
      if (permissions.contains(WorkspacePermission.useMessages) &&
          !(calendarHoldsAlerts(features) &&
              permissions.contains(WorkspacePermission.viewCalendar)))
        ShellBranch.messages,
      if (features.contains(WorkspaceFeature.calendarTab) &&
          permissions.contains(WorkspacePermission.viewCalendar))
        ShellBranch.calendar,
      // #707 — Members left of Finances (owner's call): a roster you
      // consult, not a thing that arrives.
      if (features.contains(WorkspaceFeature.membersDirectory) &&
          permissions.contains(WorkspacePermission.viewDirectory))
        ShellBranch.directory,
      if (features.contains(WorkspaceFeature.moneyTab) &&
          (permissions.contains(WorkspacePermission.viewMyMoney) ||
              permissions.contains(WorkspacePermission.viewFinances) ||
              permissions.contains(WorkspacePermission.issueInvoices) ||
              permissions.contains(WorkspacePermission.manageBilling)))
        ShellBranch.money,
    ];

/// #3551 — one destination of the bar and the menu: the branch that holds
/// it and, where a branch holds two destinations, the location it opens and
/// the paths it is selected on. Branch 0 holds both the overview and the
/// messages of a business without places; each is selected by its location.
class ShellNav {
  const ShellNav(this.id, this.branch, {this.location});

  /// Stable id: `overview`, `messages`, `calendar`, `directory`, `money`.
  final String id;
  final int branch;

  /// The location a destination of a shared branch opens; null for a
  /// destination that is its whole branch (opened with `goBranch`).
  final String? location;

  /// Whether this destination is the one on screen.
  bool selectedAt({required int branch, required String path}) =>
      location == null ? this.branch == branch : path.startsWith(location!);
}

const _branchIds = {
  ShellBranch.messages: 'messages',
  ShellBranch.calendar: 'calendar',
  ShellBranch.directory: 'directory',
  ShellBranch.money: 'money',
};

/// #3551 — THE destinations, in bar order. A business that books places
/// keeps exactly the branch list of [visibleShellBranches]. One that books
/// none leads with what it works with: Overview, Clients, Invoices,
/// Messages, then the Calendar; Services stay inside Invoices (Sales).
List<ShellNav> shellNavFor(
  Set<WorkspaceFeature> features,
  Set<WorkspacePermission> permissions,
) {
  final branches = visibleShellBranches(features, permissions);
  if (features.contains(WorkspaceFeature.placeBooking)) {
    return [for (final b in branches) ShellNav(_branchIds[b]!, b)];
  }
  return [
    if (features.contains(WorkspaceFeature.workspaceOverview))
      const ShellNav(
        'overview',
        ShellBranch.messages,
        location: '/workspace-overview',
      ),
    if (branches.contains(ShellBranch.directory))
      const ShellNav('directory', ShellBranch.directory),
    if (branches.contains(ShellBranch.money))
      const ShellNav('money', ShellBranch.money),
    if (branches.contains(ShellBranch.messages))
      const ShellNav('messages', ShellBranch.messages, location: '/messages'),
    if (branches.contains(ShellBranch.calendar))
      const ShellNav('calendar', ShellBranch.calendar),
  ];
}

/// #3551 — what the raised centre button does.
enum ShellCenterAction { reserve, newInvoice, none }

/// The centre action: the booking where places are booked (for someone who
/// may book, or while the membership is not known yet); without places, a
/// new invoice where invoicing is on and the member may issue; else none.
ShellCenterAction shellCenterActionFor(
  Set<WorkspaceFeature> features,
  Set<WorkspacePermission> permissions, {
  bool membershipKnown = true,
}) {
  if (features.contains(WorkspaceFeature.placeBooking)) {
    return !membershipKnown ||
            permissions.contains(WorkspacePermission.makeReservations)
        ? ShellCenterAction.reserve
        : ShellCenterAction.none;
  }
  return features.contains(WorkspaceFeature.invoicing) &&
          features.contains(WorkspaceFeature.moneyTab) &&
          permissions.contains(WorkspacePermission.issueInvoices)
      ? ShellCenterAction.newInvoice
      : ShellCenterAction.none;
}

/// #3551 — where a workspace opens when nothing more specific was asked for:
/// the floor plan of a business that books places; the overview (what needs
/// the person, then the figures) of one that books none — a practice, a
/// studio, a salon; the inbox when the overview is switched off too.
String landingRouteFor(Set<WorkspaceFeature> features) =>
    features.contains(WorkspaceFeature.placeBooking)
        ? '/reserve'
        : features.contains(WorkspaceFeature.workspaceOverview)
        ? '/workspace-overview'
        : '/messages';

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
    // The calendar holds the alerts now: it carries the pending count
    // whether or not the bell shortcut is on.
    calendarHoldsAlerts(effective) ||
    (!effective.contains(WorkspaceFeature.eventsTab) &&
        effective.contains(WorkspaceFeature.calendarTab) &&
        effective.contains(WorkspaceFeature.calendarValidations));
