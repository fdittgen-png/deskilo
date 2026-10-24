// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../directory/domain/messenger.dart';
import '../../directory/presentation/messenger/conversation_link_following.dart';
import '../../directory/presentation/messenger/conversation_pane.dart';
import '../../directory/presentation/messenger/message_requests_card.dart';
import '../../directory/presentation/messenger/open_inbox_entry.dart';
import '../../directory/presentation/messenger/unified_inbox_view.dart';
import '../providers/personal_shell_providers.dart';

/// Me › Messages (#1823, #1824): the unified inbox — every conversation
/// the person takes part in, on every server, labelled by its context.
/// In the personal shell the inbox and the conversation it opens share
/// the page, laid out for its width (AdaptiveMessenger). In either shell
/// a [link] to one conversation opens it once its source authorizes it.
class MeMessagesTab extends ConsumerWidget {
  const MeMessagesTab({super.key, this.link});

  /// The route's `conversation` parameter (ConversationLink).
  final String? link;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(personalShellEnabledProvider)
          ? AdaptiveMessenger(link: link)
          : _LegacyMessages(link: link);
}

/// The inbox of the four-tab shell: a conversation opens on its own page,
/// also when a link names it — once its source lists it for the person.
class _LegacyMessages extends ConsumerStatefulWidget {
  const _LegacyMessages({this.link});
  final String? link;

  @override
  ConsumerState<_LegacyMessages> createState() => _LegacyMessagesState();
}

class _LegacyMessagesState extends ConsumerState<_LegacyMessages>
    with ConversationLinkFollowing {
  @override
  void initState() {
    super.initState();
    followLink(widget.link);
  }

  @override
  void didUpdateWidget(_LegacyMessages oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.link != oldWidget.link) followLink(widget.link);
  }

  @override
  void dispose() {
    stopFollowing();
    super.dispose();
  }

  @override
  void openAuthorized(InboxEntry entry) =>
      unawaited(openInboxEntry(context, ref, entry));

  @override
  Widget build(BuildContext context) => const Column(
    children: [
      MessageRequestsCard(),
      Expanded(child: UnifiedInboxView()),
    ],
  );
}
