// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/kit/row_menu.dart';
import '../../../directory/domain/message_marks.dart';
import '../../../directory/presentation/messenger/message_marks.dart';
import '../../../directory/presentation/messenger/reaction_strip.dart';
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
///
/// #3611 — the message menu (⋯ beside the bubble, a right click, a long
/// press, the context-menu key) holds the same quote and delete the
/// swipes start, so a mouse and a keyboard reach both.
class ConversationBubble extends ConsumerWidget {
  const ConversationBubble({
    super.key,
    required this.note,
    required this.mine,
    this.senderName,
    this.onQuote,
    this.timeOnly = false,
    this.onQuoteTap,
    this.onActions,
    this.marks = MessageMarks.none,
    this.onReact,
    this.mentions = const {},
    this.selfIds = const {},
  });

  /// #2216 — my member id, so a mention of me stands out.
  final Set<String> selfIds;

  /// Names of a group's members, for `@Name` highlighting (0383).
  final Set<String> mentions;

  final MemberNote note;

  /// Reactions, stars and edits of the thread (0382).
  final MessageMarks marks;
  final ValueChanged<String>? onReact;

  /// #1824 — forward, lock, "What happened": offered when the workspace
  /// has `messageForwarding` on. Null keeps the bubble as it was.
  final VoidCallback? onActions;
  final bool mine;

  /// #821 — the stamp shows the TIME alone; the thread's day separators
  /// carry the date.
  final bool timeOnly;

  /// #821 — tapping the quoted block scrolls to the original.
  final ValueChanged<String>? onQuoteTap;

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

  /// The message's actions, once, for the menu and the swipes alike.
  /// Quoting belongs to the gestures feature; deleting is always offered
  /// (both sides of a direct conversation may delete, the server
  /// re-checks); the forward/lock sheet is the last entry when offered.
  List<RowAction> _actions(BuildContext context, WidgetRef ref,
      {required bool gestures}) {
    final l10n = context.l10n;
    final quote = onQuote;
    final more = onActions;
    return [
      if (gestures && quote != null)
        RowAction(
          id: 'quote',
          label: l10n.memberNoteQuote,
          icon: Icons.format_quote_outlined,
          // recorder-key-exempt: the RowMenu keys this entry <keyPrefix>-<id>
          onSelected: () => quote(note),
        ),
      RowAction(
        id: 'delete',
        label: l10n.memberNoteDelete,
        icon: Icons.delete_outline,
        destructive: true,
        // recorder-key-exempt: the RowMenu keys this entry <keyPrefix>-<id>
        onSelected: () => deleteMemberNoteGuarded(context, ref, note),
      ),
      if (more != null)
        RowAction(
          id: 'actions',
          label: l10n.messengerMessageActions,
          icon: Icons.more_horiz,
          // recorder-key-exempt: the RowMenu keys this entry <keyPrefix>-<id>
          onSelected: more,
        ),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final gestures = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.messageGestures);
    final actions = _actions(context, ref, gestures: gestures);
    final bubble = _withMenu(context, actions, _bubble(context, ref, theme));
    if (!gestures) return bubble;
    RowAction? action(String id) =>
        actions.where((a) => a.id == id).firstOrNull;
    // parity: bubble-actions-
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
          await action('quote')?.onSelected();
          return false;
        }
        if (!_deletableUnread) {
          // Saying WHY beats a swipe that springs back for no visible
          // reason — the two causes are different and both actionable.
          AppSnack.info(
            context,
            mine
                ? (l10n.memberNoteDeleteRead)
                : (l10n.memberNoteDeleteNotMine),
            replace: true,
          );
          return false;
        }
        await action('delete')?.onSelected();
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

  /// #1824 — the ⋯ sits BESIDE the bubble, never inside it: the bubble's
  /// long press must not land on a button's tooltip. It shows at rest
  /// where the forward/lock sheet is offered, on hover and focus otherwise.
  Widget _withMenu(
          BuildContext context, List<RowAction> actions, Widget core) =>
      Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: RowMenu(
          actions: actions,
          keyPrefix: 'bubble-menu-${note.id}',
          buttonKey: ValueKey('bubble-actions-${note.id}'),
          tooltip: context.l10n.messengerMessageActions,
          button: onActions != null
              ? RowMenuButton.always
              : RowMenuButton.onHover,
          buttonFirst: mine,
          expand: false,
          focusable: true,
          fullTarget: true,
          child: core,
        ),
      );

  Widget _bubble(BuildContext context, WidgetRef ref, ThemeData theme) {
    final l10n = context.l10n;
    final when = timeOnly
        ? ref.watch(appFormatProvider).time(note.createdAt)
        : appFormatOf(context).datesAndTime(DateShape.monthDay, note.createdAt);
    final split = splitLeadingQuote(note.body);
    return KeyedSubtree(
        key: ValueKey('bubble-${note.id}'),
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
                    _QuotedBlock(
                      key: const ValueKey('conversation-bubble-quoted-block'),
                      quote: split.quote!,
                      foreground: fg,
                      onTap: onQuoteTap == null
                          ? null
                          : () => onQuoteTap!(split.quote!.id),
                    ),
                  if (note.forwardedFrom != null)
                    ForwardOriginLine(
                      key: ValueKey('forward-origin-${note.id}'),
                      origin: note.forwardedFrom!,
                      color: fgMuted,
                    ),
                  MemberNoteBody(
                    body: split.rest,
                    style: theme.textTheme.bodyMedium?.copyWith(color: fg),
                    linkColor: mine ? fg : null,
                    mentions: mentions,
                    selfIds: selfIds,
                  ),
                  ReactionStrip(
                    messageId: note.id,
                    reactions: marks.reactions[note.id] ?? const [],
                    onReact: onReact,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (marks.starred.contains(note.id))
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(Icons.star,
                              key: ValueKey('note-starred-${note.id}'),
                              size: 12,
                              color: fgMuted),
                        ),
                      if (marks.edited.contains(note.id))
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            l10n.messengerEdited,
                            key: ValueKey('note-edited-${note.id}'),
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: fgMuted),
                          ),
                        ),
                      if (note.noForward)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(Icons.lock_outline,
                              key: ValueKey('note-locked-${note.id}'),
                              size: 12,
                              color: fgMuted),
                        ),
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
      );
  }
}

/// The quoted message above a reply — a tinted block with the accent bar
/// every chat app uses, so a reply reads as a reply at a glance.
class _QuotedBlock extends StatelessWidget {
  const _QuotedBlock({
    super.key,
    required this.quote,
    required this.foreground,
    this.onTap,
  });

  final NoteQuoteRef quote;
  final Color foreground;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      key: const ValueKey('conversation-bubble-gesture-detector'),
      onTap: onTap,
      child: Container(
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
    ),
    );
  }
}
