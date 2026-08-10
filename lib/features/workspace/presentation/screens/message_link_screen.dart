// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../providers/workspace_providers.dart';
import '../widgets/conversation_sheet.dart';

/// Deep-link target `/msg/:id` (0106): the WhatsApp mirror of a message
/// ends with a link here — the app opens DIRECTLY on the conversation
/// the message belongs to. Resolves the note from my inbox (RLS scopes
/// it), then shows the thread full-screen; a broadcast (no single
/// partner) and a since-deleted note land on the Events inbox instead.
class MessageLinkScreen extends ConsumerWidget {
  const MessageLinkScreen({super.key, required this.noteId});

  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final notesAsync = ref.watch(myNotesProvider);
    final me = ref.watch(myMemberProvider).value;
    final names = ref.watch(memberNamesProvider).value ?? const {};
    final notes = notesAsync.value;
    if (notes == null) {
      return const Scaffold(body: LoadingView());
    }
    final note = notes.where((n) => n.id == noteId).firstOrNull;
    final partner = note == null || note.isBroadcast
        ? null
        : (note.fromMemberId == me?.id
            ? note.toMemberId
            : note.fromMemberId);
    if (note == null || partner == null) {
      // Gone or a broadcast: the inbox is the right landing spot.
      return Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => context.go('/events')),
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            EmptyState(
              icon: Icons.mark_email_read_outlined,
              title: l10n?.messageLinkGone ??
                  'This message lives in your inbox.',
            ),
            FilledButton(
              key: const ValueKey('message-link-inbox'),
              onPressed: () => context.go('/events'),
              child: Text(l10n?.eventsMessagesHeader ?? 'Messages'),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/events')),
        title: Text(names[partner] ?? ''),
      ),
      // The same thread every other surface opens — full height here.
      body: ConversationSheet(
        otherMemberId: partner,
        otherName: names[partner] ?? '',
      ),
    );
  }
}
