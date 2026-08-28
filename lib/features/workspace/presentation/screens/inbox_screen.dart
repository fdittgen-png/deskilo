// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/motion/motion.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/presentation/screens/events_screen.dart';
import '../../../events/providers/event_providers.dart';
import '../../../members/presentation/screens/directory_screen.dart';
import '../../domain/workspace_feature.dart';
import '../../providers/conversation_providers.dart';
import '../../providers/workspace_providers.dart';
import 'messages_screen.dart';

part 'inbox_screen.g.dart';

/// The three faces of the inbox (#702).
enum InboxTab { chats, alerts, members }

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
/// conversations, workspace alerts, and the people both are about.
///
/// WHY THESE THREE TOGETHER. They were three destinations that all
/// answered the same question — "what is happening with the people
/// here?" — from three different corners of the app: the Messages tab,
/// the app-bar bell, and the Members tab. Reaching a person from an
/// alert, or an alert about the person you were just messaging, meant
/// leaving one surface for another and losing your place in both.
///
/// ONE HOME EACH is the rule this inherits from #687: a thing that lives
/// in two places is a thing you can mark read in one and still see
/// unread in the other. So the bell is gone from the app bar and the
/// Members tab is gone from the bottom bar — not duplicated here.
///
/// GATED, NOT INVENTED. Alerts ride the existing `eventsTab` feature and
/// Members the existing `membersDirectory` one, exactly as the bell and
/// the tab did. A workspace that turned either off sees the tab bar
/// shrink; with only Chats left there is no tab bar at all, because a
/// one-tab bar is chrome that says nothing.
///
/// An [IndexedStack], not a [TabBarView]: each face keeps its scroll
/// position, its filter chips and its search box while you look at
/// another, and no second horizontal [Scrollable] lands over lists that
/// tests and users already scroll vertically.
class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen>
    with SingleTickerProviderStateMixin {
  TabController? _controller;

  /// The tabs the current workspace actually shows, in display order.
  List<InboxTab> _tabsFor(Set<WorkspaceFeature> features) => [
        InboxTab.chats,
        if (features.contains(WorkspaceFeature.eventsTab)) InboxTab.alerts,
        if (features.contains(WorkspaceFeature.membersDirectory))
          InboxTab.members,
      ];

  void _syncController(List<InboxTab> tabs, InboxTab selected) {
    final index = tabs.indexOf(selected).clamp(0, tabs.length - 1);
    if (_controller?.length != tabs.length) {
      _controller?.dispose();
      _controller = TabController(
        length: tabs.length,
        initialIndex: index,
        vsync: this,
      )..addListener(() {
          final c = _controller!;
          if (c.indexIsChanging) return;
          final tab = tabs[c.index];
          if (ref.read(inboxTabControllerProvider) != tab) {
            ref.read(inboxTabControllerProvider.notifier).show(tab);
          }
        });
    } else if (_controller!.index != index) {
      _controller!.index = index;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final features = ref.watch(enabledFeaturesSyncProvider);
    final tabs = _tabsFor(features);
    // A tab the workspace no longer shows falls back to Chats, which is
    // the one tab that is always there.
    final requested = ref.watch(inboxTabControllerProvider);
    final selected = tabs.contains(requested) ? requested : InboxTab.chats;
    _syncController(tabs, selected);

    final unread = ref.watch(unreadMessagesProvider);
    final pending = ref.watch(myPendingEventCountProvider).value ?? 0;

    return Scaffold(
      // No title: the shell's app bar above already names the
      // destination. This slim bar carries the tabs and whatever the
      // showing face needs — the actions belong to the tab, not to the
      // screen, so they swap with it.
      appBar: tabs.length < 2
          ? null
          : AppBar(
              toolbarHeight: 0,
              bottom: TabBar(
                key: const ValueKey('inbox-tabs'),
                controller: _controller,
                tabs: [
                  for (final tab in tabs)
                    Tab(
                      key: ValueKey('inbox-tab-${tab.name}'),
                      child: _TabLabel(
                        label: switch (tab) {
                          InboxTab.chats =>
                            l10n?.inboxChatsTab ?? 'Chats',
                          InboxTab.alerts => l10n?.tabEvents ?? 'Events',
                          InboxTab.members =>
                            l10n?.directoryTitle ?? 'Members',
                        },
                        // The count each face is responsible for, on the
                        // face itself: an inbox that only badges its
                        // total makes you open all three to find the one
                        // with something in it.
                        count: switch (tab) {
                          InboxTab.chats => unread,
                          InboxTab.alerts => pending,
                          InboxTab.members => 0,
                        },
                      ),
                    ),
                ],
              ),
            ),
      // #611's shell idiom: the stack keeps every face alive, an
      // opacity layer above it fades the swap.
      body: FadeInOnChange(
        changeKey: selected,
        child: IndexedStack(
        index: tabs.indexOf(selected),
        children: [
          for (final tab in tabs)
            switch (tab) {
              InboxTab.chats => const MessagesScreen(),
              InboxTab.alerts => const EventsScreen(),
              InboxTab.members => const DirectoryScreen(),
            },
        ],
        ),
      ),
    );
  }
}

/// A tab label with the count its face is carrying, or none at all.
///
/// No count, NO BADGE WIDGET — the #687 rule: an always-present badge
/// with `isLabelVisible: false` renders nothing and still answers
/// `find.byType(Badge)`, which is a widget in the tree lying about an
/// empty inbox.
class _TabLabel extends StatelessWidget {
  const _TabLabel({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final text = Text(label, overflow: TextOverflow.ellipsis);
    if (count <= 0) return text;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Flexible(child: text),
      const SizedBox(width: 6),
      Badge.count(count: count),
    ]);
  }
}

/// Opens the inbox on [tab] from anywhere (a notification tap, a link,
/// the `/events` path that used to be its own screen).
void openInbox(WidgetRef ref, InboxTab tab) =>
    ref.read(inboxTabControllerProvider.notifier).show(tab);
