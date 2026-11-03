// SPDX-License-Identifier: AGPL-3.0-or-later
// #2494 — the membership, management and access rows of the member profile.
// Split out of member_page (was a part file).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../profile/domain/personal_info.dart';
import '../../../profile/presentation/courtesy_words.dart';
import '../../../workspace/domain/invite_uri.dart';
import '../../../workspace/domain/member.dart';
import '../../../workspace/domain/workspace_permission.dart';
import '../../../workspace/presentation/member_admin_actions.dart';
import '../../../workspace/presentation/member_labels.dart';
import '../../../workspace/presentation/widgets/invite_sheet.dart';
import '../../../workspace/providers/workspace_providers.dart';
import 'member_page_context.dart';

class MemberManageTile extends StatelessWidget {
  const MemberManageTile({
    super.key,
    required this.tileKey,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final Key tileKey;
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    key: tileKey,
    leading: Icon(icon),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}

List<Widget> memberMembershipTiles(MemberPageContext c) => <Widget>[
    ..._memberJoinTiles(c),
    ..._memberManagedTiles(c),
    ..._memberStandingTiles(c),
    ..._memberCoOwnerTiles(c),
    ..._memberKioskTiles(c),
  ];

/// A pending join request: the administrator approves or rejects it.
List<Widget> _memberJoinTiles(MemberPageContext c) => <Widget>[
    if (c.pending && !c.isSelf && c.canAdmin) ...[
      MemberManageTile(
        tileKey: const ValueKey('member-page-approve'),
        icon: Icons.how_to_reg_outlined,
        title: c.l10n.memberApprove,
        onTap: () =>
            decideMemberJoin(c.context, c.ref, c.member, approve: true),
      ),
      MemberManageTile(
        tileKey: const ValueKey('member-page-reject'),
        icon: Icons.person_off_outlined,
        title: c.l10n.memberRejectJoin,
        onTap: () =>
            decideMemberJoin(c.context, c.ref, c.member, approve: false),
      ),
    ],
  ];

/// #887 — the admin runs a managed member's identity and hands the
/// profile over with a bound invitation.
List<Widget> _memberManagedTiles(MemberPageContext c) {
  // Watched whether or not the tiles show, as the group always did.
  final workspace = c.ref.watch(currentWorkspaceProvider).value;
  final context = c.context;
  final ref = c.ref;
  final member = c.member;
  final l10n = c.l10n;
  if (!(member.isManaged && c.canAdmin)) return <Widget>[];
  final identity =
      ref.watch(managedIdentityProvider(member.id)).value?.identity ??
      PersonalInfo.empty;
  return <Widget>[
    MemberManageTile(
      tileKey: const ValueKey('member-page-managed-edit'),
      icon: Icons.contact_mail_outlined,
      title: l10n.managedProfileEdit,
      // #915 — the address comes from BEHIND the rule, and asking
      // for it is written down. An admin the rule does not name sees
      // the name on the tile and nothing under it.
      subtitle: identity
          .postalBlock(
            workspaceCountry: workspace?.countryCode ?? '',
            // #912 — the title the person asked for, in the reader's
            // language, exactly as the document will print it.
            courtesyWord: courtesyWord(l10n, identity.courtesy),
          )
          .replaceAll('\n', ', '),
      onTap: () => context.push('/members/managed?member=${member.id}'),
    ),
    if (workspace != null)
      MemberManageTile(
        tileKey: const ValueKey('member-page-hand-over'),
        icon: Icons.qr_code_2_outlined,
        title: l10n.managedProfileHandOver,
        subtitle: l10n.managedProfileHandOverHint,
        onTap: () => showInviteSheet(
          context,
          workspace: workspace,
          role: InviteRole.user,
          memberId: member.id,
          identity: member.managedIdentity,
        ),
      ),
    MemberManageTile(
      tileKey: const ValueKey('member-page-revoke-handover'),
      icon: Icons.link_off_outlined,
      title: l10n.managedProfileRevoke,
      onTap: () => _revokeMemberHandover(context, ref, member),
    ),
  ];
}

/// The owner pauses or reactivates the member and, without role
/// assignment, makes them an administrator or a member again.
List<Widget> _memberStandingTiles(MemberPageContext c) {
  final paused = c.member.status == MemberStatus.paused;
  return <Widget>[
    if (c.isOwner && c.member.status != MemberStatus.exited)
      MemberManageTile(
        tileKey: const ValueKey('member-page-pause'),
        icon: paused ? Icons.play_circle_outline : Icons.pause_circle_outline,
        title: paused ? (c.l10n.memberReactivate) : (c.l10n.memberPause),
        subtitle: memberStatusLabel(c.l10n, c.member.status),
        onTap: () => toggleMemberPaused(c.context, c.ref, c.member),
      ),
    // #2085 — with roleAssignment the Roles card gives this one too.
    if (c.isOwner &&
        !c.member.isOwner &&
        !c.member.isKiosk &&
        c.active &&
        !c.rolesOn)
      MemberManageTile(
        tileKey: const ValueKey('member-page-role'),
        icon: c.member.isAdmin
            ? Icons.remove_moderator_outlined
            : Icons.add_moderator_outlined,
        title: c.member.isAdmin
            ? (c.l10n.memberMakeMember)
            : (c.l10n.memberMakeAdmin),
        subtitle: c.member.isAdmin
            ? (c.l10n.memberRoleAdmin)
            : (c.l10n.memberRoleMember),
        onTap: () => requestMemberRoleChange(c.context, c.ref, c.member),
      ),
  ];
}

/// The owner names or activates a co-owner.
List<Widget> _memberCoOwnerTiles(MemberPageContext c) {
  if (!(c.isOwner && c.coOwnerOn && c.active)) return <Widget>[];
  return <Widget>[
    if (!c.member.isOwner && !c.member.isKiosk && !c.isSelf)
      MemberManageTile(
        tileKey: const ValueKey('member-page-coowner'),
        icon: switch (c.member.coOwner) {
          CoOwnerStatus.active => Icons.workspace_premium,
          CoOwnerStatus.passive => Icons.workspace_premium_outlined,
          CoOwnerStatus.none => Icons.badge_outlined,
        },
        title: c.l10n.coOwnerAction,
        subtitle: switch (c.member.coOwner) {
          CoOwnerStatus.active => c.l10n.memberCoOwnerChip,
          CoOwnerStatus.passive => c.l10n.memberCoOwnerPassiveChip,
          CoOwnerStatus.none => c.l10n.memberPageNone,
        },
        onTap: () => pickMemberCoOwner(c.context, c.ref, c.member),
      ),
    if (c.member.coOwner != CoOwnerStatus.none)
      MemberManageTile(
        tileKey: const ValueKey('member-page-coowner-activate'),
        icon: Icons.military_tech_outlined,
        title: c.l10n.coOwnerActivate,
        onTap: () => activateMemberCoOwner(c.context, c.ref, c.member),
      ),
  ];
}

/// The member as a kiosk: an operator makes or unmakes one, and a kiosk
/// reverts itself.
List<Widget> _memberKioskTiles(MemberPageContext c) => <Widget>[
    if (c.perms.contains(WorkspacePermission.operateKiosk) &&
        !c.member.isOwner &&
        c.active &&
        (c.member.isKiosk || c.kioskOn))
      MemberManageTile(
        tileKey: const ValueKey('member-page-kiosk'),
        icon: c.member.isKiosk ? Icons.tablet_mac : Icons.tablet_mac_outlined,
        title: c.member.isKiosk
            ? (c.l10n.memberUnmakeKiosk)
            : (c.l10n.memberMakeKiosk),
        onTap: () => toggleMemberKiosk(c.context, c.ref, c.member),
      ),
    if (c.isSelf && c.member.isKiosk)
      MemberManageTile(
        tileKey: const ValueKey('member-page-kiosk-self'),
        icon: Icons.tablet_mac,
        title: c.l10n.memberUnmakeKiosk,
        onTap: () => revertMyKiosk(c.context, c.ref, c.member),
      ),
  ];

List<Widget> memberAccessTiles(MemberPageContext c) {
  final context = c.context;
  final ref = c.ref;
  final member = c.member;
  final name = c.name;
  final l10n = c.l10n;
  final active = c.active;
  final canAdmin = c.canAdmin;
  return <Widget>[
    if (canAdmin && !member.isKiosk && !member.isOwner && active)
      MemberManageTile(
        tileKey: const ValueKey('member-page-badges'),
        icon: Icons.qr_code_2_outlined,
        title: l10n.memberBadgesTooltip,
        onTap: () => showMemberBadgesDialog(context, ref, member, name),
      ),
  ];
}

Future<void> _revokeMemberHandover(
  BuildContext context,
  WidgetRef ref,
  Member member,
) async {
  final l10n = context.l10n;
  final ok = await runGuarded(
    context,
    domain: 'workspace',
    message: 'revoke handover failed',
    errorText: l10n.workspaceGenericError,
    action: () =>
        ref.read(workspaceRepositoryProvider).revokeHandover(member.id),
  );
  if (!ok || !context.mounted) return;
  AppSnack.success(context, l10n.managedProfileRevoked);
}
