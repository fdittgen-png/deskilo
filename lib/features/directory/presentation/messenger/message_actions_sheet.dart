// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/time/clock.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/message_marks.dart';
import '../../domain/messenger.dart';
import '../../providers/messenger_providers.dart';
import '../../../workspace/domain/member_note_refs.dart';
import 'edit_message_dialog.dart';
import 'forward_target_sheet.dart';
import 'message_history_sheet.dart';
import 'refusal_text.dart';

/// The message an action sheet is about — whichever thread it sits in.
class MessageRef {
  const MessageRef({
    required this.kind,
    required this.messageId,
    required this.contextKind,
    required this.contextId,
    required this.mine,
    this.noForward = false,
    this.source = '',
    this.body = '',
    this.sentAt,
    this.isNotice = false,
    this.starred = false,
    this.myReaction,
  });

  final MessageKind kind;
  final String messageId;
  final MessageContextKind contextKind;
  final String contextId;
  final bool mine;
  final bool noForward;
  final String source;

  /// The words (for copy and edit), when it was sent (the edit window), and
  /// my current marks on it (0382).
  final String body;
  final DateTime? sentAt;
  final bool isNotice;
  final bool starred;
  final String? myReaction;

  /// The author may correct a message for [kMessageEditWindow].
  bool editableAt(DateTime now) =>
      mine &&
      !isNotice &&
      sentAt != null &&
      now.toUtc().difference(sentAt!.toUtc()) < kMessageEditWindow;
}

enum _Action { forward, lock, history, delete, star, edit, copy }

/// #1824 — what can be done with one message, in every thread: forward
/// it (absent when the author locked it), lock or unlock it (its author
/// only), see what happened to it, and delete it where the thread allows.
///
/// [forwarding] is the space's `messageForwarding` flag; account
/// messages always pass true. With it off, the sheet keeps only the
/// history and the delete.
Future<void> showMessageActions(
  BuildContext context,
  WidgetRef ref,
  MessageRef message, {
  bool forwarding = true,
  Future<void> Function()? onDelete,
  VoidCallback? onChanged,
}) async {
  final l10n = AppLocalizations.of(context);
  final picked = await showModalBottomSheet<Object>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheet) => SafeArea(
      key: const ValueKey('message-actions-sheet'),
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!message.isNotice)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final emoji in kQuickReactions)
                    InkResponse(
                      key: ValueKey('message-react-$emoji'),
                      radius: 24,
                      onTap: () => Navigator.of(sheet).pop((emoji: emoji)),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: message.myReaction == emoji
                              ? Theme.of(sheet).colorScheme.secondaryContainer
                              : null,
                        ),
                        child: Text(emoji, style: Theme.of(sheet).textTheme.headlineSmall),
                      ),
                    ),
                ],
              ),
            ),
          if (!message.isNotice)
            ListTile(
              key: const ValueKey('message-action-star'),
              leading: Icon(message.starred ? Icons.star : Icons.star_outline),
              title: Text(message.starred
                  ? (l10n?.messengerUnstar ?? 'Remove star')
                  : (l10n?.messengerStar ?? 'Star')),
              onTap: () => Navigator.of(sheet).pop(_Action.star),
            ),
          if (message.body.isNotEmpty && !message.isNotice)
            ListTile(
              key: const ValueKey('message-action-copy'),
              leading: const Icon(Icons.copy_outlined),
              title: Text(l10n?.messengerCopy ?? 'Copy text'),
              onTap: () => Navigator.of(sheet).pop(_Action.copy),
            ),
          if (message.editableAt(ref.read(clockProvider).now()))
            ListTile(
              key: const ValueKey('message-action-edit'),
              leading: const Icon(Icons.edit_outlined),
              title: Text(l10n?.messengerEdit ?? 'Edit'),
              onTap: () => Navigator.of(sheet).pop(_Action.edit),
            ),
          if (forwarding && !message.noForward)
            ListTile(
              key: const ValueKey('message-action-forward'),
              leading: const Icon(Icons.shortcut),
              title: Text(l10n?.messengerForward ?? 'Forward'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(sheet).pop(_Action.forward),
            ),
          if (forwarding && message.noForward && !message.mine)
            ListTile(
              key: const ValueKey('message-action-locked'),
              leading: const Icon(Icons.lock_outline),
              title: Text(
                l10n?.messengerForwardLocked ??
                    'The author locked this message against forwarding.',
              ),
            ),
          if (forwarding && message.mine)
            ListTile(
              key: const ValueKey('message-action-lock'),
              leading: Icon(
                message.noForward
                    ? Icons.lock_open_outlined
                    : Icons.lock_outline,
              ),
              title: Text(
                message.noForward
                    ? (l10n?.messengerUnlock ?? 'Allow forwarding')
                    : (l10n?.messengerLock ?? 'Lock against forwarding'),
              ),
              onTap: () => Navigator.of(sheet).pop(_Action.lock),
            ),
          ListTile(
            key: const ValueKey('message-action-history'),
            leading: const Icon(Icons.history),
            title: Text(l10n?.messengerHistory ?? 'What happened'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(sheet).pop(_Action.history),
          ),
          if (onDelete != null)
            ListTile(
              key: const ValueKey('message-action-delete'),
              leading: const Icon(Icons.delete_outline),
              title: Text(l10n?.messengerDelete ?? 'Delete message'),
              onTap: () => Navigator.of(sheet).pop(_Action.delete),
            ),
        ],
        ),
      ),
    ),
  );
  if (picked == null || !context.mounted) return;
  final actions = ref.read(messengerActionsProvider(source: message.source));
  if (picked is ({String emoji})) {
    final ok = await runMessenger(
      context,
      message: 'react to message failed',
      errorText: l10n?.portalActionFailed ??
          'Could not save this change. Please try again.',
      action: () => actions.react(
        message.kind,
        message.messageId,
        picked.emoji == message.myReaction ? null : picked.emoji,
      ),
    );
    if (ok) onChanged?.call();
    return;
  }
  final action = picked as _Action;
  final failed =
      l10n?.portalActionFailed ??
      'Could not save this change. Please try again.';
  switch (action) {
    case _Action.forward:
      final target = await pickForwardTarget(
        context,
        source: message.source,
        fromKind: message.contextKind,
        fromContextId: message.contextId,
      );
      if (target == null || !context.mounted) return;
      final ok = await runMessenger(
        context,
        message: 'forward message failed',
        errorText: failed,
        action: () => actions.forwardById(
          kind: message.kind,
          messageId: message.messageId,
          target: target,
          locked: message.noForward,
        ),
      );
      if (!ok || !context.mounted) return;
      ref.invalidate(unifiedInboxProvider);
      onChanged?.call();
      AppSnack.success(
        context,
        l10n?.messengerForwarded(target.title) ??
            'Forwarded to ${target.title}.',
        replace: true,
      );
    case _Action.lock:
      final ok = await runGuarded(
        context,
        domain: 'messages',
        message: 'forward lock failed',
        errorText: failed,
        action: () => actions.setForwardLock(
          message.kind,
          message.messageId,
          locked: !message.noForward,
        ),
      );
      if (ok) onChanged?.call();
    case _Action.history:
      await showMessageHistory(
        context,
        kind: message.kind,
        messageId: message.messageId,
        source: message.source,
      );
    case _Action.delete:
      await onDelete?.call();
    case _Action.star:
      final ok = await runMessenger(
        context,
        message: 'star message failed',
        errorText: failed,
        action: () =>
            actions.toggleStar(message.kind, message.messageId),
      );
      if (ok) onChanged?.call();
    case _Action.copy:
      await Clipboard.setData(ClipboardData(text: notePlainText(message.body)));
      if (context.mounted) {
        AppSnack.success(context, l10n?.messengerCopied ?? 'Copied.',
            replace: true);
      }
    case _Action.edit:
      final text = await showEditMessageDialog(context, message.body);
      if (text == null || text.trim().isEmpty || text.trim() == message.body) {
        return;
      }
      if (!context.mounted) return;
      final ok = await runMessenger(
        context,
        message: 'edit message failed',
        errorText: l10n?.messengerEditFailed ??
            'This message could not be edited — the 15 minutes may be over.',
        action: () =>
            actions.edit(message.kind, message.messageId, text.trim()),
      );
      if (ok) onChanged?.call();
  }
}
