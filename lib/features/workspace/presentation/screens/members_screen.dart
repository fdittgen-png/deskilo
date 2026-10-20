// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/help/help_hint.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../directory/presentation/member_employment_tile.dart';
import '../../../money/presentation/widgets/consumption_sheet.dart';
import '../../../money/presentation/widgets/negotiation_card.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../domain/booking_policies.dart';
import '../../domain/member.dart';
import '../../domain/member_sheet_actions.dart';
import '../../domain/overage_policy.dart';
import '../../domain/workspace_feature.dart';
import '../../domain/workspace_permission.dart';
import '../../providers/workspace_providers.dart';
import '../member_admin_actions.dart';
import '../widgets/member_note_dialog.dart';
import '../widgets/member_roles_card.dart';
import '../widgets/open_conversation.dart';

/// Owner-only member management: role overview, subscription percentage
/// assignment (#128, ADR 0008), pause/reactivate (spec §7.2).
class MembersScreen extends ConsumerWidget {
  const MembersScreen({super.key});

  Future<void> _memberSheet(
    BuildContext context,
    WidgetRef ref,
    Member member,
    String name, {
    required Set<WorkspacePermission> perms,
    required bool isOwner,
    required bool isSelf,
    required bool servicesOn,
    required bool levelBookingOn,
    required bool kioskOn,
    required bool coOwnerOn,
  }) async {
    final l10n = context.l10n;
    // #763 — one guide topic for the management rows.
    final membersTopic = l10n.helpHintMembersTopic;
    // #763 — mirrors MemberNegotiationTile's own gate (#739/#749): the
    // dot beside the self-gating tile must never float alone.
    final perms = ref.read(myPermissionsProvider);
    final negotiationVisible = !isSelf &&
        ref.read(myMemberProvider).value != null &&
        ref
            .read(enabledFeaturesSyncProvider)
            .contains(WorkspaceFeature.priceNegotiations) &&
        (isOwner ||
            perms.contains(WorkspacePermission.manageNegotiations) ||
            perms.contains(WorkspacePermission.viewNegotiations));
    final enabled = ref.read(enabledFeaturesSyncProvider);
    final me = ref.read(myMemberProvider).value;
    final facts = MemberSheetFacts(
      member: member,
      isOwner: isOwner,
      isSelf: isSelf,
      notesOn: enabled.contains(WorkspaceFeature.memberNotifications),
      reportsOn: enabled.contains(WorkspaceFeature.memberReports),
      rolesOn: enabled.contains(WorkspaceFeature.roleAssignment),
      // #2137 — the allowances (0364)
      staff: (me?.canAdminister ?? false) ||
          perms.contains(WorkspacePermission.manageReservations),
      canGiveRoles: canGiveRoles(me, perms),
      mayOperateKiosk: perms.contains(WorkspacePermission.operateKiosk),
      servicesOn: servicesOn,
      levelBookingOn: levelBookingOn,
      kioskOn: kioskOn,
      coOwnerOn: coOwnerOn,
    );
    final actions = <Widget>[
      for (final action in memberSheetActions(facts))
        _actionTile(
          context,
          ref,
          action,
          member,
          name,
          isOwner: isOwner,
          negotiationVisible: negotiationVisible,
        ),
    ];
    // NEVER a silent no-op (field report: tapping the kiosk row as a
    // non-owner showed nothing at all) — an empty sheet explains itself.
    if (actions.isEmpty) {
      actions.add(
        Padding(
          padding: AppSpacing.lgAll,
          child: Text(
            l10n.memberNoActions,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }
    // One symbol for the whole sheet; the negotiation row keeps its own.
    actions.insert(
      0,
      Align(
        alignment: AlignmentDirectional.centerEnd,
        child: HelpDot(membersTopic, anchor: HelpAnchor.membersActions),
      ),
    );
    await showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: SheetShell(title: name, children: actions),
        ),
      ),
    );
  }

  /// The tile of one sheet action (what is offered is decided by
  /// [memberSheetActions]).
  Widget _actionTile(
    BuildContext context,
    WidgetRef ref,
    MemberSheetAction action,
    Member member,
    String name, {
    required bool isOwner,
    required bool negotiationVisible,
  }) {
    final l10n = context.l10n;
    Widget tile(String key, IconData icon, String label, VoidCallback onTap) =>
        _sheetAction(
          context,
          key: ValueKey(key),
          icon: icon,
          label: label,
          onTap: onTap,
        );
    return switch (action) {
      MemberSheetAction.employment =>
        MemberEmploymentTile(member: member.id, editable: isOwner),
      // #494 — the standing financial agreement, sent by owner/admin.
      MemberSheetAction.sendAgreement => tile(
        'members-action-send-agreement',
        Icons.handshake_outlined,
        l10n.memberSendAgreement,
        () => sendMemberAgreement(context, ref, member, name),
      ),
      // Messaging (#456, refactor): the member's CONVERSATION — read the
      // whole exchange and send from the same thread every other surface
      // opens.
      MemberSheetAction.messages => tile(
        'members-action-messages-action',
        Icons.chat_outlined,
        l10n.memberMessagesAction,
        () => openDirectConversation(context, ref, memberId: member.id),
      ),
      // New-member validation (0052): a pending membership offers the
      // decision first — approve activates, reject exits. The quorum path
      // on the events feed stays available in parallel.
      MemberSheetAction.approveJoin => tile(
        'members-action-approve',
        Icons.how_to_reg_outlined,
        l10n.memberApprove,
        () => decideMemberJoin(context, ref, member, approve: true),
      ),
      MemberSheetAction.rejectJoin => tile(
        'members-action-reject-join',
        Icons.person_off_outlined,
        l10n.memberRejectJoin,
        () => decideMemberJoin(context, ref, member, approve: false),
      ),
      MemberSheetAction.addConsumption => tile(
        'members-action-consumption-add-for-member',
        Icons.room_service_outlined,
        l10n.consumptionAddForMember(name),
        () => showConsumptionSheet(
          context,
          ref,
          subjectMemberId: member.id,
          subjectName: name,
        ),
      ),
      MemberSheetAction.subscription => tile(
        'members-action-subscription-label',
        Icons.percent,
        l10n.memberSubscriptionLabel,
        () => pickMemberSubscription(context, ref, member),
      ),
      MemberSheetAction.negotiation => Row(
        children: [
          Expanded(
            child: MemberNegotiationTile(
              memberId: member.id,
              memberName: name,
              isOwner: isOwner,
            ),
          ),
          if (negotiationVisible)
            HelpDot(
              l10n.helpHintMembersTipNegotiationTopic,
              anchor: HelpAnchor.membersNegotiation,
            ),
        ],
      ),
      MemberSheetAction.overagePolicy => tile(
        'members-action-overage-policy-label',
        member.overagePolicy == OveragePolicy.blocked
            ? Icons.speed_outlined
            : Icons.speed,
        l10n.memberOveragePolicyLabel,
        () => pickMemberOveragePolicy(context, ref, member),
      ),
      MemberSheetAction.reservationLimit => tile(
        'members-action-reservation-limit-label',
        Icons.stacked_bar_chart_outlined,
        l10n.memberReservationLimitLabel,
        () => pickMemberReservationLimit(context, ref, member),
      ),
      MemberSheetAction.simultaneousLimit => tile(
        'members-action-simultaneous-limit-label',
        Icons.splitscreen_outlined,
        l10n.memberSimultaneousLimitLabel,
        () => pickMemberSimultaneousLimit(context, ref, member),
      ),
      // Whole-level reservations (0050): grant/revoke.
      MemberSheetAction.levelPermission => tile(
        'members-action-level-permission-allowed',
        member.canReserveLevel ? Icons.layers : Icons.layers_outlined,
        member.canReserveLevel
            ? l10n.levelPermissionAllowed
            : l10n.levelPermissionDenied,
        () => toggleMemberLevelPermission(context, ref, member),
      ),
      MemberSheetAction.badges => tile(
        'members-action-badges-tooltip',
        Icons.qr_code_2_outlined,
        l10n.memberBadgesTooltip,
        () => showMemberBadgesDialog(context, ref, member, name),
      ),
      // #2085 — with roleAssignment, "Add a role" offers the Administrator
      // role and the space's own, each with its rule.
      MemberSheetAction.addRole => tile(
        'members-action-roles-add',
        Icons.badge_outlined,
        l10n.memberRolesAdd,
        () => showRoleAssignSheet(context, ref, member, name),
      ),
      MemberSheetAction.makeAdminOrMember => tile(
        'members-action-make-member',
        member.isAdmin
            ? Icons.remove_moderator_outlined
            : Icons.add_moderator_outlined,
        member.isAdmin ? l10n.memberMakeMember : l10n.memberMakeAdmin,
        () => requestMemberRoleChange(context, ref, member),
      ),
      // Co-ownership (0058): owner-level callers appoint active/passive
      // co-owners; a co-owner can be promoted to FULL owner on the spot.
      MemberSheetAction.coOwnerAppoint => tile(
        'members-action-co-owner-action',
        switch (member.coOwner) {
          CoOwnerStatus.active => Icons.workspace_premium,
          CoOwnerStatus.passive => Icons.workspace_premium_outlined,
          CoOwnerStatus.none => Icons.badge_outlined,
        },
        l10n.coOwnerAction,
        () => pickMemberCoOwner(context, ref, member),
      ),
      MemberSheetAction.coOwnerActivate => tile(
        'members-action-co-owner-activate',
        Icons.military_tech_outlined,
        l10n.coOwnerActivate,
        () => activateMemberCoOwner(context, ref, member),
      ),
      MemberSheetAction.kioskToggle => tile(
        'members-action-unmake-kiosk',
        member.isKiosk ? Icons.tablet_mac : Icons.tablet_mac_outlined,
        member.isKiosk ? l10n.memberUnmakeKiosk : l10n.memberMakeKiosk,
        () => toggleMemberKiosk(context, ref, member),
      ),
      // Kiosk self-revert (0056): the kiosk account manages its OWN row
      // here too, not only in Settings.
      MemberSheetAction.kioskSelfRevert => tile(
        'members-action-unmake-kiosk-2',
        Icons.tablet_mac,
        l10n.memberUnmakeKiosk,
        () => revertMyKiosk(context, ref, member),
      ),
      // Pause/reactivate was a hidden long-press before — now a visible,
      // named action.
      MemberSheetAction.pauseOrReactivate => tile(
        'members-action-reactivate',
        member.status == MemberStatus.paused
            ? Icons.play_circle_outline
            : Icons.pause_circle_outline,
        member.status == MemberStatus.paused
            ? l10n.memberReactivate
            : l10n.memberPause,
        () => toggleMemberPaused(context, ref, member),
      ),
    };
  }

  /// One labeled sheet action: closes the sheet, then runs [onTap] with
  /// the SCREEN's context (the sheet's dies with the pop).
  Widget _sheetAction(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    // Builder: the tile's own context lives under the sheet route, so the
    // pop closes the SHEET — the action then runs on the screen's context.
    return Builder(
      builder: (tileContext) => ListTile(
        key: key,
        leading: Icon(icon),
        title: Text(label),
        onTap: () {
          Navigator.of(tileContext).pop();
          onTap();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final membersAsync = ref.watch(workspaceMembersProvider);
    final names = ref.watch(memberNamesProvider).value ?? const {};
    // Admin surface (#410): non-admin callers get {} from the server.
    final emails = ref.watch(memberEmailsProvider).value ?? const {};
    // Admins reach this screen too (0044); owner-only controls gate on
    // [isOwner], and the self row never offers the reservation limit.
    final me = ref.watch(myMemberProvider).value;
    // Permission, not literal ownership: active co-owners (0058) get
    // the full owner surface.
    final isOwner = me?.actsAsOwner ?? false;
    // Consumption entry points follow the services feature (#146).
    final features = ref.watch(enabledFeaturesSyncProvider);
    // #628 — the workspace default the per-member permission overrides.
    final policies =
        ref.watch(bookingPoliciesProvider).value ?? const BookingPolicies();
    final servicesOn = features.contains(WorkspaceFeature.services);
    final kioskOn = features.contains(WorkspaceFeature.kioskMode);
    final coOwnerOn = features.contains(WorkspaceFeature.coOwner);
    final levelBookingOn =
        features.contains(WorkspaceFeature.levelBooking);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.membersTitle),
        actions: [
          // Admin broadcast (#456): one note to ALL admins incl. the
          // owner — the server re-checks the sender's rights.
          if ((me?.canAdminister ?? false) &&
              features.contains(WorkspaceFeature.memberNotifications))
            IconButton(
              key: const ValueKey('members-notify-admins'),
              icon: const Icon(Icons.campaign_outlined),
              tooltip: l10n.memberNotifyAllAdmins,
              onPressed: () => showMemberNoteDialog(
                context,
                ref,
                toMemberId: null,
                recipientName:
                    l10n.memberAllAdmins,
              ),
            ),
          // #887 — a member who has no account yet: the admin runs the
          // profile until the person claims it.
          if ((me?.canAdminister ?? false) &&
              features.contains(WorkspaceFeature.managedProfiles))
            IconButton(
              key: const ValueKey('members-add-managed'),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              tooltip: l10n.managedProfileAdd,
              onPressed: () => context.push('/members/managed'),
            ),
          // Invite entry point (#195): the members list is where owners
          // notice someone is missing. Links to the owner-only workspace
          // ID & QR and billing surfaces — hidden from plain admins.
          if (isOwner)
            IconButton(
              key: const ValueKey('members-invite'),
              icon: const Icon(Icons.person_add_outlined),
              tooltip: l10n.membersInvite,
              onPressed: () => context.push('/workspace-code'),
            ),
          if (isOwner)
          IconButton(
            key: const ValueKey('members-billing-title'),
            icon: const Icon(Icons.tune),
            tooltip: l10n.billingTitle,
            onPressed: () => context.push('/billing'),
          ),
        ],
      ),
      body: switch (membersAsync) {
        AsyncData(value: final members) => ListView(
            children: [
              // #606 — contextual how-to; gated inside the widget.
              const HelpHint(HelpHintId.members),
              for (final member in members)
                ListTile(
                  key: ValueKey('members-member-kiosk-label-${member.id}'),
                  leading: CircleAvatar(
                    child: Text(
                      (names[member.id] ?? '?').isEmpty
                          ? '?'
                          : (names[member.id] ?? '?')
                              .substring(0, 1)
                              .toUpperCase(),
                    ),
                  ),
                  title: Text(names[member.id] ?? ''),
                  subtitle: Wrap(
                    spacing: 6,
                    children: [
                      if ((emails[member.id] ?? '').isNotEmpty)
                        Text(emails[member.id]!),
                      // A kiosk is a device, not a paying member — no
                      // subscription line.
                      if (!member.isKiosk)
                        Text(
                          subscriptionText(l10n, member.subscriptionPct),
                        ),
                      if (member.isKiosk)
                        Text(l10n.memberKioskLabel),
                      if (member.maxActiveReservations != null)
                        Text(
                          l10n.memberReservationLimitChip(
                                member.maxActiveReservations!,
                              ),
                        ),
                      // #628 — the EFFECTIVE overlap allowance (member
                      // permission, else the workspace default); 1 is
                      // one place at a time and needs no chip.
                      if (BookingPolicies.allowanceFor(
                              member.maxSimultaneousReservations,
                              policies) >
                          BookingPolicies.defaultSimultaneous)
                        Text(
                          l10n.memberSimultaneousLimitChip(
                                BookingPolicies.allowanceFor(
                                    member.maxSimultaneousReservations,
                                    policies),
                              ),
                        ),
                      if (member.isOwner)
                        Text(l10n.memberRoleOwner),
                      if (member.coOwner == CoOwnerStatus.active)
                        Text(l10n.memberCoOwnerChip),
                      if (member.coOwner == CoOwnerStatus.passive)
                        Text(l10n.memberCoOwnerPassiveChip),
                      if (member.isAdmin && !member.isOwner)
                        Text(l10n.memberRoleAdmin),
                      if (member.status == MemberStatus.pending)
                        Text(
                          l10n.memberStatusPending,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (member.status == MemberStatus.paused)
                        Text(l10n.memberStatusPaused),
                      if (member.status == MemberStatus.exited)
                        Text(l10n.memberStatusExited),
                    ],
                  ),
                  // One labeled management surface per member (UX pass):
                  // the row opens a sheet of named actions instead of a
                  // pile of cryptic icon buttons (which overflowed on
                  // phones) and a hidden long-press.
                  trailing: const Icon(Icons.chevron_right),
                  // #825 — the member PAGE holds the same actions, grouped
                  // and with their current values; the sheet stays for
                  // the flag off.
                  onTap: () => features.contains(WorkspaceFeature.memberPage)
                      ? context.push('/member/${member.id}')
                      : _memberSheet(
                    context,
                    ref,
                    member,
                    names[member.id] ?? '',
                    isOwner: isOwner,
                    perms: ref.watch(myPermissionsProvider),
                    isSelf: member.id == me?.id,
                    servicesOn: servicesOn,
                    levelBookingOn: levelBookingOn,
                    kioskOn: kioskOn,
                    coOwnerOn: coOwnerOn,
                  ),
                ),
            ],
          ),
        AsyncError() => Center(
            child: Text(
              l10n.workspaceGenericError,
            ),
          ),
        _ => const LoadingView(),
      },
    );
  }
}

/// Stateful badge manager (0043): shows the member's badges with revoke
/// actions; issuing swaps the body to the raw token's QR — the only time
/// it ever exists client-side.
