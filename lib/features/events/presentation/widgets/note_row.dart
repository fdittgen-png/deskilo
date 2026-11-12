// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../core/ui/kit/row_menu.dart';
import '../../../workspace/domain/member_note.dart';
import '../../../workspace/domain/member_note_refs.dart';
import '../../../workspace/presentation/widgets/member_note_actions.dart';
import '../../../workspace/presentation/widgets/member_note_sheet.dart';
import '../../../workspace/presentation/widgets/note_check.dart';
import '../../../workspace/presentation/widgets/open_conversation.dart';

/// One member note in the Messages inbox (#460, #523): direction +
/// sender or recipient, a 64-CHARACTER PREVIEW, and when it was sent.
/// Tapping the row opens the full message — emojis, reference links
/// and all. Swipe RIGHT to reply, swipe LEFT to delete after an
/// explicit confirmation — a received broadcast cannot be deleted (it
/// would vanish for every admin) and my own notes offer no
/// reply-to-myself.
///
/// #3611 — the same reply and delete open from the row's menu (⋯ on
/// hover, a right click, a long press, the context-menu key); the swipes
/// call those very actions.
class NoteRow extends ConsumerWidget {
  const NoteRow({
    super.key,
    required this.note,
    required this.names,
    required this.myMemberId,
    this.unread = false,
  });

  final MemberNote note;
  final Map<String, String> names;
  final String? myMemberId;

  /// #539 — unread rows read as such: bold, tinted icon, a dot. Read
  /// rows recede. Computed by the screen from `unreadNoteIds`.
  final bool unread;

  /// The direct-thread partner: whoever ISN'T me. A broadcast I sent
  /// has no single partner (null → the full-message sheet handles it);
  /// a received broadcast converses with its sender.
  String? _counterpartId(bool sentByMe) =>
      sentByMe ? note.toMemberId : note.fromMemberId;

  /// The row's reply and delete, once: the menu and the swipes call
  /// these very actions (#3611).
  List<RowAction> _actions(
    BuildContext context,
    WidgetRef ref, {
    required bool sentByMe,
    required bool canReply,
    required bool canDelete,
  }) {
    final l10n = context.l10n;
    final partner = _counterpartId(sentByMe);
    return [
      if (canReply && partner != null)
        RowAction(
          id: 'reply',
          label: l10n.memberNoteReply,
          icon: Icons.reply,
          // Replying = opening the conversation (refactor): the whole
          // exchange in view beats a blank dialog.
          // recorder-key-exempt: the RowMenu keys this entry <keyPrefix>-<id>
          onSelected: () =>
              openDirectConversation(context, ref, memberId: partner),
        ),
      if (canDelete)
        RowAction(
          id: 'delete',
          label: l10n.memberNoteDelete,
          icon: Icons.delete_outline,
          destructive: true,
          // recorder-key-exempt: the RowMenu keys this entry <keyPrefix>-<id>
          onSelected: () => deleteMemberNoteGuarded(context, ref, note),
        ),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final sentByMe = note.fromMemberId == myMemberId;
    final title = sentByMe
        ? (note.isBroadcast
            ? (l10n.memberNoteToAllAdmins)
            : (l10n.memberNoteTo(names[note.toMemberId] ?? '')))
        : (l10n.memberNoteReceived(names[note.fromMemberId] ?? ''));
    final when = appFormatOf(context).datesAndTime(DateShape.monthDay, note.createdAt);
    final canDelete = sentByMe || !note.isBroadcast;
    final canReply = !sentByMe;
    final tile = ListTile(
      key: const ValueKey('note-row-campaign'),
      leading: Icon(
        sentByMe
            ? (note.isBroadcast
                ? Icons.campaign_outlined
                : Icons.outbox_outlined)
            : (unread
                ? Icons.mark_email_unread
                : Icons.drafts_outlined),
        color: unread ? theme.colorScheme.primary : null,
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: unread ? FontWeight.w700 : null,
        ),
      ),
      trailing: unread
          ? Icon(
              Icons.circle,
              key: ValueKey('note-unread-${note.id}'),
              size: 10,
              color: theme.colorScheme.primary,
            )
          : null,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // #523 — the list carries only the first 64 characters; the
          // full message (emojis, reference links) lives in the sheet.
          Text(notePreview(note.body)),
          Row(
            children: [
              Text(
                when,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              // Read receipt on what I sent (0105): grey = delivered,
              // blue = the recipient read it. A broadcast has many
              // readers and no single read state — it stays grey.
              if (sentByMe) ...[
                const SizedBox(width: 4),
                NoteCheck(note: note),
              ],
            ],
          ),
        ],
      ),
      // A direct message opens ITS CONVERSATION (messaging refactor):
      // the same thread the member sheet and directory profile open.
      // Only a broadcast — no single partner — keeps the full-message
      // sheet.
      onTap: () {
        final partner = _counterpartId(sentByMe);
        if (!note.isBroadcast && partner != null) {
          unawaited(openDirectConversation(context, ref, memberId: partner));
          return;
        }
        unawaited(showMemberNoteSheet(
          context,
          ref,
          note: note,
          title: title,
          replyToMemberId: canReply ? note.fromMemberId : null,
          replyToName: names[note.fromMemberId] ?? '',
          onDelete: canDelete
              ? () => deleteMemberNoteGuarded(context, ref, note)
              : null,
        ));
      },
    );
    final actions = _actions(context, ref,
        sentByMe: sentByMe, canReply: canReply, canDelete: canDelete);
    RowAction? action(String id) =>
        actions.where((a) => a.id == id).firstOrNull;
    // parity: note-menu-
    return Dismissible(
      key: ValueKey('note-dismiss-${note.id}'),
      direction: canDelete || canReply
          ? DismissDirection.horizontal
          : DismissDirection.none,
      // Swipe RIGHT = reply, swipe LEFT = delete. Neither ever
      // "dismisses" the widget itself: the deletion flows through the
      // provider (repo delete → invalidate → the row leaves on the
      // rebuild) — Dismissible's synchronous-removal contract and an
      // async repository do not mix.
      confirmDismiss: (direction) async {
        await action(direction == DismissDirection.startToEnd
                ? 'reply'
                : 'delete')
            ?.onSelected();
        return false;
      },
      background: Container(
        color: AppStatusColors.successOf(theme.brightness),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: AppSpacing.lg),
        child: const Icon(Icons.reply, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: theme.colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        child: Icon(Icons.delete_outline,
            color: theme.colorScheme.onError),
      ),
      child: RowMenu(
        actions: actions,
        keyPrefix: 'note-menu-${note.id}',
        button: RowMenuButton.onHover,
        child: tile,
      ),
    );
  }
}
