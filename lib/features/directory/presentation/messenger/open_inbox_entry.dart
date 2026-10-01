// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/trace/trace_logger.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/presentation/widgets/conversation_thread.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/messenger.dart';
import '../../providers/directory_providers.dart';
import '../../providers/messenger_providers.dart';
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
  if (entry.kind == MessageContextKind.space &&
      !entry.isRemote &&
      entry.workspaceId != null &&
      entry.workspaceId == current) {
    await showConversationThread(context, ref, conversationId: entry.contextId);
  } else {
    final l10n = AppLocalizations.of(context);
    final servers = ref.read(serverLabelsProvider).value ?? const {};
    final peer = entry.peerId ?? await _peerOf(ref, entry);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ContextThreadScreen(
          kind: entry.kind,
          contextId: entry.contextId,
          title: entry.title,
          subtitle: contextSubtitle(l10n, entry, servers),
          source: entry.source,
          peer: peer,
        ),
      ),
    );
  }
  ref.invalidate(unifiedInboxProvider);
}

/// The other person of an account conversation, for a server whose inbox
/// rows do not name them: the account conversation list does.
Future<String?> _peerOf(WidgetRef ref, InboxEntry entry) async {
  if (entry.kind != MessageContextKind.account) return null;
  try {
    final rows = await ref.read(
      accountConversationsProvider(source: entry.source).future,
    );
    return rows
        .where((r) => r['id'] == entry.contextId)
        .map((r) => r['recipient'] as String?)
        .firstOrNull;
  } catch (e, st) {
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
