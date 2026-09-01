// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../domain/member_note.dart';
import '../../domain/member_note_refs.dart';
import '../../../members/presentation/member_profile_link.dart';
import '../../providers/conversation_providers.dart';
import '../../providers/workspace_providers.dart';
import 'conversation_bubble.dart';
import 'group_info_sheet.dart';
import 'member_note_composer.dart';

/// A conversation, by id (#687) — the thread behind a row of the
/// messaging centre, for a direct exchange or a group alike.
///
/// Distinct from the older `conversation_sheet.dart`, which reconstructs
/// a 1:1 thread by FILTERING every note the viewer can see. That worked
/// when a thread was implicit in a pair of member ids; it cannot show a
/// group, and it re-filters the whole inbox on every rebuild. This one
/// asks for one conversation's messages and gets them.
///
/// The old sheet stays for now because several screens open it, and
/// moving them all is its own change — that is a later stage of #687,
/// not a thing to do halfway here.
Future<void> showConversationThread(
  BuildContext context,
  WidgetRef ref, {
  required String conversationId,
  String? seedBody,
}) async {
  // Read BEFORE the sheet opens, so the badge and the row weight have
  // already settled by the time it closes.
  await runGuarded(
    context,
    domain: 'workspace',
    message: 'mark conversation read failed',
    // Silent: failing to clear an unread badge must never block reading
    // the messages behind it.
    errorText: '',
    action: () =>
        ref.read(workspaceRepositoryProvider).markConversationRead(
              conversationId,
            ),
  );
  if (!context.mounted) return;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ConversationThread(
      conversationId: conversationId,
      seedBody: seedBody,
    ),
  );
}

class ConversationThread extends ConsumerStatefulWidget {
  const ConversationThread({
    super.key,
    required this.conversationId,
    this.seedBody,
  });

  final String conversationId;

  /// #622 — pre-seeds the composer with the reference the message is
  /// about, carried over unchanged from the old sheet.
  final String? seedBody;

  @override
  ConsumerState<ConversationThread> createState() => _ConversationThreadState();
}

class _ConversationThreadState extends ConsumerState<ConversationThread> {
  /// #798 — the message the next send will quote, set by swiping a
  /// bubble right and cleared by sending or by the chip's close button.
  ({String id, String preview})? _quoted;

  @override
  Widget build(BuildContext context) {
    final conversationId = widget.conversationId;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final me = ref.watch(myMemberProvider).value;
    final names = ref.watch(memberNamesProvider).value ?? const {};
    final messages =
        ref.watch(conversationMessagesProvider(conversationId)).value ??
            const <MemberNote>[];
    final conversation = (ref.watch(conversationsProvider).value ?? const [])
        .where((c) => c.id == conversationId)
        .firstOrNull;

    final title = conversation == null
        ? ''
        : conversation.isGroup
            ? (conversation.title ?? (l10n?.conversationGroup ?? 'Group'))
            : (names[conversation.otherMemberId] ??
                (l10n?.conversationUnknownMember ?? 'Member'));

    // This context lives in the SHEET route, above the Scaffold, so it
    // sees the real keyboard inset — the composer lifts and the thread
    // shrinks with it rather than being buried.
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        child: SizedBox(
          key: const ValueKey('conversation-thread'),
          height: (media.size.height - media.viewInsets.bottom) * 0.72,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.xs,
              ),
              child: Row(children: [
                Expanded(
                  // The HEADER is the way into the roster — WhatsApp's
                  // idiom, and the one place people look for "who is in
                  // this". A separate overflow menu hides it behind a
                  // guess.
                  child: InkWell(
                    key: const ValueKey('conversation-header'),
                    // A GROUP header opens its roster; a DIRECT one
                    // opens the person — same gesture, and the thing
                    // behind the name is what you want either way.
                    onTap: conversation == null
                        ? null
                        : conversation.isGroup
                            ? () => showGroupInfoSheet(
                                  context,
                                  ref,
                                  conversation: conversation,
                                )
                            : (conversation.otherMemberId == null
                                ? null
                                : () => openMemberProfile(
                                      context,
                                      ref,
                                      memberId: conversation.otherMemberId!,
                                    )),
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!(conversation?.isGroup ?? true))
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(
                            l10n?.conversationSeeProfile ?? 'See profile',
                            style: theme.textTheme.bodySmall,
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ]),
                      if (conversation?.isGroup ?? false)
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(
                            l10n?.conversationMemberCount(
                                  conversation!.participantCount,
                                ) ??
                                '${conversation!.participantCount} members',
                            style: theme.textTheme.bodySmall,
                          ),
                          // A chevron, because a tappable subtitle that
                          // looks like plain text is a control nobody
                          // finds.
                          Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ]),
                    ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ]),
            ),
            Expanded(
              child: messages.isEmpty
                  ? Center(
                      child: Text(
                        l10n?.conversationEmpty ??
                            'No messages yet — say hello!',
                        style: theme.textTheme.bodySmall,
                      ),
                    )
                  : ListView.builder(
                      // Reversed so the newest message is in view and
                      // stays there when the keyboard opens.
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final note = messages[messages.length - 1 - index];
                        return ConversationBubble(
                          note: note,
                          mine: note.fromMemberId == me?.id,
                          onQuote: (quoted) => setState(() {
                            _quoted = (
                              id: quoted.id,
                              preview: notePreview(quoted.body, max: 80),
                            );
                          }),
                          // A GROUP bubble names its sender; a direct one
                          // does not, because there is only one person it
                          // could be and repeating it is noise.
                          senderName: (conversation?.isGroup ?? false) &&
                                  note.fromMemberId != me?.id
                              ? names[note.fromMemberId]
                              : null,
                        );
                      },
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
                seedBody: widget.seedBody,
                quoted: _quoted,
                onCancelQuote: () => setState(() => _quoted = null),
                onSend: (body) => _send(context, ref, body),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<bool> _send(BuildContext context, WidgetRef ref, String body) async {
    final conversationId = widget.conversationId;
    final l10n = AppLocalizations.of(context);
    final ok = await runGuarded(
      context,
      domain: 'workspace',
      message: 'send conversation message failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () => ref
          .read(workspaceRepositoryProvider)
          .sendConversationMessage(conversationId, body),
    );
    if (!ok) return false;
    if (mounted) setState(() => _quoted = null);
    // The thread shows it land, so no snack — but the LIST behind still
    // holds the old preview and order.
    ref
      ..invalidate(conversationMessagesProvider(conversationId))
      ..invalidate(conversationsProvider);
    return true;
  }
}
