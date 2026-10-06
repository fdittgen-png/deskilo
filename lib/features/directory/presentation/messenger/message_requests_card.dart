// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2211 — Me › Messages: the first messages from people outside my
// reachability wait here as requests. Accept turns one into a conversation,
// Ignore hides it without telling the sender, Block also ends all contact.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/trace/guarded.dart';
import '../../../../l10n/app_localizations.dart';
import '../../providers/blocks_providers.dart';
import '../../providers/messenger_providers.dart';
import 'block_person.dart';

class MessageRequestsCard extends ConsumerWidget {
  const MessageRequestsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final requests = ref.watch(messageRequestsProvider).value ?? const [];
    if (requests.isEmpty) return const SizedBox.shrink();

    Future<void> respond(String conversation, {required bool accept}) async {
      final ok = await runGuarded(
        context,
        domain: 'messages',
        message: 'message request answer failed',
        action: () => ref
            .read(messengerActionsProvider())
            .respondToMessageRequest(conversation, accept: accept),
      );
      if (!ok) return;
      ref.invalidate(messageRequestsProvider);
      ref.invalidate(unifiedInboxProvider);
    }

    return Card(
      key: const ValueKey('message-requests'),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n?.messageRequestsTitle ?? 'Message requests',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              l10n?.messageRequestsHint ??
                  'These people are outside the ones you chose to be '
                      'reachable by. They are not told what you decide.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            for (final r in requests) ...[
              const Divider(),
              Text(
                r.name.isEmpty ? r.userId : r.name,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(r.body, maxLines: 3, overflow: TextOverflow.ellipsis),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    key: ValueKey('request-accept-${r.conversationId}'),
                    onPressed: () => respond(r.conversationId, accept: true),
                    child: Text(l10n?.requestAccept ?? 'Accept'),
                  ),
                  OutlinedButton(
                    key: ValueKey('request-ignore-${r.conversationId}'),
                    onPressed: () => respond(r.conversationId, accept: false),
                    child: Text(l10n?.requestIgnore ?? 'Ignore'),
                  ),
                  TextButton(
                    key: ValueKey('request-block-${r.conversationId}'),
                    onPressed: () async {
                      final blocked = await confirmAndBlock(
                        context,
                        ref,
                        source: '',
                        peer: r.userId,
                        name: r.name.isEmpty ? r.userId : r.name,
                      );
                      if (blocked && context.mounted) {
                        await respond(r.conversationId, accept: false);
                      }
                    },
                    child: Text(l10n?.requestBlock ?? 'Block'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
