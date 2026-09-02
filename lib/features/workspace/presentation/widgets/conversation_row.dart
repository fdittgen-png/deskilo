// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';

import '../../domain/conversation.dart';
import '../../domain/member_note_refs.dart';
import 'conversation_avatar.dart';

/// One row of the conversation list (#687) — the WhatsApp shape the
/// owner asked for: avatar, name, last-message preview, time, unread
/// count.
///
/// WHAT THE PREVIEW MUST NOT DO. It is one line of someone's private
/// message rendered on a list that is often on screen while other people
/// are in the room, so it renders as PLAIN TEXT: reference links are not
/// resolved, emoji are not enlarged, nothing is tappable. The thread is
/// where a message is read; this is only enough to recognise it.
class ConversationRow extends ConsumerWidget {
  const ConversationRow({
    super.key,
    required this.conversation,
    required this.myMemberId,
    required this.names,
    required this.now,
    required this.onTap,
    this.onLongPress,
  });

  /// #821 — the row's menu (pin, mute, mark unread, archive).
  final VoidCallback? onLongPress;

  final Conversation conversation;
  final String? myMemberId;

  /// member id → display name. A direct thread has no title of its own:
  /// it is titled by the other person, whose name is theirs to change.
  final Map<String, String> names;

  /// Read once by the list, not per row — twenty rows asking the clock
  /// separately can straddle a minute and render two different "now"s.
  final DateTime now;

  final VoidCallback onTap;

  String _title(AppLocalizations? l10n) {
    if (conversation.isGroup) {
      return conversation.title ?? (l10n?.conversationGroup ?? 'Group');
    }
    final other = conversation.otherMemberId;
    return (other == null ? null : names[other]) ??
        (l10n?.conversationUnknownMember ?? 'Member');
  }

  /// Relative, and coarse on purpose: a conversation list is scanned, not
  /// read. WhatsApp's own scale — a time today, "yesterday", then a date.
  String _stamp(AppLocalizations? l10n) {
    final at = conversation.lastAt.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(at.year, at.month, at.day);
    if (day == today) return DateFormat.Hm().format(at);
    if (day == today.subtract(const Duration(days: 1))) {
      return l10n?.conversationYesterday ?? 'Yesterday';
    }
    return DateFormat.yMd().format(at);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final title = _title(l10n);
    final unread = conversation.unread;

    return ListTile(
      key: ValueKey('conversation-${conversation.id}'),
      leading: conversation.isGroup
          ? ConversationAvatar(
              conversationId: conversation.id,
              title: title,
              avatarPath: conversation.avatarPath,
            )
          : _DirectAvatar(
              memberId: conversation.otherMemberId,
              name: title,
            ),
      title: Row(children: [
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: unread > 0
                ? const TextStyle(fontWeight: FontWeight.w600)
                : null,
          ),
        ),
        // #821 — my pin and my mute, on the row.
        if (conversation.isPinned)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(Icons.push_pin,
                key: ValueKey('conversation-pinned-${conversation.id}'),
                size: 14,
                color: theme.colorScheme.primary),
          ),
        if (conversation.muted)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(Icons.notifications_off_outlined,
                key: ValueKey('conversation-muted-${conversation.id}'),
                size: 14,
                color: theme.colorScheme.onSurfaceVariant),
          ),
      ]),
      subtitle: Row(children: [
        // #694 — a group with NOTHING said in it has no preview to
        // distinguish it, so the row says what it is. "3 members" is
        // also the fact someone wants first when two groups have
        // similar names.
        if (conversation.isGroup && conversation.lastBody.isEmpty)
          Text(
            l10n?.conversationMemberCount(conversation.participantCount) ??
                '${conversation.participantCount} members',
            style: theme.textTheme.bodySmall,
          ),
        // A group preview says WHO wrote, because "ok" from an unnamed
        // someone in a group of eight is not a preview of anything.
        if (conversation.isGroup && conversation.lastFromMemberId != null)
          Text(
            '${conversation.sentByMe(myMemberId) ? (l10n?.conversationYou ?? 'You') : names[conversation.lastFromMemberId] ?? ''}: ',
            style: theme.textTheme.bodySmall,
          ),
        Expanded(
          child: Text(
            // LABELS, never raw tokens. `[res:res-1|Desk A1]` in a list
            // row is markup leaking into someone's inbox — the old
            // events inbox already stripped it and the new row must too.
            notePlainText(conversation.lastBody),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ),
      ]),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(_stamp(l10n), style: theme.textTheme.labelSmall),
          const SizedBox(height: 4),
          if (unread > 0)
            Badge(
              key: ValueKey('conversation-unread-${conversation.id}'),
              // Capped: past 99 the exact number tells nobody anything
              // and the badge starts pushing the timestamp off the row.
              label: Text(unread > 99 ? '99+' : '$unread'),
            )
          else
            const SizedBox(height: 16),
        ],
      ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

/// A direct thread's avatar: the other member's photo.
///
/// Its own widget because [MemberAvatar] keys on the auth USER id while a
/// conversation carries a MEMBER id, and the lookup that bridges them
/// should happen once here rather than in every caller.
class _DirectAvatar extends ConsumerWidget {
  const _DirectAvatar({required this.memberId, required this.name});

  final String? memberId;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = memberId;
    if (id == null) {
      return CircleAvatar(child: Text(name.isEmpty ? '?' : name[0]));
    }
    return MemberAvatarByMember(memberId: id, name: name);
  }
}
