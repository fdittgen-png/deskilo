// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../domain/conversation.dart';
import '../../domain/member.dart';
import '../../providers/conversation_providers.dart';
import '../../providers/workspace_providers.dart';
import 'conversation_avatar.dart';

/// Starting a conversation (#687).
///
/// The messaging centre had no way to begin one: its empty state pointed
/// at a member's profile on another screen, which is the app telling
/// someone to leave the screen they opened for exactly this.
///
/// One sheet for both kinds, because "who do I want to talk to" is one
/// question. Picking a person opens their thread; picking several names
/// a group. WhatsApp splits these into two entries — here they are one
/// list with a checkbox, which is fewer taps for the common case and
/// still obvious for the rarer one.
/// Returns the conversation that was started, or null if nothing was.
///
/// The caller OPENS it. Closing the sheet and leaving someone on the
/// list is what made "Démarrer" look like it had done nothing — a
/// message-less thread has nothing to show on a row, so the only
/// evidence of success was invisible.
Future<String?> showNewConversationSheet(
  BuildContext context,
  WidgetRef ref,
) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _NewConversationSheet(),
    );

class _NewConversationSheet extends ConsumerStatefulWidget {
  const _NewConversationSheet();

  @override
  ConsumerState<_NewConversationSheet> createState() =>
      _NewConversationSheetState();
}

class _NewConversationSheetState
    extends ConsumerState<_NewConversationSheet> {
  final _selected = <String>{};
  final _search = TextEditingController();
  final _groupName = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _search.dispose();
    _groupName.dispose();
    super.dispose();
  }

  /// A group needs a name; a one-to-one thread is titled by the person.
  bool get _isGroup => _selected.length > 1;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final me = ref.watch(myMemberProvider).value;
    final names = ref.watch(memberNamesProvider).value ?? const {};
    final query = _search.text.trim().toLowerCase();
    final members = [
      for (final m in ref.watch(workspaceMembersProvider).value ?? const <Member>[])
        // Never myself, never a kiosk: a kiosk is a shared tablet, not
        // someone to write to.
        if (m.id != me?.id && m.status == MemberStatus.active && !m.isKiosk)
          if (query.isEmpty ||
              (names[m.id] ?? '').toLowerCase().contains(query))
            m,
    ]..sort((a, b) => (names[a.id] ?? '').compareTo(names[b.id] ?? ''));

    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        child: SizedBox(
          height: (media.size.height - media.viewInsets.bottom) * 0.8,
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
                  child: Text(
                    l10n?.newConversationTitle ?? 'New conversation',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ]),
            ),
            Padding(
              padding: AppSpacing.lgH,
              child: TextField(
                key: const ValueKey('new-conversation-search'),
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n?.newConversationSearch ?? 'Search members',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            // The name field appears only once it is needed. Asking for a
            // group name before anyone has picked two people is a field
            // that means nothing yet.
            if (_isGroup)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  0,
                ),
                child: TextField(
                  key: const ValueKey('new-group-name'),
                  controller: _groupName,
                  onChanged: (_) => setState(() {}),
                  maxLength: ConversationRules.maxTitleLength,
                  decoration: InputDecoration(
                    labelText: l10n?.newGroupName ?? 'Group name',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            Expanded(
              child: members.isEmpty
                  ? Center(
                      child: Text(
                        l10n?.newConversationNoMembers ??
                            'Nobody else here yet.',
                        key: const ValueKey('new-conversation-empty'),
                        style: theme.textTheme.bodySmall,
                      ),
                    )
                  : ListView.builder(
                      itemCount: members.length,
                      itemBuilder: (context, index) {
                        final m = members[index];
                        final name = names[m.id] ?? '';
                        return CheckboxListTile(
                          key: ValueKey('new-conversation-${m.id}'),
                          value: _selected.contains(m.id),
                          onChanged: _busy
                              ? null
                              : (on) => setState(() {
                                    if (on ?? false) {
                                      _selected.add(m.id);
                                    } else {
                                      _selected.remove(m.id);
                                    }
                                  }),
                          secondary:
                              MemberAvatarByMember(memberId: m.id, name: name),
                          title: Text(name),
                        );
                      },
                    ),
            ),
            Padding(
              padding: AppSpacing.lgAll,
              child: FilledButton(
                key: const ValueKey('new-conversation-start'),
                onPressed: _canStart ? _start : null,
                child: Text(
                  _isGroup
                      ? (l10n?.newGroupCreate ?? 'Create group')
                      : (l10n?.newConversationStart ?? 'Start chat'),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  /// Disabled until the choice is complete: one person, or two-plus AND a
  /// name. A button that fails on tap teaches nothing about why.
  bool get _canStart =>
      !_busy &&
      _selected.isNotEmpty &&
      (!_isGroup || _groupName.text.trim().isNotEmpty);

  Future<void> _start() async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    setState(() => _busy = true);
    final repo = ref.read(workspaceRepositoryProvider);
    String id;
    try {
      id = _isGroup
          ? await repo.createGroupConversation(
              workspace.id,
              title: _groupName.text.trim(),
              memberIds: _selected.toList(),
            )
          : await repo.openDirectConversation(
              workspace.id,
              otherMemberId: _selected.single,
            );
    } catch (e, st) {
      TraceLogger.instance.error(
        'messaging',
        'start conversation failed',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      // #694 — a name that is simply TAKEN is not "something went
      // wrong": it is one word to change, and saying so is the whole
      // difference between a dead end and a correction. The server pins
      // the substring; runGuarded could not be used here because it
      // resolves its message before the action runs.
      final taken = '$e'.contains('a group with that name already exists');
      AppSnack.error(
        context,
        taken
            ? (l10n?.newGroupNameTaken ??
                'A group with that name already exists here. Pick another.')
            : (l10n?.workspaceGenericError ??
                'Something went wrong. Please try again.'),
        replace: true,
      );
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    // The list behind is stale the moment a thread exists.
    ref.invalidate(conversationsProvider);
    Navigator.of(context).pop(id);
  }
}
