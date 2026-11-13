// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3628 — roles from the members' table, as short tasks:
//   * one member: the member's role card (member_roles_card.dart), the one
//     place a role is given or taken back, with its refusals said in words;
//   * a selection: one of the space's own roles given to each member, each
//     checked on their own with the same rule as one (`customRoleRefusal`)
//     and given through the same command; a member who cannot be given it is
//     listed with the reason and left as they were.
// Nothing here changes what a role may do.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/context_l10n.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/trace/trace_logger.dart';
import '../../core/ui/adaptive/task_choice.dart';
import '../../core/ui/adaptive/task_surface.dart';
import '../../features/workspace/domain/member.dart';
import '../../features/workspace/domain/role_assignment.dart';
import '../../features/workspace/domain/workspace_role.dart';
import '../../features/workspace/presentation/widgets/member_roles_card.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import '../../features/workspace/providers/workspace_roles_providers.dart';

/// [member]'s roles as a short task: the role card with its actions.
Future<void> showMemberRolesTask(
  BuildContext context, {
  required Member member,
  required String name,
}) => showTask<void>(
  context,
  size: TaskSize.short,
  builder: (taskContext) => TaskChoice(
    title: name,
    content: MemberRolesCard(member: member, name: name),
    actions: [
      FilledButton(
        key: const ValueKey('member-roles-task-close'),
        onPressed: () => Navigator.of(taskContext).pop(),
        child: Text(taskContext.l10n.commonClose),
      ),
    ],
  ),
);

/// One of the space's own roles given to each of [members].
Future<void> showGiveRoleTask(
  BuildContext context, {
  required List<Member> members,
}) => showTask<void>(
  context,
  size: TaskSize.short,
  builder: (_) => _GiveRole(members: members),
);

/// What became of one member: given, already held, refused (with why), or
/// failed (the server refused or did not answer).
typedef _Outcome = ({bool given, bool held, RoleRefusal? refusal, bool failed});

class _GiveRole extends ConsumerStatefulWidget {
  const _GiveRole({required this.members});

  final List<Member> members;

  @override
  ConsumerState<_GiveRole> createState() => _GiveRoleState();
}

class _GiveRoleState extends ConsumerState<_GiveRole> {
  WorkspaceRole? _role;
  bool _running = false;
  Map<String, _Outcome>? _outcomes;

  Future<void> _apply(WorkspaceRole role) async {
    final me = ref.read(myMemberProvider).value;
    if (me == null) return;
    setState(() => _running = true);
    final perms = ref.read(myPermissionsProvider);
    final repository = ref.read(workspaceRolesRepositoryProvider);
    // Read again now: the rule is checked on what the space holds.
    final assignments = await ref.refresh(
      workspaceRoleAssignmentsProvider.future,
    );
    final members = {
      for (final m in await ref.refresh(workspaceMembersProvider.future))
        m.id: m,
    };
    final outcomes = <String, _Outcome>{};
    for (final selected in widget.members) {
      final subject = members[selected.id] ?? selected;
      if (assignments[subject.id]?.contains(role.id) ?? false) {
        outcomes[subject.id] = (
          given: false,
          held: true,
          refusal: null,
          failed: false,
        );
        continue;
      }
      final refusal = customRoleRefusal(
        caller: me,
        callerPermissions: perms,
        subject: subject,
        role: role,
      );
      if (refusal != null) {
        outcomes[subject.id] = (
          given: false,
          held: false,
          refusal: refusal,
          failed: false,
        );
        continue;
      }
      try {
        await repository.assignRole(
          memberId: subject.id,
          roleId: role.id,
          assign: true,
        );
        outcomes[subject.id] = (
          given: true,
          held: false,
          refusal: null,
          failed: false,
        );
      } on Object catch (e, st) {
        TraceLogger.instance.warn(
          'workspace',
          'a role was not given to a member of a selection',
          error: e,
          stackTrace: st,
        );
        outcomes[subject.id] = (
          given: false,
          held: false,
          refusal: null,
          failed: true,
        );
      }
    }
    if (!mounted) return;
    ref.invalidate(workspaceRoleAssignmentsProvider);
    setState(() {
      _running = false;
      _outcomes = outcomes;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).languageCode;
    final names = ref.watch(memberNamesProvider).value ?? const {}; // empty-ok: an unread name shows blank, the outcome still shows
    final roles = [
      for (final r in orderedRoles(
        ref.watch(workspaceRolesProvider).value ??
            const <
              WorkspaceRole
            >[], // empty-ok: no role is offered before they are read
      ))
        if (r.active && !r.builtin) r,
    ];
    final outcomes = _outcomes;
    final role = _role;
    String said(_Outcome o) => switch (o) {
      (given: true, held: _, refusal: _, failed: _) => l.membersRoleGiven,
      (held: true, given: _, refusal: _, failed: _) => l.membersRoleHeld,
      (refusal: final r?, given: _, held: _, failed: _) => roleRefusalText(
        l,
        r,
      ),
      _ => l.membersOutcomeFailed,
    };
    return TaskChoice(
      title: l.membersBulkGiveRole(widget.members.length),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (outcomes == null) ...[
            Text(l.membersGiveRoleChoose),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final r in roles)
                  ChoiceChip(
                    key: ValueKey('give-role-${r.key}'),
                    label: Text(r.nameIn(locale)),
                    selected: role?.id == r.id,
                    onSelected: (_) => setState(() => _role = r),
                  ),
              ],
            ),
          ] else
            for (final m in widget.members)
              ListTile(
                key: ValueKey('give-role-outcome-${m.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text(names[m.id] ?? ''),
                subtitle: Text(said(outcomes[m.id]!)),
              ),
        ],
      ),
      actions: [
        if (outcomes == null) ...[
          TextButton(
            key: const ValueKey('give-role-cancel'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            key: const ValueKey('give-role-apply'),
            onPressed: role == null || _running ? null : () => _apply(role),
            child: Text(l.membersChangeApply),
          ),
        ] else
          FilledButton(
            key: const ValueKey('give-role-close'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.commonClose),
          ),
      ],
    );
  }
}
