// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../domain/conversation.dart';
import '../../domain/member.dart';
import '../../../members/presentation/member_profile_link.dart';
import '../../providers/conversation_providers.dart';
import '../../providers/workspace_providers.dart';
import 'conversation_avatar.dart';

/// A group's roster (#687): who is in it, who runs it, and the ways in
/// and out.
///
/// Every action here is ALSO enforced server-side (0126), and the sheet
/// only hides what the server would refuse. Showing an admin control to
/// someone who cannot use it produces a tap, a refusal and no
/// explanation; hiding it is the explanation.
Future<void> showGroupInfoSheet(
  BuildContext context,
  WidgetRef ref, {
  required Conversation conversation,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _GroupInfoSheet(conversation: conversation),
    );

class _GroupInfoSheet extends ConsumerWidget {
  const _GroupInfoSheet({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final names = ref.watch(memberNamesProvider).value ?? const {};
    final myMemberId = ref.watch(myMemberProvider).value?.id;
    final roster =
        ref.watch(conversationParticipantsProvider(conversation.id)).value ??
            const <ConversationParticipant>[];
    final iAmAdmin = roster
        .any((p) => p.memberId == myMemberId && p.isAdmin && p.isActive);
    // Left participants are listed LAST and dimmed rather than dropped:
    // their messages are still in the thread above, and a name with no
    // row is a name nobody can place.
    final ordered = [
      for (final p in roster) if (p.isActive) p,
      for (final p in roster) if (!p.isActive) p,
    ];

    final media = MediaQuery.of(context);
    return SafeArea(
      child: SizedBox(
        height: media.size.height * 0.7,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.sm,
            ),
            child: Row(children: [
              ConversationAvatar(
                conversationId: conversation.id,
                title: conversation.title ?? '',
                avatarPath: conversation.avatarPath,
                radius: 24,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      conversation.title ??
                          (l10n?.conversationGroupInfo ?? 'Group'),
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      l10n?.conversationMemberCount(
                            ordered.where((p) => p.isActive).length,
                          ) ??
                          '${ordered.length} members',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ]),
          ),
          if (iAmAdmin)
            ListTile(
              key: const ValueKey('group-add-people'),
              leading: const Icon(Icons.person_add_outlined),
              title: Text(l10n?.conversationAddPeople ?? 'Add people'),
              onTap: () => _addPeople(context, ref, roster),
            ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: ordered.length,
              itemBuilder: (context, index) {
                final p = ordered[index];
                final name = names[p.memberId] ?? '';
                return Opacity(
                  opacity: p.isActive ? 1 : 0.5,
                  child: ListTile(
                    key: ValueKey('group-member-${p.memberId}'),
                    leading:
                        MemberAvatarByMember(memberId: p.memberId, name: name),
                    title: Text(name),
                    // #695 — the roster is a list of people, so tapping
                    // one shows the person: their reservations, whether
                    // they are checked in right now, how to reach them.
                    onTap: () => openMemberProfile(
                      context,
                      ref,
                      memberId: p.memberId,
                    ),
                    subtitle: !p.isActive
                        ? Text(l10n?.conversationLeft ?? 'Left')
                        : p.isAdmin
                            ? Text(l10n?.conversationAdmin ?? 'Admin')
                            : null,
                    // An admin cannot remove THEMSELVES here — that is
                    // leaving, and leaving carries the last-admin rule.
                    trailing: iAmAdmin &&
                            p.isActive &&
                            p.memberId != myMemberId
                        ? TextButton(
                            key: ValueKey('group-remove-${p.memberId}'),
                            onPressed: () => _remove(context, ref, p.memberId),
                            child:
                                Text(l10n?.conversationRemove ?? 'Remove'),
                          )
                        : null,
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: AppSpacing.lgAll,
            child: TextButton.icon(
              key: const ValueKey('group-leave'),
              onPressed: () => _leave(context, ref),
              icon: Icon(Icons.logout, color: theme.colorScheme.error),
              label: Text(
                l10n?.conversationLeave ?? 'Leave group',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _addPeople(
    BuildContext context,
    WidgetRef ref,
    List<ConversationParticipant> roster,
  ) async {
    final l10n = AppLocalizations.of(context);
    final names = ref.read(memberNamesProvider).value ?? const {};
    final present = {for (final p in roster) if (p.isActive) p.memberId};
    final candidates = [
      for (final m
          in ref.read(workspaceMembersProvider).value ?? const <Member>[])
        if (m.status == MemberStatus.active &&
            !m.isKiosk &&
            !present.contains(m.id))
          m,
    ]..sort((a, b) => (names[a.id] ?? '').compareTo(names[b.id] ?? ''));

    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: candidates.isEmpty
            // Everyone is already in. Saying so beats an empty list that
            // reads as a loading failure.
            ? Padding(
                padding: AppSpacing.lgAll,
                child: Text(
                  l10n?.newConversationNoMembers ?? 'Nobody else here yet.',
                ),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final m in candidates)
                    ListTile(
                      key: ValueKey('group-add-${m.id}'),
                      leading: MemberAvatarByMember(
                        memberId: m.id,
                        name: names[m.id] ?? '',
                      ),
                      title: Text(names[m.id] ?? ''),
                      onTap: () => Navigator.of(context).pop(m.id),
                    ),
                ],
              ),
      ),
    );
    if (picked == null || !context.mounted) return;
    await runGuarded(
      context,
      domain: 'workspace',
      message: 'add participant failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () => ref
          .read(workspaceRepositoryProvider)
          .addParticipant(conversation.id, picked),
    );
    _refresh(ref);
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    String memberId,
  ) async {
    final l10n = AppLocalizations.of(context);
    await runGuarded(
      context,
      domain: 'workspace',
      message: 'remove participant failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () => ref
          .read(workspaceRepositoryProvider)
          .removeParticipant(conversation.id, memberId),
    );
    _refresh(ref);
  }

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    // Confirmed, like every other irreversible-feeling action here, and
    // the wording says what actually HAPPENS: "leave" alone reads like
    // it might delete the group for everyone.
    final go = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n?.conversationLeave ?? 'Leave group'),
        content: Text(
          l10n?.conversationLeaveConfirm ??
              'Leave this group? You stop receiving its messages; what '
                  'you already sent stays.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n?.commonCancel ?? 'Cancel'),
          ),
          FilledButton(
            key: const ValueKey('group-leave-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n?.conversationLeave ?? 'Leave group'),
          ),
        ],
      ),
    );
    if (go != true || !context.mounted) return;
    await runGuarded(
      context,
      domain: 'workspace',
      message: 'leave conversation failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () => ref
          .read(workspaceRepositoryProvider)
          .leaveConversation(conversation.id),
    );
    if (!context.mounted) return;
    _refresh(ref);
    // Out of the sheet AND out of the thread behind it: staying in a
    // conversation you just left is a screen that cannot refresh.
    Navigator.of(context)
      ..pop()
      ..pop();
  }

  void _refresh(WidgetRef ref) => ref
    ..invalidate(conversationParticipantsProvider(conversation.id))
    ..invalidate(conversationsProvider);
}
