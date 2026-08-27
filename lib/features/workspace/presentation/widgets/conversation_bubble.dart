// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/member_note.dart';
import 'member_note_actions.dart';
import 'member_note_body.dart';
import 'note_check.dart';

/// One chat bubble (#687), lifted out of conversation_sheet.dart so the
/// group thread renders messages exactly as the 1:1 sheet always has.
///
/// Two renderers for the same bubble is how a group's messages end up
/// looking subtly unlike a direct one — different padding, a reference
/// link that resolves in one and not the other.
class ConversationBubble extends ConsumerWidget {
  const ConversationBubble({
    super.key,
    required this.note,
    required this.mine,
    this.senderName,
  });

  final MemberNote note;
  final bool mine;

  /// Named above the bubble in a GROUP, where "ok" from nobody in
  /// particular is unreadable. Null in a direct thread: there is only
  /// one person it could be from, and saying so every time is noise.
  final String? senderName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final when = DateFormat.MMMd().add_Hm().format(note.createdAt.toLocal());
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        key: ValueKey('bubble-${note.id}'),
        onLongPress: () => deleteMemberNoteGuarded(context, ref, note),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          decoration: BoxDecoration(
            color: mine
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: AppRadius.lgAll,
          ),
          // Field report: the DARK theme keeps a LIGHT primaryContainer,
          // so my bubble must use its on-color for EVERYTHING inside —
          // body, links, timestamp and the delivery check. Inheriting
          // the theme's light body color made my own texts unreadable.
          child: Builder(
            builder: (context) {
              final fg = mine
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurface;
              final fgMuted = mine
                  ? fg.withValues(alpha: .7)
                  : theme.colorScheme.onSurfaceVariant;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  MemberNoteBody(
                    body: note.body,
                    style: theme.textTheme.bodyMedium?.copyWith(color: fg),
                    linkColor: mine ? fg : null,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        when,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: fgMuted,
                        ),
                      ),
                      if (mine) ...[
                        const SizedBox(width: 4),
                        NoteCheck(note: note, unreadColor: fgMuted),
                      ],
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
