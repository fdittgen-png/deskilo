// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/member_note.dart';
import '../../providers/workspace_providers.dart';
import 'member_note_actions.dart';
import 'member_note_body.dart';
import 'member_note_composer.dart';
import 'note_check.dart';

/// THE conversation with one member (messaging refactor): every direct
/// message between me and [otherMemberId], oldest to newest, chat
/// bubbles with the full text (emojis, reference links live) and the
/// read check on mine — plus the shared composer at the bottom. The
/// member sheet, the directory profile and the Events inbox all open
/// THIS, so messages are sent and read the same way everywhere.
/// Opening it marks my unread notes read (the sender's check turns
/// blue). Long-press a bubble to delete it (confirmed, as everywhere).
Future<void> showConversationSheet(
  BuildContext context,
  WidgetRef ref, {
  required String otherMemberId,
  required String otherName,
}) {
  // Opening the thread reads THIS exchange (0108) — the partner's
  // check turns blue, the inbox rows un-bold; everything else stays
  // visibly unread.
  ref
      .read(unreadNoteCountProvider.notifier)
      .markConversationRead(otherMemberId);
  // The keyboard inset is handled INSIDE the sheet (field report): the
  // caller's context sits in a Scaffold body, where viewInsets read 0 —
  // padding from here left the composer buried under the keyboard.
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) =>
        ConversationSheet(otherMemberId: otherMemberId, otherName: otherName),
  );
}

class ConversationSheet extends ConsumerWidget {
  const ConversationSheet({
    super.key,
    required this.otherMemberId,
    required this.otherName,
  });

  final String otherMemberId;
  final String otherName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final me = ref.watch(myMemberProvider).value;
    final notes = ref.watch(myNotesProvider).value ?? const <MemberNote>[];
    // The thread: direct messages between the two of us, oldest first
    // (myNotes arrives newest-first).
    final thread = notes
        .where(
          (n) =>
              (n.fromMemberId == me?.id && n.toMemberId == otherMemberId) ||
              (n.fromMemberId == otherMemberId && n.toMemberId == me?.id),
        )
        .toList()
        .reversed
        .toList();
    // This context lives in the SHEET route, above the Scaffold, so it
    // sees the real keyboard inset: the padding lifts the composer over
    // the keyboard and the height SHRINKS with it — the thread stays
    // scrollable (reverse list keeps the newest message in view).
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        child: SizedBox(
          key: const ValueKey('conversation-sheet'),
          height: (media.size.height - media.viewInsets.bottom) * 0.72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        otherName,
                        style: theme.textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: thread.isEmpty
                    ? Center(
                        child: Text(
                          l10n?.conversationEmpty ??
                              'No messages yet — say hello!',
                          style: theme.textTheme.bodySmall,
                        ),
                      )
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.sm,
                        ),
                        itemCount: thread.length,
                        itemBuilder: (context, index) => _Bubble(
                          note: thread[thread.length - 1 - index],
                          mine:
                              thread[thread.length - 1 - index].fromMemberId ==
                              me?.id,
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: MemberNoteComposer(
                  autofocus: false,
                  onSend: (body) => sendMemberNoteGuarded(
                    context,
                    ref,
                    toMemberId: otherMemberId,
                    body: body,
                    // The thread itself shows the message land — no snack.
                    confirmWithSnack: false,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends ConsumerWidget {
  const _Bubble({required this.note, required this.mine});

  final MemberNote note;
  final bool mine;

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
