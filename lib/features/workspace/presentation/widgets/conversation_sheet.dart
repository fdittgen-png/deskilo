// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/member_note.dart';
import '../../providers/workspace_providers.dart';
import 'member_note_actions.dart';
import 'member_note_composer.dart';
import 'conversation_bubble.dart';

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
  String? seedBody,
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
    builder: (_) => ConversationSheet(
      otherMemberId: otherMemberId,
      otherName: otherName,
      seedBody: seedBody,
    ),
  );
}

class ConversationSheet extends ConsumerWidget {
  const ConversationSheet({
    super.key,
    required this.otherMemberId,
    required this.otherName,
    this.seedBody,
  });

  final String otherMemberId;
  final String otherName;

  /// #622 — pre-seeds the composer (e.g. the blocking reservation's
  /// `[res:…]` reference) so the message points at what it is about.
  final String? seedBody;

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
                        itemBuilder: (context, index) => ConversationBubble(
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
                  seedBody: seedBody,
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
