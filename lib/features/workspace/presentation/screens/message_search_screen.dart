// SPDX-License-Identifier: 0BSD
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../domain/conversation.dart';
import '../../domain/member.dart';
import '../../domain/member_note.dart';
import '../../providers/conversation_providers.dart';
import '../../providers/workspace_providers.dart';
import '../widgets/conversation_avatar.dart';
import '../widgets/conversation_thread.dart';

/// Searching the messaging centre (#687): people, groups and message
/// text in one field.
///
/// ONE field, three kinds of answer, because "find that thing about the
/// invoice" and "find Alex" are the same impulse and nobody wants to
/// choose a category first. Results are grouped and labelled so the
/// three never blur: a person opens their thread, a group opens the
/// group, a message opens the conversation it is in.
///
/// The message half runs on the 0125 full-text index with a PREFIX
/// query — nobody finishes a word before expecting results.
class MessageSearchScreen extends ConsumerStatefulWidget {
  const MessageSearchScreen({super.key});

  @override
  ConsumerState<MessageSearchScreen> createState() =>
      _MessageSearchScreenState();
}

class _MessageSearchScreenState extends ConsumerState<MessageSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  /// What the SERVER is asked. Separate from the field's text so every
  /// keystroke does not become a query: the field updates instantly, the
  /// search follows once typing pauses.
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    // People and groups filter locally and instantly — they are already
    // in memory. Only the message search waits.
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final typed = _controller.text.trim().toLowerCase();
    final names = ref.watch(memberNamesProvider).value ?? const {};
    final me = ref.watch(myMemberProvider).value;
    final conversations = ref.watch(conversationsProvider).value ?? const [];

    final people = typed.isEmpty
        ? const <Member>[]
        : [
            for (final m
                in ref.watch(workspaceMembersProvider).value ?? const <Member>[])
              if (m.id != me?.id &&
                  m.status == MemberStatus.active &&
                  !m.isKiosk &&
                  (names[m.id] ?? '').toLowerCase().contains(typed))
                m,
          ];
    final groups = typed.isEmpty
        ? const <Conversation>[]
        : [
            for (final c in conversations)
              if (c.isGroup && (c.title ?? '').toLowerCase().contains(typed))
                c,
          ];
    final messages = _query.isEmpty
        ? const <MemberNote>[]
        : ref.watch(messageSearchProvider(_query)).value ?? const <MemberNote>[];

    final nothing =
        typed.isNotEmpty && people.isEmpty && groups.isEmpty && messages.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          key: const ValueKey('message-search-field'),
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: l10n?.messageSearchHint ?? 'People, groups, messages',
            border: InputBorder.none,
          ),
        ),
      ),
      body: typed.isEmpty
          ? Center(
              child: Padding(
                padding: AppSpacing.lgAll,
                child: Text(
                  l10n?.messageSearchPrompt ??
                      'Search people, groups and what was said.',
                  key: const ValueKey('message-search-prompt'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            )
          : nothing
              ? Center(
                  child: Text(
                    l10n?.messageSearchNothing ?? 'Nothing matched.',
                    key: const ValueKey('message-search-nothing'),
                    style: theme.textTheme.bodySmall,
                  ),
                )
              : ListView(
                  key: const ValueKey('message-search-results'),
                  children: [
                    if (people.isNotEmpty)
                      _header(l10n?.messageSearchPeople ?? 'People'),
                    for (final m in people)
                      ListTile(
                        key: ValueKey('search-person-${m.id}'),
                        leading: MemberAvatarByMember(
                          memberId: m.id,
                          name: names[m.id] ?? '',
                        ),
                        title: Text(names[m.id] ?? ''),
                        onTap: () => _openWith(m.id),
                      ),
                    if (groups.isNotEmpty)
                      _header(l10n?.messageSearchGroups ?? 'Groups'),
                    for (final c in groups)
                      ListTile(
                        key: ValueKey('search-group-${c.id}'),
                        leading: ConversationAvatar(
                          conversationId: c.id,
                          title: c.title ?? '',
                          avatarPath: c.avatarPath,
                        ),
                        title: Text(c.title ?? ''),
                        subtitle: Text(
                          l10n?.conversationMemberCount(c.participantCount) ??
                              '${c.participantCount} members',
                        ),
                        onTap: () => _openConversation(c.id),
                      ),
                    if (messages.isNotEmpty)
                      _header(l10n?.messageSearchMessages ?? 'Messages'),
                    for (final note in messages)
                      ListTile(
                        key: ValueKey('search-message-${note.id}'),
                        leading: const Icon(Icons.chat_bubble_outline),
                        title: Text(
                          note.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${names[note.fromMemberId] ?? ''} · '
                          '${DateFormat.yMMMd().format(note.createdAt.toLocal())}',
                        ),
                        // A message with no conversation is a pre-0125
                        // note or an admin broadcast — it has no thread
                        // to open, and a dead tap is worse than none.
                        enabled: note.conversationId != null,
                        onTap: note.conversationId == null
                            ? null
                            : () => _openConversation(note.conversationId!),
                      ),
                  ],
                ),
    );
  }

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xs,
        ),
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: Theme.of(context).colorScheme.primary),
        ),
      );

  /// A PERSON opens the thread with them, creating it if this is the
  /// first word — which is the whole point of finding them here.
  Future<void> _openWith(String memberId) async {
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final id = await ref
        .read(workspaceRepositoryProvider)
        .openDirectConversation(workspace.id, otherMemberId: memberId);
    if (!mounted) return;
    await _openConversation(id);
  }

  Future<void> _openConversation(String conversationId) async {
    await showConversationThread(context, ref, conversationId: conversationId);
    if (mounted) ref.invalidate(conversationsProvider);
  }
}
