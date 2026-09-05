// SPDX-License-Identifier: 0BSD
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../money/presentation/widgets/negotiation_card.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/help/help_hint.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../money/presentation/widgets/consumption_sheet.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../domain/booking_policies.dart';
import '../../domain/member.dart';
import '../../domain/overage_policy.dart';
import '../member_admin_actions.dart';
import '../../domain/workspace_feature.dart';
import '../../domain/workspace_permission.dart';
import '../../providers/workspace_providers.dart';
import '../widgets/open_conversation.dart';
import '../widgets/member_note_dialog.dart';

/// Owner-only member management: role overview, subscription percentage
/// assignment (#128, ADR 0008), pause/reactivate (spec §7.2).
class MembersScreen extends ConsumerWidget {
  const MembersScreen({super.key});

  Future<void> _memberSheet(
    BuildContext context,
    WidgetRef ref,
    Member member,
    String name, {
    required bool isOwner,
    required bool isSelf,
    required bool servicesOn,
    required bool levelBookingOn,
    required bool kioskOn,
    required bool coOwnerOn,
  }) async {
    final l10n = AppLocalizations.of(context);
    final active = member.status == MemberStatus.active;
    final pending = member.status == MemberStatus.pending;
    // #763 — one guide topic for the management rows.
    final membersTopic = l10n?.helpHintMembersTopic ?? 'Members & plans';
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
    final notesOn = ref
        .read(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.memberNotifications);
    final reportsOn = ref
        .read(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.memberReports);
    final actions = <Widget>[
      // #494 — the standing financial agreement, sent by owner/admin.
      if (reportsOn && !member.isKiosk && active)
        _sheetAction(
          context,
          icon: Icons.handshake_outlined,
          label: l10n?.memberSendAgreement ??
              'Send the financial agreement',
          onTap: () => sendMemberAgreement(context, ref, member, name),
        ),
      // Messaging (#456, refactor): the member's CONVERSATION — read
      // the whole exchange and send from the same thread every other
      // surface opens.
      // #887 — nobody reads a message to a managed member.
      if (notesOn &&
          !isSelf &&
          !member.isKiosk &&
          !member.isManaged &&
          active)
        _sheetAction(
          context,
          icon: Icons.chat_outlined,
          label: l10n?.memberMessagesAction ?? 'Messages',
          onTap: () => openDirectConversation(
            context,
            ref,
            memberId: member.id,
          ),
        ),
      // New-member validation (0052): a pending membership offers the
      // decision first — approve activates, reject exits. The quorum
      // path on the events feed stays available in parallel.
      if (pending && !isSelf)
        _sheetAction(
          context,
          icon: Icons.how_to_reg_outlined,
          label: l10n?.memberApprove ?? 'Approve membership',
          onTap: () => decideMemberJoin(context, ref, member, approve: true),
        ),
      if (pending && !isSelf)
        _sheetAction(
          context,
          icon: Icons.person_off_outlined,
          label: l10n?.memberRejectJoin ?? 'Reject membership',
          onTap: () => decideMemberJoin(context, ref, member, approve: false),
        ),
      if (servicesOn && !member.isKiosk && active)
        _sheetAction(
          context,
          icon: Icons.room_service_outlined,
          label: l10n?.consumptionAddForMember(name) ?? 'Add service for $name',
          onTap: () => showConsumptionSheet(
            context,
            ref,
            subjectMemberId: member.id,
            subjectName: name,
          ),
        ),
      if (isOwner && !member.isKiosk)
        _sheetAction(
          context,
          icon: Icons.percent,
          label: l10n?.memberSubscriptionLabel ?? 'Subscription',
          topic: membersTopic,
          onTap: () => pickMemberSubscription(context, ref, member),
        ),
      if (!member.isKiosk && active)
        Row(children: [
          Expanded(
            child: MemberNegotiationTile(
                memberId: member.id, memberName: name, isOwner: isOwner),
          ),
          if (negotiationVisible)
            HelpDot(l10n?.helpHintMembersTipNegotiationTopic ??
                'Price negotiations'),
        ]),
      if (isOwner && !member.isKiosk && active)
        _sheetAction(
          context,
          icon: member.overagePolicy == OveragePolicy.blocked
              ? Icons.speed_outlined
              : Icons.speed,
          label: l10n?.memberOveragePolicyLabel ?? 'When days run out',
          topic: membersTopic,
          onTap: () => pickMemberOveragePolicy(context, ref, member),
        ),
      if (!isSelf && !member.isKiosk && active)
        _sheetAction(
          context,
          icon: Icons.stacked_bar_chart_outlined,
          label: l10n?.memberReservationLimitLabel ?? 'Reservation limit',
          topic: membersTopic,
          onTap: () => pickMemberReservationLimit(context, ref, member),
        ),
      // #628 — the explicit permission to hold OVERLAPPING bookings;
      // same authorization as the cap above, never for themselves.
      if (!isSelf && !member.isKiosk && active)
        _sheetAction(
          context,
          icon: Icons.splitscreen_outlined,
          label: l10n?.memberSimultaneousLimitLabel ??
              'Simultaneous reservations',
          topic: membersTopic,
          onTap: () => pickMemberSimultaneousLimit(context, ref, member),
        ),
      // Whole-level reservations (0050): grant/revoke — owner or admin,
      // never self (the reservation-limit rule), feature-gated.
      if (levelBookingOn && !isSelf && !member.isKiosk && active)
        _sheetAction(
          context,
          icon: member.canReserveLevel
              ? Icons.layers
              : Icons.layers_outlined,
          label: member.canReserveLevel
              ? (l10n?.levelPermissionAllowed ??
                  'May reserve a whole level')
              : (l10n?.levelPermissionDenied ??
                  'May not reserve a whole level'),
          topic: membersTopic,
          onTap: () => toggleMemberLevelPermission(context, ref, member),
        ),
      if (!member.isKiosk && !member.isOwner && active)
        _sheetAction(
          context,
          icon: Icons.qr_code_2_outlined,
          label: l10n?.memberBadgesTooltip ?? 'Badges',
          topic: l10n?.helpHintBadgesTopic ?? 'NFC badges',
          onTap: () => showMemberBadgesDialog(context, ref, member, name),
        ),
      if (isOwner && !member.isOwner && !member.isKiosk && active)
        _sheetAction(
          context,
          icon: member.isAdmin
              ? Icons.remove_moderator_outlined
              : Icons.add_moderator_outlined,
          label: member.isAdmin
              ? (l10n?.memberMakeMember ?? 'Make regular member')
              : (l10n?.memberMakeAdmin ?? 'Make admin'),
          onTap: () => requestMemberRoleChange(context, ref, member),
        ),
      // Co-ownership (0058): owner-level callers appoint active/passive
      // co-owners; a co-owner can be promoted to FULL owner on the
      // spot. The server-side succession runs regardless of the flag.
      if (isOwner &&
          coOwnerOn &&
          !member.isOwner &&
          !member.isKiosk &&
          !isSelf &&
          active)
        _sheetAction(
          context,
          icon: switch (member.coOwner) {
            CoOwnerStatus.active => Icons.workspace_premium,
            CoOwnerStatus.passive => Icons.workspace_premium_outlined,
            CoOwnerStatus.none => Icons.badge_outlined,
          },
          label: l10n?.coOwnerAction ?? 'Co-ownership',
          topic: membersTopic,
          onTap: () => pickMemberCoOwner(context, ref, member),
        ),
      if (isOwner &&
          coOwnerOn &&
          member.coOwner != CoOwnerStatus.none &&
          active)
        _sheetAction(
          context,
          icon: Icons.military_tech_outlined,
          label: l10n?.coOwnerActivate ?? 'Promote to owner now',
          onTap: () => activateMemberCoOwner(context, ref, member),
        ),
      if (isOwner &&
          !member.isOwner &&
          active &&
          (member.isKiosk || kioskOn))
        _sheetAction(
          context,
          icon: member.isKiosk
              ? Icons.tablet_mac
              : Icons.tablet_mac_outlined,
          label: member.isKiosk
              ? (l10n?.memberUnmakeKiosk ?? 'Revert kiosk to member')
              : (l10n?.memberMakeKiosk ?? 'Make kiosk device'),
          topic: l10n?.helpTopicKiosk ?? 'Kiosk mode',
          onTap: () => toggleMemberKiosk(context, ref, member),
        ),
      // Kiosk self-revert (0056): the kiosk account manages its OWN row
      // here too, not only in Settings — without this, an admin kiosk
      // viewing itself had zero actions (field report: "nothing opens").
      if (isSelf && member.isKiosk)
        _sheetAction(
          context,
          icon: Icons.tablet_mac,
          label: l10n?.memberUnmakeKiosk ?? 'Revert kiosk to member',
          onTap: () => revertMyKiosk(context, ref, member),
        ),
      // Pause/reactivate was a hidden long-press before — now a visible,
      // named action.
      if (isOwner && member.status != MemberStatus.exited)
        _sheetAction(
          context,
          icon: member.status == MemberStatus.paused
              ? Icons.play_circle_outline
              : Icons.pause_circle_outline,
          label: member.status == MemberStatus.paused
              ? (l10n?.memberReactivate ?? 'Reactivate membership')
              : (l10n?.memberPause ?? 'Pause membership'),
          topic: membersTopic,
          onTap: () => toggleMemberPaused(context, ref, member),
        ),
    ];
    // NEVER a silent no-op (field report: tapping the kiosk row as a
    // non-owner showed nothing at all) — an empty sheet explains itself.
    if (actions.isEmpty) {
      actions.add(
        Padding(
          padding: AppSpacing.lgAll,
          child: Text(
            l10n?.memberNoActions ??
                'Only the workspace owner can change this member.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: SheetShell(title: name, children: actions),
        ),
      ),
    );
  }

  /// One labeled sheet action: closes the sheet, then runs [onTap] with
  /// the SCREEN's context (the sheet's dies with the pop).
  Widget _sheetAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? topic,
  }) {
    // Builder: the tile's own context lives under the sheet route, so the
    // pop closes the SHEET — the action then runs on the screen's context.
    return Builder(
      builder: (tileContext) => ListTile(
        leading: Icon(icon),
        title: topic == null ? Text(label) : HelpDotTitle(label, topic),
        onTap: () {
          Navigator.of(tileContext).pop();
          onTap();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
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
        title: Text(l10n?.membersTitle ?? 'Members & plans'),
        actions: [
          // Admin broadcast (#456): one note to ALL admins incl. the
          // owner — the server re-checks the sender's rights.
          if ((me?.canAdminister ?? false) &&
              features.contains(WorkspaceFeature.memberNotifications))
            IconButton(
              key: const ValueKey('members-notify-admins'),
              icon: const Icon(Icons.campaign_outlined),
              tooltip: l10n?.memberNotifyAllAdmins ?? 'Notify all admins',
              onPressed: () => showMemberNoteDialog(
                context,
                ref,
                toMemberId: null,
                recipientName:
                    l10n?.memberAllAdmins ?? 'all admins',
              ),
            ),
          // #887 — a member who has no account yet: the admin runs the
          // profile until the person claims it.
          if ((me?.canAdminister ?? false) &&
              features.contains(WorkspaceFeature.managedProfiles))
            IconButton(
              key: const ValueKey('members-add-managed'),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              tooltip: l10n?.managedProfileAdd ?? 'Add a managed profile',
              onPressed: () => context.push('/members/managed'),
            ),
          // Invite entry point (#195): the members list is where owners
          // notice someone is missing. Links to the owner-only workspace
          // ID & QR and billing surfaces — hidden from plain admins.
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.person_add_outlined),
              tooltip: l10n?.membersInvite ?? 'Invite a member',
              onPressed: () => context.push('/workspace-code'),
            ),
          if (isOwner)
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: l10n?.billingTitle ?? 'Billing',
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
                          l10n?.percentValue(member.subscriptionPct) ??
                              '${member.subscriptionPct}%',
                        ),
                      if (member.isKiosk)
                        Text(l10n?.memberKioskLabel ?? 'Kiosk'),
                      if (member.maxActiveReservations != null)
                        Text(
                          l10n?.memberReservationLimitChip(
                                member.maxActiveReservations!,
                              ) ??
                              'max ${member.maxActiveReservations}',
                        ),
                      // #628 — the EFFECTIVE overlap allowance (member
                      // permission, else the workspace default); 1 is
                      // one place at a time and needs no chip.
                      if (BookingPolicies.allowanceFor(
                              member.maxSimultaneousReservations,
                              policies) >
                          BookingPolicies.defaultSimultaneous)
                        Text(
                          l10n?.memberSimultaneousLimitChip(
                                BookingPolicies.allowanceFor(
                                    member.maxSimultaneousReservations,
                                    policies),
                              ) ??
                              '${member.maxSimultaneousReservations} at once',
                        ),
                      if (member.isOwner)
                        Text(l10n?.memberRoleOwner ?? 'Owner'),
                      if (member.coOwner == CoOwnerStatus.active)
                        Text(l10n?.memberCoOwnerChip ?? 'Co-owner'),
                      if (member.coOwner == CoOwnerStatus.passive)
                        Text(l10n?.memberCoOwnerPassiveChip ??
                            'Co-owner (passive)'),
                      if (member.isAdmin && !member.isOwner)
                        Text(l10n?.memberRoleAdmin ?? 'Admin'),
                      if (member.status == MemberStatus.pending)
                        Text(
                          l10n?.memberStatusPending ?? 'Pending',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (member.status == MemberStatus.paused)
                        Text(l10n?.memberStatusPaused ?? 'Paused'),
                      if (member.status == MemberStatus.exited)
                        Text(l10n?.memberStatusExited ?? 'Exited'),
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
              l10n?.workspaceGenericError ??
                  'Something went wrong. Please try again.',
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
