// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2493 — the actions of the shell's app bar: scan a space, open the editor,
// the inbox shortcut with its count, the account or settings door and the
// way back to Me. They were 75 lines of ShellScreen.build.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/context_l10n.dart';
import '../../core/l10n/lexicon.dart';
import '../../core/ui/kit/row_menu.dart';
import '../../features/events/providers/attention_providers.dart';
import '../../features/reservations/presentation/widgets/space_scan.dart';
import '../../features/workspace/domain/workspace_feature.dart';
import '../../features/workspace/domain/workspace_permission.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import 'shell_destinations.dart';
import 'space_chip.dart';

/// One control of the shell's top bar: its button, and the menu entry it
/// becomes when the bar is too narrow to hold it.
@immutable
class ShellBarControl {
  const ShellBarControl({
    required this.id,
    required this.rank,
    required this.button,
    this.entry,
  });

  /// The button's key.
  final String id;

  /// How often a person needs it: 0 first. The controls with the highest
  /// rank leave the bar first.
  final int rank;
  final Widget button;

  /// The entry behind the overflow button, with the button's own label;
  /// null for a control that never leaves the bar (the inbox, the account).
  final RowAction? entry;
}

/// The order of priority of the bar's controls, most needed first: the
/// inbox and the way back to the account never leave the bar; the settings
/// door is opened daily; a space is scanned on site; the editor is a tool
/// of the few who draw the plan.
enum _ShellBarRank { inbox, account, settings, scan, editor }

/// The app bar's actions for the branch at [currentIndex], every one a
/// button: the desk's bar, which has the room for all of them.
List<Widget> shellBarActions(
  BuildContext context,
  WidgetRef ref, {
  required int currentIndex,
}) => [
  for (final control in shellBarControls(
    context,
    ref,
    currentIndex: currentIndex,
  ))
    control.button,
];

/// The bar's controls for the branch at [currentIndex], in the order the
/// bar shows them.
List<ShellBarControl> shellBarControls(
  BuildContext context,
  WidgetRef ref, {
  required int currentIndex,
}) {
  final l10n = context.l10n;
  final features = ref.watch(enabledFeaturesSyncProvider);
  final attention = ref.watch(workspaceAttentionProvider);
  final isOwner = ref.watch(myMemberProvider).value?.actsAsOwner ?? false;
  // #1598 — a member who administers nothing meets My account where the
  // gear was. WATCHED, not read: a delegation or a workspace switch
  // must rename the entry on the same frame the permissions change,
  // never leave a stale one behind.
  final accountMenu = showsMemberAccountMenu(
    features: features,
    permissions: ref.watch(myPermissionsProvider),
  );
  ShellBarControl leaving({
    required String id,
    required _ShellBarRank rank,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) => ShellBarControl(
    id: id,
    rank: rank.index,
    button: IconButton(
      key: ValueKey(id),
      icon: Icon(icon),
      tooltip: label,
      onPressed: onPressed,
    ),
    entry: RowAction(id: id, label: label, icon: icon, onSelected: onPressed),
  );
  final settingsLabel = accountMenu
      ? l10n.memberAccountTitle
      : l10n.settingsTitle;
  return [
    // The editor sits on BOTH map surfaces (field request). Plan
    // and Réserver draw the same canvas from the same providers,
    // so an owner who spots a wrong desk while booking had to
    // leave the hub, switch tab and come back — for the same fix
    // they could make where they saw the problem.
    // #687 — Réserver is the only map surface now, so the editor
    // sits there and nowhere else.
    // Space QR scan (field request): a desk/office/level card opens
    // that space's permitted actions.
    //
    // #699 — it used to sit in the hub's control rows, where it
    // cost the width that pushed the window chips onto a third
    // line. It reads better here anyway: scanning a card is an
    // action ON the whole surface, like opening the editor beside
    // it, not a control that changes what the plan below shows.
    if (currentIndex == ShellBranch.reserve &&
        features.contains(WorkspaceFeature.spaceQrCodes))
      leaving(
        id: 'reserve-scan-button',
        rank: _ShellBarRank.scan,
        icon: Icons.qr_code_scanner_outlined,
        label: l10n.spaceScanTitle,
        onPressed: () => scanSpace(context, ref),
      ),
    // #2137 — the owner, and whoever holds manageSites.
    if ((isOwner ||
            ref
                .watch(myPermissionsProvider)
                .contains(WorkspacePermission.manageSites)) &&
        currentIndex == ShellBranch.reserve)
      leaving(
        id: 'shell-editor-button',
        rank: _ShellBarRank.editor,
        icon: Icons.design_services_outlined,
        label: l10n.editorOpenTooltip,
        onPressed: () => context.push('/editor'),
      ),
    // #707 — the bell is back, as a SHORTCUT: it opens the inbox
    // on its Événements face rather than a screen of its own. That
    // keeps the #687 rule intact — one place holds the alerts, so
    // reading one there is reading it everywhere — while the count
    // stays visible from every tab, which a tab inside the inbox
    // could not offer. Hidden when the workspace gated events off.
    // #719 → the GDPR rights moved to Me › Me with the rest of the
    // person's own pages (#1823); the avatar below is one tap away.
    if (features.contains(WorkspaceFeature.eventsTab))
      ShellBarControl(
        id: 'shell-events-bell',
        rank: _ShellBarRank.inbox.index,
        button: IconButton(
          key: const ValueKey('shell-events-bell'),
          icon: attention.total == 0
              ? const Icon(Icons.inbox_outlined)
              : Badge.count(
                  count: attention.total,
                  maxCount: 99,
                  child: const Icon(Icons.inbox_outlined),
                ),
          tooltip:
              '${lexiconText(context, key: 'tabEvents', fallback: l10n.tabEvents)} — ${l10n.uxAttentionSummary(attention.updates, attention.pending)}',
          // The /events path lands on the alerts (the calendar's Alerts
          // view when the hub holds them).
          onPressed: () => context.go('/events'),
        ),
      ),
    // #1598 — the SAME destination under two names. Hiding an
    // entry is not access control: /settings already shows a
    // member only what their permissions earn, and every
    // administrative route behind it keeps its own guard, so what
    // changes here is the word and the icon on the door.
    leaving(
      id: accountMenu ? 'shell-account-button' : 'shell-settings-button',
      rank: _ShellBarRank.settings,
      icon: accountMenu ? Icons.account_circle_outlined : Icons.settings_outlined,
      label: settingsLabel,
      onPressed: () => context.push('/settings'),
    ),
    ShellBarControl(
      id: 'shell-back-to-me',
      rank: _ShellBarRank.account.index,
      button: const BackToMeButton(), // #1823
    ),
  ];
}
