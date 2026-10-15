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
import '../../features/events/providers/attention_providers.dart';
import '../../features/reservations/presentation/widgets/space_scan.dart';
import '../../features/workspace/domain/workspace_feature.dart';
import '../../features/workspace/domain/workspace_permission.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import 'shell_destinations.dart';
import 'space_chip.dart';

/// The app bar's actions for the branch at [currentIndex].
List<Widget> shellBarActions(
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
      IconButton(
        key: const ValueKey('reserve-scan-button'),
        icon: const Icon(Icons.qr_code_scanner_outlined),
        tooltip: l10n.spaceScanTitle,
        onPressed: () => scanSpace(context, ref),
      ),
    // #2137 — the owner, and whoever holds manageSites.
    if ((isOwner ||
            ref
                .watch(myPermissionsProvider)
                .contains(WorkspacePermission.manageSites)) &&
        currentIndex == ShellBranch.reserve)
      IconButton(
        key: const ValueKey('shell-editor-button'),
        icon: const Icon(Icons.design_services_outlined),
        tooltip: l10n.editorOpenTooltip,
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
      IconButton(
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
    // #1598 — the SAME destination under two names. Hiding an
    // entry is not access control: /settings already shows a
    // member only what their permissions earn, and every
    // administrative route behind it keeps its own guard, so what
    // changes here is the word and the icon on the door.
    IconButton(
      key: ValueKey(
        accountMenu ? 'shell-account-button' : 'shell-settings-button',
      ),
      icon: Icon(
        accountMenu ? Icons.account_circle_outlined : Icons.settings_outlined,
      ),
      tooltip: accountMenu ? (l10n.memberAccountTitle) : (l10n.settingsTitle),
      onPressed: () => context.push('/settings'),
    ),
    const BackToMeButton(), // #1823
  ];
}
