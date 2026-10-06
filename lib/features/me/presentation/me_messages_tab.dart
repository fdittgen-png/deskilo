// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../directory/presentation/messenger/message_requests_card.dart';
import '../../directory/presentation/messenger/unified_inbox_view.dart';

/// Me › Messages (#1823, #1824): the unified inbox — every conversation
/// the person takes part in, on every server, labelled by its context.
class MeMessagesTab extends StatelessWidget {
  const MeMessagesTab({super.key});

  @override
  Widget build(BuildContext context) => const Column(
    children: [
      MessageRequestsCard(),
      Expanded(child: UnifiedInboxView()),
    ],
  );
}
