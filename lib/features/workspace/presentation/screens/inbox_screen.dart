// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../events/presentation/screens/events_screen.dart';
import '../../domain/workspace_feature.dart';
import '../../../events/providers/event_providers.dart';
import '../../providers/conversation_providers.dart';
import '../../providers/workspace_providers.dart';
import '../../../directory/presentation/messenger/space_inquiries_screen.dart';
import '../widgets/application_requests_entry.dart';

part 'inbox_screen.g.dart';

/// The two faces of the inbox (#702; Members left again in #707 for
/// its own bottom-bar destination — a roster is consulted, not
/// received, and an inbox tab put it behind the wrong door).
enum InboxTab { chats, alerts }

/// Which face is showing — a provider rather than local state so a deep
/// link (a notification tap, `/events`, "see who is in today") can put
/// the inbox on the right tab before it is built.
///
/// KeepAlive, like [PlanFocusController] and for the same reason: the
/// inbox lives in the shell's indexed stack, so a request made from
/// another tab has to survive until the switch delivers it.
@Riverpod(keepAlive: true)
class InboxTabController extends _$InboxTabController {
  @override
  InboxTab build() => InboxTab.chats;

  void show(InboxTab tab) => state = tab;
}

/// THE INBOX (#702) — everything addressed to you, in one place:
/// conversations and workspace alerts.
///
/// They were two destinations answering the same question — "is there
/// anything for me?" — from two corners of the app: the Messages tab and
/// the app-bar bell. ONE HOME EACH is the rule this inherits from #687:
/// a thing that lives in two places is a thing you can mark read in one
/// and still see unread in the other. The bell survives (#707) as a
/// SHORTCUT onto the Événements face — same tab, same read state — so
/// the pending count stays visible from every screen without the alerts
/// living anywhere else.
///
/// GATED, NOT INVENTED. Alerts ride the existing `eventsTab` feature,
/// exactly as the bell does. A workspace that turned it off sees no tab
/// bar at all, because a one-tab bar is chrome that says nothing.
///
/// An [IndexedStack], not a [TabBarView]: each face keeps its scroll
/// position, its filter chips and its search box while you look at
/// another, and no second horizontal [Scrollable] lands over lists that
/// tests and users already scroll vertically.
class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final features = ref.watch(enabledFeaturesSyncProvider);
    final alerts = features.contains(WorkspaceFeature.eventsTab);
    // Discussions live in the messenger of the Me space; this destination
    // keeps what belongs to the workspace itself: its alerts, the requests
    // addressed to it, and one door to the messenger.
    return Scaffold(
      body: Column(
        children: [
          _TopRow(alerts: alerts),
          if (alerts) const Expanded(child: EventsScreen()) else const Spacer(),
        ],
      ),
    );
  }
}

/// The face's title, with the count of what waits for a decision.
class _AlertsHeader extends ConsumerWidget {
  const _AlertsHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final features = ref.watch(enabledFeaturesSyncProvider);
    final pending = ref.watch(myPendingEventCountProvider).value ?? 0;
    final label = features.contains(WorkspaceFeature.messagesHub)
        ? (l10n?.inboxAlertsTab ?? 'Alerts')
        : (l10n?.tabEvents ?? 'Events');
    return Padding(
      key: const ValueKey('inbox-tab-alerts'),
      padding: const EdgeInsets.fromLTRB(8, 0, 12, 0),
      child: Row(
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          if (pending > 0) ...[
            const SizedBox(width: 8),
            Badge.count(count: pending),
          ],
        ],
      ),
    );
  }
}

/// One door from the workspace to the messenger (Me › Messages), with the
/// unread count, plus the requests addressed to this workspace.
class _TopRow extends ConsumerWidget {
  const _TopRow({required this.alerts});

  final bool alerts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final unread = ref.watch(unreadMessagesProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Wrap(
        spacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (alerts) const _AlertsHeader(),
          TextButton.icon(
            key: const ValueKey('inbox-messenger-door'),
            onPressed: () => context.go('/me?tab=messages'),
            icon: unread > 0
                ? Badge.count(
                    count: unread,
                    child: const Icon(Icons.forum_outlined),
                  )
                : const Icon(Icons.forum_outlined),
            label: Text(l10n?.inboxMessengerDoor ?? 'Open my messenger'),
          ),
          const ApplicationRequestsEntry(compact: false),
          const SpaceInquiriesEntry(),
        ],
      ),
    );
  }
}

/// Opens the inbox on [tab] from anywhere (a notification tap, a link,
/// the `/events` path that used to be its own screen).
void openInbox(WidgetRef ref, InboxTab tab) =>
    ref.read(inboxTabControllerProvider.notifier).show(tab);
