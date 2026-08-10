// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/domain/member_note.dart';
import '../../../workspace/domain/member_note_refs.dart';
import '../../../workspace/presentation/widgets/member_note_dialog.dart';
import '../../../workspace/presentation/widgets/member_note_sheet.dart';
import '../../../workspace/providers/workspace_providers.dart';

/// Read-check blue (0105) — the calendar's fixed "others" hue, chosen
/// once for both themes: the receipt must read as "blue" everywhere,
/// including on the orange brand palette.
const _readBlue = Color(0xFF42A5F5);

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

  /// #523 — deleting is destructive: every path (swipe and the sheet's
  /// button) asks first.
  Future<bool> _confirmDelete(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n?.memberNoteDelete ?? 'Delete'),
        content: Text(l10n?.memberNoteDeleteConfirm ??
            'Delete this message? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n?.commonCancel ?? 'Cancel'),
          ),
          FilledButton(
            key: const ValueKey('note-delete-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n?.memberNoteDelete ?? 'Delete'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    if (!await _confirmDelete(context)) return;
    if (!context.mounted) return;
    try {
      await ref
          .read(workspaceRepositoryProvider)
          .deleteMemberNote(note.id);
    } catch (e, st) {
      TraceLogger.instance.error('workspace', 'delete member note failed',
          error: e, stackTrace: st);
      if (!context.mounted) return;
      AppSnack.error(
        context,
        l10n?.workspaceGenericError ??
            'Something went wrong. Please try again.',
      );
      ref.invalidate(myNotesProvider);
      return;
    }
    ref.invalidate(myNotesProvider);
    if (!context.mounted) return;
    AppSnack.info(
      context,
      l10n?.memberNoteDeleted ?? 'Message deleted.',
      replace: true,
    );
  }

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
                Icon(
                  Icons.done,
                  key: ValueKey('note-check-${note.id}'),
                  size: 14,
                  color: note.readAt != null
                      ? _readBlue
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ],
          ),
        ],
      ),
      onTap: () => showMemberNoteSheet(
        context,
        ref,
        note: note,
        title: title,
        replyToMemberId: canReply ? note.fromMemberId : null,
        replyToName: names[note.fromMemberId] ?? '',
        onDelete:
            canDelete ? () => _delete(context, ref) : null,
      ),
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
          if (canReply) {
            await showMemberNoteDialog(
              context,
              ref,
              toMemberId: note.fromMemberId,
              recipientName: names[note.fromMemberId] ?? '',
            );
          }
        } else if (canDelete) {
          await _delete(context, ref);
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
