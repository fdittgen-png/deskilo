// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/member_note.dart';
import '../../domain/member_note_refs.dart';
import '../../domain/workspace_feature.dart';
import '../../providers/workspace_providers.dart';
import 'member_note_actions.dart';
import 'member_note_body.dart';
import 'note_check.dart';

/// One chat bubble (#687), lifted out of conversation_sheet.dart so the
/// group thread renders messages exactly as the 1:1 sheet always has.
///
/// Two renderers for the same bubble is how a group's messages end up
/// looking subtly unlike a direct one — different padding, a reference
/// link that resolves in one and not the other.
///
/// #798 — the two swipes everyone already knows from their phone:
/// RIGHT quotes the message into the composer, LEFT takes it back while
/// it is still unread.
class ConversationBubble extends ConsumerWidget {
  const ConversationBubble({
    super.key,
    required this.note,
    required this.mine,
    this.senderName,
    this.onQuote,
  });

  final MemberNote note;
  final bool mine;

  /// Named above the bubble in a GROUP, where "ok" from nobody in
  /// particular is unreadable. Null in a direct thread: there is only
  /// one person it could be from, and saying so every time is noise.
  final String? senderName;

  /// Swipe-right target (#798). Null where the surface has no composer
  /// to quote INTO — the bubble then keeps the plain long-press menu.
  final ValueChanged<MemberNote>? onQuote;

  /// A message can be taken back while it is still UNREAD, and only by
  /// the person who wrote it.
  ///
  /// The read stamp is the whole rule: once someone has read it, the
  /// words have landed and a delete would only hide the evidence from
  /// one side of a conversation the other still remembers. The server
  /// re-checks; this decides what the gesture OFFERS.
  bool get _deletableUnread => mine && note.readAt == null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final gestures = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.messageGestures);
    final bubble = _bubble(context, ref, theme);
    if (!gestures) return bubble;
    return Dismissible(
      key: ValueKey('swipe-${note.id}'),
      // Both swipes ACT and put the bubble back — nothing here is a
      // list removal, and a message that vanishes before its own
      // confirmation dialog is answered is a lie about what happened.
      direction: onQuote == null
          ? DismissDirection.endToStart
          : DismissDirection.horizontal,
      // A reply is a flick — the gesture people make without thinking,
      // and the default 40% of the width is a shove. Taking a message
      // back is the opposite: deliberate, so it keeps a longer pull
      // before the confirmation even appears.
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.2,
        DismissDirection.endToStart: 0.35,
      },
      background: _swipeHint(
        theme,
        alignment: Alignment.centerLeft,
        icon: Icons.reply,
        color: theme.colorScheme.primary,
      ),
      secondaryBackground: _swipeHint(
        theme,
        alignment: Alignment.centerRight,
        icon: _deletableUnread ? Icons.delete_outline : Icons.lock_outline,
        color: _deletableUnread
            ? theme.colorScheme.error
            : theme.colorScheme.outline,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onQuote?.call(note);
          return false;
        }
        if (!_deletableUnread) {
          // Saying WHY beats a swipe that springs back for no visible
          // reason — the two causes are different and both actionable.
          AppSnack.info(
            context,
            mine
                ? (l10n?.memberNoteDeleteRead ??
                    'Already read — this message can no longer be taken back.')
                : (l10n?.memberNoteDeleteNotMine ??
                    'Only the sender can take a message back.'),
            replace: true,
          );
          return false;
        }
        await deleteMemberNoteGuarded(context, ref, note);
        return false;
      },
      child: bubble,
    );
  }

  Widget _swipeHint(
    ThemeData theme, {
    required Alignment alignment,
    required IconData icon,
    required Color color,
  }) =>
      Container(
        alignment: alignment,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Icon(icon, color: color),
      );

  Widget _bubble(BuildContext context, WidgetRef ref, ThemeData theme) {
    final when = DateFormat.MMMd().add_Hm().format(note.createdAt.toLocal());
    final split = splitLeadingQuote(note.body);
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
                  if (split.quote != null)
                    _QuotedBlock(quote: split.quote!, foreground: fg),
                  MemberNoteBody(
                    body: split.rest,
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

/// The quoted message above a reply — a tinted block with the accent bar
/// every chat app uses, so a reply reads as a reply at a glance.
class _QuotedBlock extends StatelessWidget {
  const _QuotedBlock({required this.quote, required this.foreground});

  final NoteQuoteRef quote;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: ValueKey('quote-${quote.id}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: .08),
        borderRadius: AppRadius.smAll,
        border: Border(
          left: BorderSide(color: foreground.withValues(alpha: .5), width: 3),
        ),
      ),
      child: Text(
        quote.preview,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: foreground.withValues(alpha: .8),
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
