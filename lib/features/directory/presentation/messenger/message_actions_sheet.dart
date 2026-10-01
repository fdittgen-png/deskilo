// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/messenger.dart';
import '../../providers/messenger_providers.dart';
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
  });

  final MessageKind kind;
  final String messageId;
  final MessageContextKind contextKind;
  final String contextId;
  final bool mine;
  final bool noForward;
  final String source;
}

enum _Action { forward, lock, history, delete }

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
  final action = await showModalBottomSheet<_Action>(
    context: context,
    builder: (sheet) => SafeArea(
      key: const ValueKey('message-actions-sheet'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
  );
  if (action == null || !context.mounted) return;
  final actions = ref.read(messengerActionsProvider(source: message.source));
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
  }
}
