// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2085 — the third place a role is given: the invitation.
//
// Whoever invites a new member may choose which of the workspace's own
// roles the person holds when they arrive. The roles are given by the
// server when the membership becomes active (`set_invitation_roles`,
// 0356), asking the inviter's authority again on that day. Here, a role
// the inviter may not give is shown disabled, with the reason.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/role_assignment.dart';
import '../../domain/workspace_role.dart';
import '../../providers/workspace_providers.dart';
import '../../providers/workspace_roles_providers.dart';
import 'member_roles_card.dart';

class InviteRolesPicker extends ConsumerWidget {
  const InviteRolesPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  static Key chipKeyFor(String roleKey) => ValueKey('invite-role-$roleKey');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final me = ref.watch(myMemberProvider).value;
    final perms = ref.watch(myPermissionsProvider);
    final roles =
        ref.watch(workspaceRolesProvider).value ?? const <WorkspaceRole>[];
    final locale = Localizations.localeOf(context).languageCode;
    final offered = [
      for (final role in orderedRoles(roles))
        if (!role.builtin && role.active) role,
    ];
    if (me == null || offered.isEmpty) return const SizedBox.shrink();
    final reasons = <String>{};
    final chips = <Widget>[];
    for (final role in offered) {
      final refusal = inviteRoleRefusal(
        caller: me,
        callerPermissions: perms,
        role: role,
      );
      if (refusal != null) reasons.add(roleRefusalText(l10n, refusal));
      chips.add(
        FilterChip(
          key: chipKeyFor(role.key),
          label: Text(role.nameIn(locale)),
          selected: selected.contains(role.key),
          onSelected: refusal != null
              ? null
              : (on) => onChanged(
                  on
                      ? {...selected, role.key}
                      : ({...selected}..remove(role.key)),
                ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n?.inviteRolesTitle ?? 'Roles on arrival',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: chips,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n?.inviteRolesHint ??
              'Given when they join, once their membership is active.',
          style: theme.textTheme.bodySmall,
        ),
        for (final reason in reasons)
          Text(reason, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
