// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2085 — the one place a member is given a role.
//
// Everyone in a workspace is a member; what they can do beyond that comes
// from their roles. This card shows them as chips on the member's page:
//
//   * ownership first (owner, co-owner, successor), which is not a role
//     and is never removed here;
//   * the built-in Administrator role, which goes through the validation
//     quorum (`request_role_change`, 0035) in both directions;
//   * the workspace's own roles, which take effect at once
//     (`assign_workspace_role`, 0247).
//
// "Add a role" lists every role with what giving it means, or why it
// cannot be given. The refusals are the ones the server raises, asked
// first, so a person meets a reason rather than an error. Nobody gives a
// role to themselves.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/assign_role.dart';
import '../../domain/member.dart';
import '../../domain/role_assignment.dart';
import '../../domain/workspace_permission.dart';
import '../../domain/workspace_role.dart';
import '../../providers/workspace_providers.dart';
import '../../providers/workspace_roles_providers.dart';
import '../member_admin_actions.dart';
import '../member_labels.dart';
import '../screens/roles_screen_labels.dart';

/// The sentence a person reads for [refusal].
String roleRefusalText(AppLocalizations? l10n, RoleRefusal refusal) =>
    switch (refusal) {
      RoleRefusal.yourself =>
        l10n?.roleEditorNotYourself ?? 'You cannot give a role to yourself.',
      RoleRefusal.notPermitted => l10n?.roleRefusalNotPermitted ??
          'Only someone who manages roles can give this one.',
      RoleRefusal.ownerOnly => l10n?.roleRefusalOwnerOnly ??
          'Only the owner gives a role that manages roles.',
      RoleRefusal.exceedsYours => l10n?.roleRefusalExceedsYours ??
          'This role can do things you cannot, so only the owner gives it.',
      RoleRefusal.notAssignable => l10n?.roleRefusalNotAssignable ??
          'This member cannot hold this role.',
    };

/// Whether [caller] may give anybody any role at all: the owner asks for
/// the Administrator role, manageRoles gives the workspace's own roles.
bool canGiveRoles(Member? caller, Set<WorkspacePermission> permissions) =>
    caller != null &&
    (caller.actsAsOwner ||
        permissions.contains(WorkspacePermission.manageRoles));

class MemberRolesCard extends ConsumerWidget {
  const MemberRolesCard({super.key, required this.member, required this.name});

  final Member member;
  final String name;

  static const Key cardKey = Key('member-roles-card');
  static const Key addKey = Key('member-roles-add');
  static const Key administratorKey = Key('member-roles-administrator');
  static const Key baseRoleKey = Key('member-roles-base');
  static const Key baseRoleNoteKey = Key('member-roles-base-note');
  static const Key whatKey = Key('member-roles-what');
  static Key chipKeyFor(String roleKey) => ValueKey('member-roles-$roleKey');

  Future<void> _takeBack(
    BuildContext context,
    WidgetRef ref,
    WorkspaceRole role,
  ) async {
    final l10n = AppLocalizations.of(context);
    final ok = await runGuarded(
      context,
      domain: 'workspace',
      message: 'role take-back failed',
      errorText:
          l10n?.roleTakeBackFailed ?? 'The role was not taken back.',
      action: () => setMemberRole(
        ref,
        memberId: member.id,
        roleId: role.id,
        assign: false,
      ),
    );
    if (!ok || !context.mounted) return;
    AppSnack.success(context, l10n?.roleTakenBack ?? 'Role taken back.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final me = ref.watch(myMemberProvider).value;
    final perms = ref.watch(myPermissionsProvider);
    final roles =
        ref.watch(workspaceRolesProvider).value ?? const <WorkspaceRole>[];
    final assignments = ref.watch(workspaceRoleAssignmentsProvider).value ??
        const <String, Set<String>>{};
    final locale = Localizations.localeOf(context).languageCode;
    final isSelf = me?.id == member.id;
    final held = rolesHeldBy(member.id, roles, assignments);

    // The mandatory base role: exactly one of User, Administrator,
    // Co-owner, Owner. Every other role adds to it and never takes from it.
    final base = permissionRoleOf(member);
    final baseName = baseRoleLabel(l10n, base, administratorName(
        roles, locale, l10n?.roleAdmin ?? 'Administrator'));
    final successor = member.coOwner == CoOwnerStatus.passive
        ? (l10n?.memberCoOwnerPassiveChip ?? 'Successor')
        : null;
    final adminRefusal = me == null
        ? RoleRefusal.notPermitted
        : administratorRefusal(caller: me, subject: member);

    final chips = <Widget>[
      if (base == PermissionRole.admin)
        InputChip(
          key: administratorKey,
          avatar: const Icon(Icons.verified_user_outlined, size: 18),
          label: Text(baseName),
          onDeleted: adminRefusal == null
              ? () => requestMemberRoleChange(context, ref, member)
              : null,
        )
      else
        Chip(
          key: baseRoleKey,
          avatar: Icon(
            base == PermissionRole.member
                ? Icons.person_outline
                : Icons.workspace_premium_outlined,
            size: 18,
          ),
          label: Text(baseName),
        ),
      if (successor != null)
        Chip(
          avatar: const Icon(Icons.hourglass_empty, size: 18),
          label: Text(successor),
        ),
      for (final role in held)
        InputChip(
          key: chipKeyFor(role.key),
          label: Text(role.nameIn(locale)),
          onDeleted: me != null &&
                  customRoleRefusal(
                        caller: me,
                        callerPermissions: perms,
                        subject: member,
                        role: role,
                        granting: false,
                      ) ==
                      null
              ? () => _takeBack(context, ref, role)
              : null,
        ),
    ];

    final canSeeAccess = isSelf ||
        (me?.canAdminister ?? false) ||
        perms.contains(WorkspacePermission.manageRoles);

    return Card(
      key: cardKey,
      margin: const EdgeInsets.only(top: AppSpacing.md),
      child: Padding(
        padding: AppSpacing.lgAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n?.memberRolesTitle ?? 'Roles',
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: chips,
            ),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                key: baseRoleNoteKey,
                l10n?.baseRoleNote ??
                    'Everyone has exactly one base role: User, Administrator, '
                        'Co-owner or Owner. Other roles add to it; none takes '
                        'anything away.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            if (isSelf)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  l10n?.roleEditorNotYourself ??
                      'You cannot give a role to yourself.',
                  style: theme.textTheme.bodySmall,
                ),
              )
            else if (canGiveRoles(me, perms) &&
                !member.isKiosk &&
                member.status == MemberStatus.active)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: ActionChip(
                  key: addKey,
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text(l10n?.memberRolesAdd ?? 'Add a role'),
                  onPressed: () =>
                      showRoleAssignSheet(context, ref, member, name),
                ),
              ),
            if (canSeeAccess)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  key: whatKey,
                  onPressed: () => context.push(isSelf
                      ? '/settings/what-you-can-do'
                      : '/settings/what-you-can-do?member=${member.id}'),
                  child: Text(isSelf
                      ? (l10n?.whatYouCanDoTitle ?? 'What you can do here')
                      : (l10n?.memberRolesWhatTheyCanDo ??
                          'What they can do here')),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The roles [member] does not hold yet, each with what giving it means
/// or why it cannot be given.
Future<void> showRoleAssignSheet(
  BuildContext context,
  WidgetRef ref,
  Member member,
  String name,
) async {
  final l10n = AppLocalizations.of(context);
  final me = ref.read(myMemberProvider).value;
  if (me == null) return;
  final perms = ref.read(myPermissionsProvider);
  final roles =
      ref.read(workspaceRolesProvider).value ?? const <WorkspaceRole>[];
  final assignments = ref.read(workspaceRoleAssignmentsProvider).value ??
      const <String, Set<String>>{};
  final heldIds = assignments[member.id] ?? const <String>{};
  final locale = Localizations.localeOf(context).languageCode;
  final offerAdministrator = !holdsAdministrator(member) &&
      !member.isOwner &&
      member.coOwner != CoOwnerStatus.active;
  final adminRefusal = administratorRefusal(caller: me, subject: member);
  final candidates = [
    for (final role in orderedRoles(roles))
      if (role.active && !heldIds.contains(role.id)) role,
  ];

  final chosen = await showModalBottomSheet<Object>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      Widget tile({
        required Key key,
        required String title,
        required String hint,
        required RoleRefusal? refusal,
        required Object value,
      }) =>
          ListTile(
            key: key,
            enabled: refusal == null,
            leading: const Icon(Icons.badge_outlined),
            title: Text(title),
            subtitle: Text(
              refusal == null ? hint : roleRefusalText(l10n, refusal),
            ),
            onTap: () => Navigator.of(sheetContext).pop(value),
          );
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          children: [
            Padding(
              padding: AppSpacing.lgAll,
              child: Text(
                l10n?.roleAssignSheetTitle(name) ?? 'Give a role to $name',
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            if (offerAdministrator)
              tile(
                key: const ValueKey('role-assign-administrator'),
                title: administratorName(
                    roles, locale, l10n?.roleAdmin ?? 'Administrator'),
                hint: l10n?.roleAssignQuorumHint ??
                    'Takes effect once validated.',
                refusal: adminRefusal,
                value: true,
              ),
            for (final role in candidates)
              tile(
                key: ValueKey('role-assign-${role.key}'),
                title: role.nameIn(locale),
                hint: [
                  l10n?.roleAssignImmediateHint ?? 'Takes effect at once.',
                  for (final p in role.permissions) permissionLabel(l10n, p),
                ].join(' · '),
                refusal: customRoleRefusal(
                  caller: me,
                  callerPermissions: perms,
                  subject: member,
                  role: role,
                ),
                value: role,
              ),
            if (!offerAdministrator && candidates.isEmpty)
              Padding(
                padding: AppSpacing.lgAll,
                child: Text(
                  l10n?.roleAssignNothing ?? 'There is no role left to give.',
                ),
              ),
          ],
        ),
      );
    },
  );
  if (chosen == null || !context.mounted) return;
  if (chosen is WorkspaceRole) {
    final ok = await runGuarded(
      context,
      domain: 'workspace',
      message: 'role grant failed',
      errorText: l10n?.roleGiveFailed ?? 'The role was not given.',
      action: () => setMemberRole(
        ref,
        memberId: member.id,
        roleId: chosen.id,
        assign: true,
      ),
    );
    if (!ok || !context.mounted) return;
    AppSnack.success(context, l10n?.roleGiven ?? 'Role given.');
  } else {
    await requestMemberRoleChange(context, ref, member);
  }
}
