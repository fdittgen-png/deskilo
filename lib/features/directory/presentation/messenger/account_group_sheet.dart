// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../domain/account_group.dart';
import '../../providers/directory_providers.dart';
import '../../providers/message_marks_providers.dart';
import '../../providers/messenger_providers.dart';
import 'refusal_text.dart';

/// A group of people (0384): who is in it, who runs it, and the ways in and
/// out. Everything is also enforced by the server; the sheet only hides what
/// it would refuse.
///
/// Answers `true` when the person left the group, so the thread behind the
/// sheet can close with it.
Future<bool?> showAccountGroupSheet(BuildContext context, String groupId) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _GroupSheet(groupId: groupId),
    );

class _GroupSheet extends ConsumerWidget {
  const _GroupSheet({required this.groupId});
  final String groupId;

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    String what,
    Future<void> Function() action,
  ) async {
    final l10n = AppLocalizations.of(context);
    await runMessenger(
      context,
      message: what,
      errorText: l10n?.portalActionFailed ??
          'Could not save this change. Please try again.',
      action: action,
    );
    ref
      ..invalidate(accountGroupInfoProvider(groupId))
      ..invalidate(accountGroupMembersProvider(groupId))
      ..invalidate(groupSharedWorkspacesProvider(groupId))
      ..invalidate(unifiedInboxProvider);
  }

  Future<String?> _ask(BuildContext context, String title, String initial,
      int maxLength, Key key, {int maxLines = 1}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: TextField(
          key: key,
          controller: controller,
          autofocus: true,
          maxLength: maxLength,
          maxLines: maxLines,
          minLines: 1,
        ),
        actions: [
          TextButton(
            key: const ValueKey('agroup-text-cancel'),
            onPressed: () => Navigator.of(dialog).pop(),
            child: Text(MaterialLocalizations.of(dialog).cancelButtonLabel),
          ),
          FilledButton(
            key: const ValueKey('agroup-text-save'),
            onPressed: () => Navigator.of(dialog).pop(controller.text),
            child: Text(MaterialLocalizations.of(dialog).okButtonLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _addPeople(BuildContext context, WidgetRef ref) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _PeoplePicker(),
    );
    if (picked == null || !context.mounted) return;
    await _run(context, ref, 'add group member failed',
        () => ref.read(messengerActionsProvider()).addGroupMember(groupId, picked));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final info = ref.watch(accountGroupInfoProvider(groupId)).value;
    final members = ref.watch(accountGroupMembersProvider(groupId)).value ?? const [];
    final admin = info?.iAmAdmin ?? false;
    final actions = ref.read(messengerActionsProvider());
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.lg, AppSpacing.md, AppSpacing.sm),
              child: Row(children: [
                const CircleAvatar(child: Icon(Icons.groups_outlined)),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(info?.title ?? '', style: theme.textTheme.titleMedium),
                      Text(l10n?.conversationMemberCount(members.length) ??
                          '${members.length} members',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                if (admin)
                  IconButton(
                    key: const ValueKey('agroup-rename'),
                    tooltip: l10n?.groupRename ?? 'Rename group',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () async {
                      final t = await _ask(context, l10n?.groupRenameTitle ?? 'Group name',
                          info?.title ?? '', 60, const ValueKey('agroup-rename-field'));
                      if (t == null || t.trim().isEmpty || !context.mounted) return;
                      await _run(context, ref, 'rename group failed',
                          () => actions.setGroupMeta(groupId, title: t));
                    },
                  ),
                IconButton(
                  key: const ValueKey('agroup-close'),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ]),
            ),
            if ((info?.description.isNotEmpty ?? false) || admin)
              ListTile(
                key: const ValueKey('agroup-description'),
                leading: const Icon(Icons.notes_outlined),
                title: Text((info?.description.isNotEmpty ?? false)
                    ? info!.description
                    : (l10n?.groupDescriptionAdd ?? 'Add a description')),
                onTap: admin
                    ? () async {
                        final t = await _ask(
                            context,
                            l10n?.groupDescriptionTitle ?? 'Group description',
                            info?.description ?? '',
                            500,
                            const ValueKey('agroup-description-field'),
                            maxLines: 5);
                        if (t == null || !context.mounted) return;
                        await _run(context, ref, 'group description failed',
                            () => actions.setGroupMeta(groupId, description: t));
                      }
                    : null,
              ),
            if (admin)
              SwitchListTile(
                key: const ValueKey('agroup-announce-only'),
                secondary: const Icon(Icons.campaign_outlined),
                title: Text(l10n?.groupAnnounceOnly ?? 'Only admins can post'),
                subtitle: Text(l10n?.groupAnnounceOnlyHint ??
                    'Everyone reads; only admins write.'),
                value: info?.announceOnly ?? false,
                onChanged: (v) => _run(context, ref, 'group announce failed',
                    () => actions.setGroupMeta(groupId, announceOnly: v)),
              ),
            if (admin)
              ListTile(
                key: const ValueKey('agroup-add-people'),
                leading: const Icon(Icons.person_add_outlined),
                title: Text(l10n?.conversationAddPeople ?? 'Add people'),
                onTap: () => _addPeople(context, ref),
              ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                children: [
                  for (final m in members)
                    ListTile(
                      key: ValueKey('agroup-member-${m.userId}'),
                      leading: CircleAvatar(
                        child: Text(m.name.isEmpty ? '?' : m.name.characters.first.toUpperCase()),
                      ),
                      title: Text(m.name),
                      subtitle: m.isAdmin ? Text(l10n?.conversationAdmin ?? 'Admin') : null,
                      trailing: admin && !_isMe(ref, m)
                          ? Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(
                                key: ValueKey('agroup-admin-${m.userId}'),
                                tooltip: m.isAdmin
                                    ? (l10n?.groupRemoveAdmin ?? 'Remove admin')
                                    : (l10n?.groupMakeAdmin ?? 'Make admin'),
                                icon: Icon(m.isAdmin ? Icons.shield : Icons.shield_outlined),
                                onPressed: () => _run(context, ref, 'group admin failed',
                                    () => actions.setGroupAdmin(groupId, m.userId, admin: !m.isAdmin)),
                              ),
                              TextButton(
                                key: ValueKey('agroup-remove-${m.userId}'),
                                onPressed: () => _run(context, ref, 'remove group member failed',
                                    () => actions.removeGroupMember(groupId, m.userId)),
                                child: Text(l10n?.conversationRemove ?? 'Remove'),
                              ),
                            ])
                          : null,
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: AppSpacing.lgAll,
              child: TextButton.icon(
                key: const ValueKey('agroup-leave'),
                icon: Icon(Icons.logout, color: theme.colorScheme.error),
                label: Text(l10n?.conversationLeave ?? 'Leave group',
                    style: TextStyle(color: theme.colorScheme.error)),
                onPressed: () async {
                  final go = await showDialog<bool>(
                    context: context,
                    builder: (dialog) => AlertDialog(
                      title: Text(l10n?.conversationLeave ?? 'Leave group'),
                      content: Text(l10n?.conversationLeaveConfirm ??
                          'Leave this group? You stop receiving its messages; what you already sent stays.'),
                      actions: [
                        TextButton(
                          key: const ValueKey('agroup-leave-cancel'),
                          onPressed: () => Navigator.of(dialog).pop(false),
                          child: Text(l10n?.commonCancel ?? 'Cancel'),
                        ),
                        FilledButton(
                          key: const ValueKey('agroup-leave-confirm'),
                          onPressed: () => Navigator.of(dialog).pop(true),
                          child: Text(l10n?.conversationLeave ?? 'Leave group'),
                        ),
                      ],
                    ),
                  );
                  if (go != true || !context.mounted) return;
                  await _run(context, ref, 'leave group failed',
                      () => actions.leaveGroup(groupId));
                  if (context.mounted) Navigator.of(context).pop(true);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Whether a roster row is me: the roster names no ids of mine, so the
  /// sheet compares against the person the account answers as.
  bool _isMe(WidgetRef ref, GroupMember m) => m.userId == ref.read(authStateProvider).value;
}

/// Picks one person among those who can be found (`accountContacts`).
class _PeoplePicker extends ConsumerStatefulWidget {
  const _PeoplePicker();

  @override
  ConsumerState<_PeoplePicker> createState() => _PeoplePickerState();
}

class _PeoplePickerState extends ConsumerState<_PeoplePicker> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final results = _query.isEmpty
        ? const AsyncData<List<Map<String, dynamic>>>([])
        : ref.watch(accountContactsProvider(_query));
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('people-picker-search'),
              controller: _search,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n?.portalFindPeople ?? 'Find available people',
                suffixIcon: IconButton(
                  key: const ValueKey('people-picker-go'),
                  tooltip: l10n?.portalFindPeople ?? 'Find available people',
                  icon: const Icon(Icons.search),
                  onPressed: () => setState(() => _query = _search.text.trim()),
                ),
              ),
              onSubmitted: (v) => setState(() => _query = v.trim()),
            ),
            Flexible(
              child: switch (results) {
                AsyncData(value: final people) => ListView(
                    shrinkWrap: true,
                    children: [
                      for (final p in people)
                        ListTile(
                          key: ValueKey('people-picker-${p['id']}'),
                          leading: const Icon(Icons.person_outline),
                          title: Text('${p['name'] ?? ''}'),
                          onTap: () => Navigator.of(context).pop('${p['id']}'),
                        ),
                    ],
                  ),
                _ => const SizedBox.shrink(),
              },
            ),
          ],
        ),
      ),
    );
  }
}
