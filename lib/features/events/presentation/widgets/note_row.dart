// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/domain/member_note.dart';
import '../../../workspace/domain/member_note_refs.dart';
import '../../../workspace/presentation/widgets/conversation_sheet.dart';
import '../../../workspace/presentation/widgets/member_note_actions.dart';
import '../../../workspace/presentation/widgets/member_note_sheet.dart';
import '../../../workspace/presentation/widgets/note_check.dart';

/// One member note in the Messages inbox (#460, #523): direction +
/// sender or recipient, a 64-CHARACTER PREVIEW, and when it was sent.
/// Tapping the row opens the full message — emojis, reference links
/// and all. Swipe RIGHT to reply, swipe LEFT to delete after an
/// explicit confirmation — a received broadcast cannot be deleted (it
/// would vanish for every admin) and my own notes offer no
/// reply-to-myself.
class NoteRow extends ConsumerWidget {
  const NoteRow({
    super.key,
    required this.note,
    required this.names,
    required this.myMemberId,
  });

  final MemberNote note;
  final Map<String, String> names;
  final String? myMemberId;

  /// The direct-thread partner: whoever ISN'T me. A broadcast I sent
  /// has no single partner (null → the full-message sheet handles it);
  /// a received broadcast converses with its sender.
  String? _counterpartId(bool sentByMe) =>
      sentByMe ? note.toMemberId : note.fromMemberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final sentByMe = note.fromMemberId == myMemberId;
    final title = sentByMe
        ? (note.isBroadcast
            ? (l10n?.memberNoteToAllAdmins ?? 'To all admins')
            : (l10n?.memberNoteTo(names[note.toMemberId] ?? '') ??
                'To ${names[note.toMemberId] ?? ''}'))
        : (l10n?.memberNoteReceived(names[note.fromMemberId] ?? '') ??
            'Message from ${names[note.fromMemberId] ?? ''}');
    final when = DateFormat.MMMd()
        .add_Hm()
        .format(note.createdAt.toLocal());
    final canDelete = sentByMe || !note.isBroadcast;
    final canReply = !sentByMe;
    final tile = ListTile(
      leading: Icon(
        sentByMe
            ? (note.isBroadcast
                ? Icons.campaign_outlined
                : Icons.outbox_outlined)
            : Icons.mark_email_unread_outlined,
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: sentByMe ? null : FontWeight.w600,
        ),
      ),
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
          showConversationSheet(
            context,
            ref,
            otherMemberId: partner,
            otherName: names[partner] ?? '',
          );
          return;
        }
        showMemberNoteSheet(
          context,
          ref,
          note: note,
          title: title,
          replyToMemberId: canReply ? note.fromMemberId : null,
          replyToName: names[note.fromMemberId] ?? '',
          onDelete: canDelete
              ? () => deleteMemberNoteGuarded(context, ref, note)
              : null,
        );
      },
    );
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
        if (direction == DismissDirection.startToEnd) {
          // Replying = opening the conversation (refactor): the whole
          // exchange in view beats a blank dialog.
          final partner = _counterpartId(sentByMe);
          if (canReply && partner != null) {
            await showConversationSheet(
              context,
              ref,
              otherMemberId: partner,
              otherName: names[partner] ?? '',
            );
          }
        } else if (canDelete) {
          await deleteMemberNoteGuarded(context, ref, note);
        }
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
      child: tile,
    );
  }
}
