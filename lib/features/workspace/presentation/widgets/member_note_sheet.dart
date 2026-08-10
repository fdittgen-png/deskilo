// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/member_note.dart';
import 'member_note_body.dart';
import 'conversation_sheet.dart';

/// The FULL message (#523): the list shows only the first 64
/// characters — tapping a row opens this sheet with the complete text,
/// emojis and all, the reference links live, and the same actions the
/// swipes offer (reply / delete), spelled out as buttons.
///
/// [onDelete] runs the caller's delete flow (which asks for
/// confirmation); null hides the button (received broadcasts).
/// [replyToMemberId]/[replyToName] enable the reply button.
Future<void> showMemberNoteSheet(
  BuildContext context,
  WidgetRef ref, {
  required MemberNote note,
  required String title,
  String? replyToMemberId,
  String replyToName = '',
  Future<void> Function()? onDelete,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final l10n = AppLocalizations.of(sheetContext);
        final theme = Theme.of(sheetContext);
        final when = DateFormat.yMMMd()
            .add_Hm()
            .format(note.createdAt.toLocal());
        return SheetShell(
          title: title,
          children: [
            Text(
              when,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // The one place the message is readable IN FULL.
            MemberNoteBody(
              key: const ValueKey('note-sheet-body'),
              body: note.body,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                if (replyToMemberId != null)
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('note-sheet-reply'),
                      icon: const Icon(Icons.reply),
                      label: Text(l10n?.memberNoteReply ?? 'Reply'),
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        // Replying = the conversation (refactor): the
                        // whole exchange with the sender in one thread.
                        await showConversationSheet(
                          context,
                          ref,
                          otherMemberId: replyToMemberId,
                          otherName: replyToName,
                        );
                      },
                    ),
                  ),
                if (replyToMemberId != null && onDelete != null)
                  const SizedBox(width: AppSpacing.sm),
                if (onDelete != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('note-sheet-delete'),
                      icon: const Icon(Icons.delete_outline),
                      label:
                          Text(l10n?.memberNoteDelete ?? 'Delete'),
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        await onDelete();
                      },
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
