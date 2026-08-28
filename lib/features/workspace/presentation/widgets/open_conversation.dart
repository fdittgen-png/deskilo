// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/trace/guarded.dart';
import '../../../../l10n/app_localizations.dart';
import '../../providers/conversation_providers.dart';
import '../../providers/workspace_providers.dart';
import 'conversation_thread.dart';

/// Opens the conversation with one member — from anywhere (#702).
///
/// THE ONE WAY IN. Until now there were two threads with the same job:
/// the messaging centre opened [ConversationThread] by conversation id,
/// while the directory, a member sheet, an event row and a blocked
/// booking all opened the older sheet, which reconstructed a 1:1 thread
/// by FILTERING every note the viewer could see.
///
/// That was not only duplicated UI. The two marked READ by different
/// mechanisms — one stamped the notes, the other the participant row —
/// so a conversation read from a member's profile stayed bold in the
/// inbox, with its unread badge intact. Reading something in one place
/// and still being told about it in another is exactly the bug that
/// moved messages out of the bell in the first place.
///
/// Resolving the id costs one round trip (`direct_conversation` creates
/// the thread on first use and returns the existing one after), which is
/// why the caller gets a spinner-free guarded call rather than an
/// optimistic open: a thread that opens empty because its id has not
/// arrived yet looks like lost messages.
Future<void> openDirectConversation(
  BuildContext context,
  WidgetRef ref, {
  required String memberId,
  String? seedBody,
}) async {
  final l10n = AppLocalizations.of(context);
  final workspace = ref.read(currentWorkspaceProvider).value;
  if (workspace == null) return;
  String? conversationId;
  final ok = await runGuarded(
    context,
    domain: 'workspace',
    message: 'open direct conversation failed',
    errorText: l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
    action: () async {
      conversationId = await ref
          .read(workspaceRepositoryProvider)
          .openDirectConversation(workspace.id, otherMemberId: memberId);
    },
  );
  if (!ok || conversationId == null || !context.mounted) return;
  // A conversation that did not exist a moment ago is not in the cached
  // list, and the thread reads its title and kind from there.
  ref.invalidate(conversationsProvider);
  await showConversationThread(
    context,
    ref,
    conversationId: conversationId!,
    seedBody: seedBody,
  );
}
