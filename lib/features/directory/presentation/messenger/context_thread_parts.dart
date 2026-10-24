// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../workspace/domain/workspace.dart';
import '../../providers/conversation_pane_providers.dart';
import 'environment_pill.dart';

/// A thread's unsent text, kept per conversation for the session under the
/// account that opened the thread (ConversationDrafts).
class ThreadDraft {
  ThreadDraft(String? account, ConversationDrafts drafts, this._keyOf)
    : _account = account,
      _drafts = drafts,
      restored = drafts.draftOf(account, _keyOf());

  final String? _account;
  final ConversationDrafts _drafts;
  final String Function() _keyOf;

  /// The unsent text found when the thread opened.
  final String restored;

  void keep(String text) => _drafts.keep(_account, _keyOf(), text);

  /// Clears the draft as it is keyed now, under this account — also when
  /// the delivery that calls it lands after the thread closed or another
  /// account signed in (then it changes nothing).
  VoidCallback clearOnDelivery() {
    final key = _keyOf();
    return () => _drafts.clear(_account, key);
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
