// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2211 — Me › Me › Blocked people: who I blocked on this server, and the way
// back. A block is mutual invisibility; the list is the only place it can be
// undone from.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/trace/guarded.dart';
import '../../../l10n/app_localizations.dart';
import '../../directory/providers/blocks_providers.dart';
import '../../directory/providers/messenger_providers.dart';

class BlockedPeopleCard extends ConsumerWidget {
  const BlockedPeopleCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final blocks = ref.watch(myBlocksProvider('')).value ?? const [];
    return ExpansionTile(
      key: const ValueKey('me-blocked-people'),
      leading: const Icon(Icons.block_outlined),
      title: Text(l10n?.blockedPeopleTitle ?? 'Blocked people'),
      subtitle: Text(blocks.isEmpty
          ? (l10n?.blockedPeopleEmpty ?? 'You have not blocked anyone.')
          : '${blocks.length}'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              l10n?.blockedPeopleHint ??
                  'A blocked person cannot see you or write to you, and you '
                      'cannot see or reach them.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        for (final b in blocks)
          ListTile(
            key: ValueKey('blocked-${b.userId}'),
            title: Text(b.name.isEmpty ? b.userId : b.name),
            trailing: TextButton(
              key: ValueKey('unblock-${b.userId}'),
              onPressed: () async {
                final ok = await runGuarded(
                  context,
                  domain: 'messages',
                  message: 'unblock failed',
                  action: () => ref
                      .read(messengerActionsProvider())
                      .unblockAccount(b.userId),
                );
                if (ok) ref.invalidate(myBlocksProvider(''));
              },
              child: Text(l10n?.unblockAction ?? 'Unblock'),
            ),
          ),
      ],
    );
  }
}
