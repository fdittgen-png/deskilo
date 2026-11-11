// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2211 — Me › Me › Blocked people: who I blocked on this server, and the way
// back. A block is mutual invisibility; the list is the only place it can be
// undone from.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/async_read_body.dart';
import '../../directory/providers/blocks_providers.dart';
import '../../directory/providers/messenger_providers.dart';

class BlockedPeopleCard extends ConsumerStatefulWidget {
  const BlockedPeopleCard({super.key});

  @override
  ConsumerState<BlockedPeopleCard> createState() => _BlockedPeopleCardState();
}

class _BlockedPeopleCardState extends ConsumerState<BlockedPeopleCard> {
  /// The people whose Unblock is running: a second tap does nothing (#3683).
  final _unblocking = <String>{};

  Future<void> _unblock(String userId) async {
    if (!_unblocking.add(userId)) return;
    setState(() {});
    try {
      final ok = await runGuarded(
        context,
        domain: 'messages',
        message: 'unblock failed',
        action: () =>
            ref.read(messengerActionsProvider()).unblockAccount(userId),
      );
      if (ok) ref.invalidate(myBlocksProvider(thisServerSource));
    } finally {
      _unblocking.remove(userId);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final read = ref.watch(myBlocksProvider(thisServerSource));
    // #3683 -- "you have not blocked anyone" is said only of a list that was
    // read; a failed or running read says nothing about who is blocked.
    final blocks = read.value ?? const [];
    return ExpansionTile(
      key: const ValueKey('me-blocked-people'),
      leading: const Icon(Icons.block_outlined),
      title: Text(l10n.blockedPeopleTitle),
      subtitle: read.hasValue
          ? Text(blocks.isEmpty ? l10n.blockedPeopleEmpty : '${blocks.length}')
          : null,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              l10n.blockedPeopleHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        if (!read.hasValue && read.hasError && !read.isLoading)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: ReadFailureBanner(
              error: read.error!,
              onRetry: () => ref.invalidate(myBlocksProvider(thisServerSource)),
            ),
          ),
        for (final b in blocks)
          ListTile(
            key: ValueKey('blocked-${b.userId}'),
            title: Text(b.name.isEmpty ? b.userId : b.name),
            trailing: TextButton(
              key: ValueKey('unblock-${b.userId}'),
              onPressed: _unblocking.contains(b.userId)
                  ? null
                  : () => _unblock(b.userId),
              child: Text(l10n.unblockAction),
            ),
          ),
      ],
    );
  }
}
