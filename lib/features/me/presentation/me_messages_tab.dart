// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../directory/presentation/messenger/conversation_pane.dart';
import '../../directory/presentation/messenger/message_requests_card.dart';
import '../../directory/presentation/messenger/unified_inbox_view.dart';
import '../providers/personal_shell_providers.dart';

/// Me › Messages (#1823, #1824): the unified inbox — every conversation
/// the person takes part in, on every server, labelled by its context.
/// In the personal shell the inbox and the conversation it opens share
/// the page, laid out for its width (AdaptiveMessenger), and a [link] to
/// one conversation selects it once its source authorizes it.
class MeMessagesTab extends ConsumerWidget {
  const MeMessagesTab({super.key, this.link});

  /// The route's `conversation` parameter (ConversationLink).
  final String? link;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(personalShellEnabledProvider)
          ? AdaptiveMessenger(link: link)
          : const Column(
              children: [
                MessageRequestsCard(),
                Expanded(child: UnifiedInboxView()),
              ],
            );
}
