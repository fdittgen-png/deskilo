// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/composer_send_keys.dart';
import '../../../workspace/domain/workspace.dart';
import '../../application/messenger_actions.dart';
import '../../domain/conversation_delivery.dart';
import '../../domain/messenger.dart';
import '../../providers/conversation_pane_providers.dart';
import 'environment_pill.dart';

/// A thread's unsent text, kept per conversation for the session under the
/// account that opened the thread (ConversationDrafts), and the send that
/// waits on it (ConversationSends).
class ThreadDraft {
  ThreadDraft(String? account, WidgetRef ref, String Function() keyOf)
    : this._(
        account,
        ref.read(conversationDraftsProvider.notifier),
        ref.read(conversationSendsProvider.notifier),
        keyOf,
        inFlight: ref.read(conversationSendsProvider)[keyOf()] ==
            SendPhase.inFlight,
      );

  ThreadDraft._(
    this._account,
    this._drafts,
    this._sends,
    this._keyOf, {
    required bool inFlight,
  }) : restored = inFlight ? '' : _drafts.draftOf(_account, _keyOf());

  final String? _account;
  final ConversationDrafts _drafts;
  final ConversationSends _sends;
  final String Function() _keyOf;

  /// The unsent text found when the thread opened — none while a send of
  /// it is still in flight, so it can never go out twice.
  final String restored;

  /// The conversation's key as it is now.
  String get key => _keyOf();

  /// The draft as it is now.
  String get current => _drafts.draftOf(_account, _keyOf());

  void keep(String text) => _drafts.keep(_account, _keyOf(), text);

  /// Waits on [attempt], the send of [text] under the key as it is now:
  /// true delivered, false refused, null unanswered after
  /// [ConversationDelivery.unconfirmedAfter] — unconfirmed, never resent;
  /// its late answer still settles it. Only a delivery clears the draft,
  /// under this account, and only while it still holds [text] — also when
  /// it lands after the thread closed or another account signed in (then
  /// it changes nothing).
  Future<bool?> deliver(String text, Future<bool> attempt) async {
    final key = _keyOf();
    void settle({required bool ok}) {
      if (ok) _drafts.clearIfStill(_account, key, text);
      _sends.mark(_account, key, null);
    }

    _sends.mark(_account, key, SendPhase.inFlight);
    var unanswered = false;
    final ok = await attempt.timeout(
      ConversationDelivery.unconfirmedAfter,
      onTimeout: () {
        unanswered = true;
        return false;
      },
    );
    if (!unanswered) {
      settle(ok: ok);
      return ok;
    }
    _sends.mark(_account, key, SendPhase.unconfirmed);
    unawaited(attempt.then((ok) => settle(ok: ok)));
    return null;
  }

  /// The person reads the conversation again: unconfirmed no more.
  void reviewed() => _sends.mark(_account, _keyOf(), null);
}

/// Above the composer while its conversation's send waits: still in flight
/// (sent from this conversation opened earlier), or unconfirmed with the
/// way to read the conversation again.
class DeliveryNote extends StatelessWidget {
  const DeliveryNote(this.phase, {super.key, required this.onReview});
  final SendPhase phase;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: switch (phase) {
        SendPhase.inFlight => Text(
          l10n.conversationSendInFlight,
          key: const ValueKey('context-send-in-flight'),
          style: style,
        ),
        SendPhase.unconfirmed => Row(
          children: [
            Expanded(
              child: Text(
                l10n.conversationSendUnconfirmed,
                key: const ValueKey('context-send-unconfirmed'),
                style: style,
              ),
            ),
            TextButton(
              key: const ValueKey('context-send-review'),
              onPressed: onReview,
              child: Text(l10n.conversationSendReview),
            ),
          ],
        ),
      },
    );
  }
}

/// Above the composer of a person who shares several workspaces with the
/// conversation: which workspace its references (a reservation, a space,
/// an invoice…) speak about.
class ThreadRefsWorkspacePicker extends StatelessWidget {
  const ThreadRefsWorkspacePicker({
    super.key,
    required this.workspaces,
    required this.active,
    required this.onChoose,
  });

  final List<Workspace> workspaces;
  final String? active;
  final ValueChanged<String> onChoose;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.xs,
      AppSpacing.md,
      0,
    ),
    child: Row(
      children: [
        Icon(
          Icons.link,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          context.l10n.threadRefsIn,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: DropdownButton<String>(
            key: const ValueKey('thread-ref-workspace'),
            value: workspaces.any((w) => w.id == active) ? active : null,
            isDense: true,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            items: [
              for (final w in workspaces)
                DropdownMenuItem(
                  value: w.id,
                  child: EnvironmentLabel(
                    w.name,
                    isProd: w.environment == 'prod',
                  ),
                ),
            ],
            onChanged: (id) {
              if (id != null) onChoose(id);
            },
          ),
        ),
      ],
    ),
  );
}

/// A thread's header title: who or what it is about, and where.
class ThreadTitle extends StatelessWidget {
  const ThreadTitle(this.title, this.subtitle, {super.key});
  final String title, subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, overflow: TextOverflow.ellipsis),
      if (subtitle.isNotEmpty)
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall,
          overflow: TextOverflow.ellipsis,
        ),
    ],
  );
}

/// The Back of a thread that is the messenger's focused page, not a route.
class ThreadBack extends StatelessWidget {
  const ThreadBack(this.onPressed, {super.key});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => BackButton(
    key: const ValueKey('context-thread-back'),
    onPressed: onPressed,
  );
}

/// Asks before one of my messages is deleted; pops true to delete.
class MessageDeleteDialog extends StatelessWidget {
  const MessageDeleteDialog({super.key});

  @override
  Widget build(BuildContext context) => AlertDialog(
    content: Text(context.l10n.messengerDeleteConfirm),
    actions: [
      TextButton(
        key: const ValueKey('context-thread-text-button'),
        onPressed: () => Navigator.of(context).pop(false),
        child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
      ),
      FilledButton(
        key: const ValueKey('context-delete-confirm'),
        onPressed: () => Navigator.of(context).pop(true),
        child: Text(context.l10n.messengerDelete),
      ),
    ],
  );
}

/// Above a composer that reopened with unsent text: the draft lives in
/// this app's memory only, never on the device or in the cloud.
class DraftSessionNote extends StatelessWidget {
  const DraftSessionNote({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    child: Text(
      context.l10n.conversationDraftSessionOnly,
      key: const ValueKey('context-draft-session-only'),
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );
}

/// The composer of a conversation on another server: the field (Return a
/// newline, Ctrl/Cmd+Enter sends) and Send, both locked while one goes out.
class PlainComposer extends StatelessWidget {
  const PlainComposer({
    super.key,
    required this.controller,
    required this.busy,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      top: false,
      child: Padding(
        padding: AppSpacing.mdAll,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: ComposerSendKeys(
                controller: controller,
                onSend: onSend,
                child: TextField(
                  key: const ValueKey('context-composer'),
                  controller: controller,
                  enabled: !busy,
                  maxLength: MessengerRules.maxBody,
                  minLines: 1,
                  maxLines: 4,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(labelText: l10n.memberNoteHint),
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('context-send'),
              tooltip: l10n.memberNoteSend,
              onPressed: busy ? null : onSend,
              icon: const Icon(Icons.send_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tells the conversation a screenshot was taken of it (iOS cannot refuse
/// one); answers whether it was told. A failure never blocks reading.
Future<bool> recordThreadCapture(
  MessengerActions actions,
  MessageContextKind kind,
  String contextId,
) async {
  try {
    await actions.recordScreenCapture(kind, contextId);
    return true;
  } on Object catch (e, st) {
    TraceLogger.instance.error(
      'messages',
      'record screen capture failed',
      error: e,
      stackTrace: st,
    );
    return false;
  }
}
