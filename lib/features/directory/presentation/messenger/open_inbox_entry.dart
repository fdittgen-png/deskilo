// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/backend/context_client_providers.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../workspace/presentation/widgets/conversation_thread.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/messenger.dart';
import '../../providers/directory_providers.dart';
import '../../providers/messenger_providers.dart';
import '../directory_pages.dart';
import 'context_labels.dart';
import 'context_thread_screen.dart';

/// #1824 — opens a conversation of the unified inbox where it reads
/// best: a space conversation of the space I am in opens the space's own
/// thread (names, quotes, references); everything else opens the
/// context thread, on the server it lives on.
Future<void> openInboxEntry(
  BuildContext context,
  WidgetRef ref,
  InboxEntry entry,
) async {
  final current = ref.read(currentWorkspaceProvider).value?.id;
  if (opensInWorkspaceThread(entry)) {
    // A conversation of one of my workspaces opens in that workspace's own
    // thread — names, quotes, references to reservations, spaces and
    // documents — so it works from the Me messenger exactly as it did in
    // the workspace. The workspace is selected for the time the thread is
    // open and the previous one restored after.
    final previous = await ref.read(activeWorkspaceIdProvider.future);
    // A workspace of a connected installation comes back on it (#2556).
    final host = ref.read(selectedWorkspaceHostProvider);
    final previousHost =
        host != null && host.workspaceId == previous ? host.source : null;
    if (entry.workspaceId != current || previousHost != null) {
      await ref.read(activeWorkspaceIdProvider.notifier).select(entry.workspaceId!);
      await ref.read(currentWorkspaceProvider.future);
    }
    if (!context.mounted) return;
    await showConversationThread(context, ref, conversationId: entry.contextId);
    final active = ref.read(activeWorkspaceIdProvider.notifier);
    if (previousHost != null) {
      active.activateConnected(previous!, previousHost);
    } else if (previous != null && previous != entry.workspaceId) {
      await active.select(previous);
    }
  } else {
    final l10n = context.l10n;
    final servers = ref.read(serverLabelsProvider).value ?? const {};
    final peer = entry.peerId ?? await inboxEntryPeer(ref, entry);
    if (!context.mounted) return;
    await contextThreadPage.open<void>(
      context,
      ContextThreadScreen(
        kind: entry.kind,
        contextId: entry.contextId,
        title: entry.title,
        subtitle: contextSubtitle(l10n, entry, servers),
        source: entry.source,
        peer: peer,
      ),
    );
  }
  ref.invalidate(messengerInboxProvider);
}

/// Whether [entry] is a conversation of one of my workspaces on this
/// server, which reads in that workspace's own thread rather than in the
/// context thread.
bool opensInWorkspaceThread(InboxEntry entry) =>
    entry.kind == MessageContextKind.space &&
    !entry.isRemote &&
    entry.workspaceId != null;

/// The other person of an account conversation, for a server whose inbox
/// rows do not name them: the account conversation list does.
Future<String?> inboxEntryPeer(WidgetRef ref, InboxEntry entry) async {
  if (entry.kind != MessageContextKind.account) return null;
  try {
    final rows = await ref.read(
      accountConversationsProvider(source: entry.source).future,
    );
    return rows
        .where((r) => r['id'] == entry.contextId)
        .map((r) => r['recipient'] as String?)
        .firstOrNull;
  } on Object catch (e, st) {
    // Without a peer the thread still reads; only a reply is refused.
    TraceLogger.instance.warn(
      'messages',
      'account peer lookup failed',
      error: e,
      stackTrace: st,
    );
    return null;
  }
}
