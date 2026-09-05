// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/links/link_launcher.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../money/presentation/widgets/consumption_sheet.dart';
import '../../../money/presentation/widgets/negotiation_card.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../../profile/presentation/widgets/member_avatar.dart';
import '../../../reservations/domain/reservation.dart';
import '../../../reservations/presentation/widgets/reservation_detail_sheet.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../../workspace/domain/booking_policies.dart';
import '../../../workspace/domain/member.dart';
import '../../../workspace/domain/overage_policy.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/domain/workspace_permission.dart';
import '../../../workspace/presentation/member_admin_actions.dart';
import '../../../workspace/presentation/widgets/open_conversation.dart';
import '../../../workspace/presentation/widgets/invite_sheet.dart';
import '../../../workspace/domain/invite_uri.dart';
import '../../../../core/trace/guarded.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/directory_status.dart';
import '../../providers/directory_providers.dart';
import '../widgets/member_contact_card.dart';
import '../widgets/member_money_card.dart';

/// #825 — ONE page per person (`/member/:id`): who they are and whether
/// they are here, what they have booked, how to reach them, their money
/// position where the viewer may see it — and, for admins, everything
/// that can be changed about them, grouped by topic with the CURRENT
/// value on every row. It replaces two surfaces that never met: the
/// read-only profile sheet of the directory and the flat seventeen-row
/// action sheet of Members & plans.
class MemberPage extends ConsumerWidget {
  const MemberPage({super.key, required this.memberId});

  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final membersAsync = ref.watch(workspaceMembersProvider);
    final member = membersAsync.value?.where((m) => m.id == memberId).firstOrNull;
    if (member == null) {
      return Scaffold(
        appBar: AppBar(),
        body: membersAsync.isLoading
            ? const LoadingView()
            : EmptyState(
                icon: Icons.person_off_outlined,
                title: l10n?.workspaceGenericError ??
                    'Something went wrong. Please try again.',
              ),
      );
    }
    final name = ref.watch(memberNamesProvider).value?[memberId] ?? '';
    return _MemberPageBody(member: member, name: name);
  }
}

class _MemberPageBody extends ConsumerWidget {
  const _MemberPageBody({required this.member, required this.name});

  final Member member;
  final String name;

  Future<void> _launch(BuildContext context, WidgetRef ref, Uri uri) async {
    final l10n = AppLocalizations.of(context);
    try {
      final handled = await ref.read(linkLauncherProvider)(uri);
      if (!handled) throw StateError('no handler for $uri');
    } catch (e, st) {
      TraceLogger.instance.error('members', 'link launch failed',
          error: e, stackTrace: st);
      if (!context.mounted) return;
      AppSnack.error(
        context,
        l10n?.workspaceGenericError ??
            'Something went wrong. Please try again.',
      );
    }
  }

  /// "Wed 2 · 08:00 · A1" — the directory's house style for a booking.
  static String bookingLabel(Reservation reservation, String seatName) {
    final local = reservation.startsAt.toLocal();
    final day =
        '${DateFormat.E().format(local)} ${DateFormat.d().format(local)}';
    final when = '$day · ${DateFormat.Hm().format(local)}';
    return seatName.isEmpty ? when : '$when · $seatName';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final now = ref.watch(clockProvider).now();
    final me = ref.watch(myMemberProvider).value;
    final isSelf = me?.id == member.id;
    final features = ref.watch(enabledFeaturesSyncProvider);
    final perms = ref.watch(myPermissionsProvider);
    final profile = ref.watch(memberProfilesProvider).value?[member.userId];
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final email = ref.watch(memberEmailsProvider).value?[member.id] ?? '';
    final reservations =
        ref.watch(directoryReservationsProvider).value ?? const <Reservation>[];
    final targets = ref.watch(targetNamesProvider).value ?? const {};
    final policies =
        ref.watch(bookingPoliciesProvider).value ?? const BookingPolicies();
    final presence = resolveDirectoryPresence(
      lastSeenAt: profile?.lastSeenAt,
      now: now,
      isSelf: isSelf,
    );
    final info = resolveReservationInfo(
      memberId: member.id,
      reservations: reservations,
      now: now,
    );
    final upcoming = [
      for (final r in reservations)
        if (r.memberId == member.id && r.endsAt.isAfter(now)) r,
    ]..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    final active = member.status == MemberStatus.active;
    final pending = member.status == MemberStatus.pending;
    final canAdmin = me?.canAdminister ?? false;
    final isOwner = me?.actsAsOwner ?? false;
    final whatsappOn = features.contains(WorkspaceFeature.whatsappIntegration);
    final whatsappUri = whatsappOn ? profile?.whatsappUri : null;
    final notesOn = features.contains(WorkspaceFeature.memberNotifications);
    // #887 — nobody reads a message sent to a managed member.
    final canMessage =
        notesOn && !isSelf && !member.isKiosk && !member.isManaged && active;
    final servicesOn = features.contains(WorkspaceFeature.services);
    final reportsOn = features.contains(WorkspaceFeature.memberReports);
    final kioskOn = features.contains(WorkspaceFeature.kioskMode);
    final coOwnerOn = features.contains(WorkspaceFeature.coOwner);
    final levelOn = features.contains(WorkspaceFeature.levelBooking);
    final negotiationVisible = !isSelf &&
        me != null &&
        features.contains(WorkspaceFeature.priceNegotiations) &&
        (isOwner ||
            perms.contains(WorkspacePermission.manageNegotiations) ||
            perms.contains(WorkspacePermission.viewNegotiations));

    final quickActions = <Widget>[
      if (canMessage)
        FilledButton.tonalIcon(
          key: const ValueKey('member-page-action-message'),
          icon: const Icon(Icons.chat_bubble_outline),
          label: Text(l10n?.memberMessagesAction ?? 'Messages'),
          onPressed: () =>
              openDirectConversation(context, ref, memberId: member.id),
        ),
      if (whatsappUri != null)
        FilledButton.tonalIcon(
          key: const ValueKey('member-page-action-wa'),
          icon: const Icon(Icons.chat_outlined),
          label: Text(l10n?.directoryWhatsapp ?? 'Chat on WhatsApp'),
          onPressed: () => _launch(context, ref, whatsappUri),
        ),
      if (email.isNotEmpty && !isSelf)
        FilledButton.tonalIcon(
          key: const ValueKey('member-page-action-email'),
          icon: const Icon(Icons.mail_outline),
          label: Text(l10n?.memberPageEmailAction ?? 'E-mail'),
          onPressed: () =>
              _launch(context, ref, Uri(scheme: 'mailto', path: email)),
        ),
      if (servicesOn && canAdmin && !member.isKiosk && active)
        FilledButton.tonalIcon(
          key: const ValueKey('member-page-action-service'),
          icon: const Icon(Icons.room_service_outlined),
          label: Text(l10n?.memberPageAddService ?? 'Add a service'),
          onPressed: () => showConsumptionSheet(
            context,
            ref,
            subjectMemberId: member.id,
            subjectName: name,
          ),
        ),
      if (reportsOn && canAdmin && !member.isKiosk && active)
        FilledButton.tonalIcon(
          key: const ValueKey('member-page-action-agreement'),
          icon: const Icon(Icons.handshake_outlined),
          label: Text(
              l10n?.memberSendAgreement ?? 'Send the financial agreement'),
          onPressed: () => sendMemberAgreement(context, ref, member, name),
        ),
    ];

    // ---- the admin groups: every row carries its CURRENT value.
    final membership = <Widget>[
      if (pending && !isSelf && canAdmin) ...[
        _ManageTile(
          tileKey: const ValueKey('member-page-approve'),
          icon: Icons.how_to_reg_outlined,
          title: l10n?.memberApprove ?? 'Approve membership',
          onTap: () => decideMemberJoin(context, ref, member, approve: true),
        ),
        _ManageTile(
          tileKey: const ValueKey('member-page-reject'),
          icon: Icons.person_off_outlined,
          title: l10n?.memberRejectJoin ?? 'Reject membership',
          onTap: () => decideMemberJoin(context, ref, member, approve: false),
        ),
      ],
      // #887 — the admin runs a managed member's identity and hands
      // the profile over with a bound invitation.
      if (member.isManaged && canAdmin) ...[
        _ManageTile(
          tileKey: const ValueKey('member-page-managed-edit'),
          icon: Icons.contact_mail_outlined,
          title: l10n?.managedProfileEdit ?? 'Edit identity',
          subtitle: member.managedIdentity
              .postalBlock(workspaceCountry: workspace?.countryCode ?? '')
              .replaceAll('\n', ', '),
          onTap: () => context.push('/members/managed?member=${member.id}'),
        ),
        if (workspace != null)
          _ManageTile(
            tileKey: const ValueKey('member-page-hand-over'),
            icon: Icons.qr_code_2_outlined,
            title: l10n?.managedProfileHandOver ?? 'Hand over to the person',
            subtitle: l10n?.managedProfileHandOverHint ??
                'Mints a personal code bound to this profile. Whoever '
                    'redeems it takes the profile over — reservations, '
                    'invoices, subscription — once you approve the '
                    'membership.',
            onTap: () => showInviteSheet(
              context,
              workspace: workspace,
              role: InviteRole.user,
              memberId: member.id,
              identity: member.managedIdentity,
            ),
          ),
        _ManageTile(
          tileKey: const ValueKey('member-page-revoke-handover'),
          icon: Icons.link_off_outlined,
          title: l10n?.managedProfileRevoke ?? 'Revoke handover',
          onTap: () => _revokeHandover(context, ref, member),
        ),
      ],
      if (isOwner && member.status != MemberStatus.exited)
        _ManageTile(
          tileKey: const ValueKey('member-page-pause'),
          icon: member.status == MemberStatus.paused
              ? Icons.play_circle_outline
              : Icons.pause_circle_outline,
          title: member.status == MemberStatus.paused
              ? (l10n?.memberReactivate ?? 'Reactivate membership')
              : (l10n?.memberPause ?? 'Pause membership'),
          subtitle: _statusLabel(l10n, member.status),
          onTap: () => toggleMemberPaused(context, ref, member),
        ),
      if (isOwner && !member.isOwner && !member.isKiosk && active)
        _ManageTile(
          tileKey: const ValueKey('member-page-role'),
          icon: member.isAdmin
              ? Icons.remove_moderator_outlined
              : Icons.add_moderator_outlined,
          title: member.isAdmin
              ? (l10n?.memberMakeMember ?? 'Make regular member')
              : (l10n?.memberMakeAdmin ?? 'Make admin'),
          subtitle: member.isAdmin
              ? (l10n?.memberRoleAdmin ?? 'Admin')
              : (l10n?.memberRoleMember ?? 'Member'),
          onTap: () => requestMemberRoleChange(context, ref, member),
        ),
      if (isOwner &&
          coOwnerOn &&
          !member.isOwner &&
          !member.isKiosk &&
          !isSelf &&
          active)
        _ManageTile(
          tileKey: const ValueKey('member-page-coowner'),
          icon: switch (member.coOwner) {
            CoOwnerStatus.active => Icons.workspace_premium,
            CoOwnerStatus.passive => Icons.workspace_premium_outlined,
            CoOwnerStatus.none => Icons.badge_outlined,
          },
          title: l10n?.coOwnerAction ?? 'Co-ownership',
          subtitle: switch (member.coOwner) {
            CoOwnerStatus.active => l10n?.memberCoOwnerChip ?? 'Co-owner',
            CoOwnerStatus.passive =>
              l10n?.memberCoOwnerPassiveChip ?? 'Co-owner (passive)',
            CoOwnerStatus.none => l10n?.memberPageNone ?? 'None',
          },
          onTap: () => pickMemberCoOwner(context, ref, member),
        ),
      if (isOwner && coOwnerOn && member.coOwner != CoOwnerStatus.none && active)
        _ManageTile(
          tileKey: const ValueKey('member-page-coowner-activate'),
          icon: Icons.military_tech_outlined,
          title: l10n?.coOwnerActivate ?? 'Promote to owner now',
          onTap: () => activateMemberCoOwner(context, ref, member),
        ),
      if (isOwner && !member.isOwner && active && (member.isKiosk || kioskOn))
        _ManageTile(
          tileKey: const ValueKey('member-page-kiosk'),
          icon: member.isKiosk ? Icons.tablet_mac : Icons.tablet_mac_outlined,
          title: member.isKiosk
              ? (l10n?.memberUnmakeKiosk ?? 'Revert kiosk to member')
              : (l10n?.memberMakeKiosk ?? 'Make kiosk device'),
          onTap: () => toggleMemberKiosk(context, ref, member),
        ),
      if (isSelf && member.isKiosk)
        _ManageTile(
          tileKey: const ValueKey('member-page-kiosk-self'),
          icon: Icons.tablet_mac,
          title: l10n?.memberUnmakeKiosk ?? 'Revert kiosk to member',
          onTap: () => revertMyKiosk(context, ref, member),
        ),
    ];
    final booking = <Widget>[
      if (canAdmin && !isSelf && !member.isKiosk && active) ...[
        _ManageTile(
          tileKey: const ValueKey('member-page-reservation-limit'),
          icon: Icons.stacked_bar_chart_outlined,
          title: l10n?.memberReservationLimitLabel ?? 'Reservation limit',
          subtitle: member.maxActiveReservations == null
              ? (l10n?.memberReservationLimitNone ?? 'No limit')
              : '${member.maxActiveReservations}',
          onTap: () => pickMemberReservationLimit(context, ref, member),
        ),
        _ManageTile(
          tileKey: const ValueKey('member-page-simultaneous'),
          icon: Icons.splitscreen_outlined,
          title: l10n?.memberSimultaneousLimitLabel ??
              'Simultaneous reservations',
          subtitle: member.maxSimultaneousReservations == null
              ? (l10n?.memberPageWorkspaceDefaultValue(
                      BookingPolicies.allowanceFor(null, policies)) ??
                  'Workspace default (${BookingPolicies.allowanceFor(null, policies)})')
              : '${member.maxSimultaneousReservations}',
          onTap: () => pickMemberSimultaneousLimit(context, ref, member),
        ),
        if (levelOn)
          SwitchListTile(
            key: const ValueKey('member-page-level'),
            secondary: Icon(
                member.canReserveLevel ? Icons.layers : Icons.layers_outlined),
            title: Text(l10n?.memberPageLevelTitle ?? 'Whole-level bookings'),
            subtitle: Text(member.canReserveLevel
                ? (l10n?.levelPermissionAllowed ?? 'May reserve a whole level')
                : (l10n?.levelPermissionDenied ??
                    'May not reserve a whole level')),
            value: member.canReserveLevel,
            onChanged: (_) =>
                toggleMemberLevelPermission(context, ref, member),
          ),
      ],
    ];
    final billing = <Widget>[
      if (isOwner && !member.isKiosk)
        _ManageTile(
          tileKey: const ValueKey('member-page-subscription'),
          icon: Icons.percent,
          title: l10n?.memberSubscriptionLabel ?? 'Subscription',
          subtitle: l10n?.percentValue(member.subscriptionPct) ??
              '${member.subscriptionPct}%',
          onTap: () => pickMemberSubscription(context, ref, member),
        ),
      if (isOwner && !member.isKiosk && active)
        _ManageTile(
          tileKey: const ValueKey('member-page-overage'),
          icon: member.overagePolicy == OveragePolicy.blocked
              ? Icons.speed_outlined
              : Icons.speed,
          title: l10n?.memberOveragePolicyLabel ?? 'When days run out',
          subtitle: switch (member.overagePolicy) {
            OveragePolicy.blocked =>
              l10n?.overagePolicyBlocked ?? 'Block further booking',
            OveragePolicy.payg =>
              l10n?.overagePolicyPayg ?? 'Charge overage (pay-as-you-go)',
            OveragePolicy.package =>
              l10n?.overagePolicyPackage ?? 'Require buying a package',
          },
          onTap: () => pickMemberOveragePolicy(context, ref, member),
        ),
      if (negotiationVisible && !member.isKiosk && active)
        MemberNegotiationTile(
            memberId: member.id, memberName: name, isOwner: isOwner),
    ];
    final access = <Widget>[
      if (canAdmin && !member.isKiosk && !member.isOwner && active)
        _ManageTile(
          tileKey: const ValueKey('member-page-badges'),
          icon: Icons.qr_code_2_outlined,
          title: l10n?.memberBadgesTooltip ?? 'Badges',
          onTap: () => showMemberBadgesDialog(context, ref, member, name),
        ),
    ];
    final groups = <(String, List<Widget>)>[
      (l10n?.memberPageGroupMembership ?? 'Membership', membership),
      (l10n?.memberPageGroupBooking ?? 'Booking rules', booking),
      (l10n?.memberPageGroupBilling ?? 'Billing', billing),
      (l10n?.memberPageGroupAccess ?? 'Badges & access', access),
    ].where((g) => g.$2.isNotEmpty).toList();

    return Scaffold(
      key: const ValueKey('member-page'),
      appBar: AppBar(
        title: Text(name, overflow: TextOverflow.ellipsis),
        actions: [
          if (canMessage)
            IconButton(
              key: const ValueKey('member-page-message'),
              icon: const Icon(Icons.chat_bubble_outline),
              tooltip: l10n?.memberMessagesAction ?? 'Messages',
              onPressed: () =>
                  openDirectConversation(context, ref, memberId: member.id),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
        children: [
          _HeaderCard(
            member: member,
            name: name,
            isSelf: isSelf,
            hasAvatar: profile?.hasAvatar ?? false,
            statusText: profile?.statusText ?? '',
            presence: presence,
            now: now,
          ),
          const SizedBox(height: AppSpacing.md),
          _NowCard(
            info: info,
            upcoming: upcoming,
            targets: targets,
            onOpen: (r) => showReservationDetail(context, ref, r),
          ),
          if (quickActions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              key: const ValueKey('member-page-actions'),
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: quickActions,
            ),
          ],
          // Role-gated INSIDE each card, as on the old sheet.
          MemberContactCard(member: member, isSelf: isSelf),
          MemberMoneyCard(memberId: member.id, isSelf: isSelf),
          if (groups.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n?.memberPageManageHeading ?? 'Manage',
              key: const ValueKey('member-page-manage'),
              style: theme.textTheme.titleMedium,
            ),
            for (final (title, tiles) in groups)
              Card(
                margin: const EdgeInsets.only(top: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                      child: Text(
                        title,
                        style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                    ...tiles,
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  static String _statusLabel(AppLocalizations? l10n, MemberStatus status) =>
      switch (status) {
        MemberStatus.active => l10n?.memberPageStatusActive ?? 'Active',
        MemberStatus.paused => l10n?.memberStatusPaused ?? 'Paused',
        MemberStatus.pending => l10n?.memberStatusPending ?? 'Pending',
        MemberStatus.exited => l10n?.memberStatusExited ?? 'Exited',
      };
}

/// Who they are, at a glance: photo with the presence dot, name, role
/// chips, their own status line, when they were last seen, since when
/// they are a member.
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.member,
    required this.name,
    required this.isSelf,
    required this.hasAvatar,
    required this.statusText,
    required this.presence,
    required this.now,
  });

  final Member member;
  final String name;
  final bool isSelf;
  final bool hasAvatar;
  final String statusText;
  final DirectoryPresence presence;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final online = presence.kind == DirectoryPresenceKind.online;
    final chips = <Widget>[
      if (member.isOwner)
        _Chip(l10n?.memberRoleOwner ?? 'Owner',
            foreground: theme.colorScheme.onPrimary,
            background: theme.colorScheme.primary),
      if (member.isAdmin && !member.isOwner)
        _Chip(l10n?.memberRoleAdmin ?? 'Admin',
            foreground: theme.colorScheme.primary, outlined: true),
      if (member.coOwner == CoOwnerStatus.active)
        _Chip(l10n?.memberCoOwnerChip ?? 'Co-owner',
            foreground: theme.colorScheme.primary, outlined: true),
      if (member.coOwner == CoOwnerStatus.passive)
        _Chip(l10n?.memberCoOwnerPassiveChip ?? 'Co-owner (passive)',
            foreground: theme.colorScheme.onSurfaceVariant, outlined: true),
      if (member.isKiosk)
        _Chip(l10n?.memberKioskLabel ?? 'Kiosk',
            foreground: theme.colorScheme.onSurfaceVariant, outlined: true),
      if (member.isManaged)
        _Chip(l10n?.managedProfileChip ?? 'Managed',
            foreground: theme.colorScheme.tertiary, outlined: true),
      if (member.status == MemberStatus.pending)
        _Chip(l10n?.memberStatusPending ?? 'Pending',
            foreground: theme.colorScheme.onError,
            background: theme.colorScheme.error),
      if (member.status == MemberStatus.paused)
        _Chip(l10n?.memberStatusPaused ?? 'Paused',
            foreground: theme.colorScheme.onSurfaceVariant, outlined: true),
      if (member.status == MemberStatus.exited)
        _Chip(l10n?.memberStatusExited ?? 'Exited',
            foreground: theme.colorScheme.onSurfaceVariant, outlined: true),
    ];
    final presenceText = online
        ? (l10n?.directoryOnline ?? 'Online')
        : presence.lastSeenAt == null
            ? (l10n?.memberPageNeverSeen ?? 'Not seen yet')
            : relativeLastSeen(l10n, now, presence.lastSeenAt!);
    final joined = member.joinedAt;
    return Card(
      key: const ValueKey('member-page-header'),
      child: Padding(
        padding: AppSpacing.lgAll,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(clipBehavior: Clip.none, children: [
              MemberAvatar(
                userId: member.userId,
                name: name,
                hasAvatar: hasAvatar,
                radius: 32,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  key: const ValueKey('member-page-presence-dot'),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: online
                        ? AppStatusColors.successOf(brightness)
                        : theme.colorScheme.outlineVariant,
                    border: Border.all(
                        color: theme.colorScheme.surface, width: 2),
                  ),
                ),
              ),
            ]),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSelf
                        ? (l10n?.memberPageYou(name) ?? '$name (you)')
                        : name,
                    style: theme.textTheme.titleLarge,
                  ),
                  if (chips.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: chips,
                      ),
                    ),
                  if (statusText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Text(statusText,
                          key: const ValueKey('member-page-status-text'),
                          style: theme.textTheme.bodyMedium),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Row(children: [
                      Icon(Icons.circle,
                          size: 10,
                          color: online
                              ? AppStatusColors.successOf(brightness)
                              : theme.colorScheme.outline),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        presenceText,
                        key: const ValueKey('member-page-presence'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: online
                              ? AppStatusColors.successOf(brightness)
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ]),
                  ),
                  if (joined != null)
                    Text(
                      l10n?.memberPageSince(
                              DateFormat.yMMMd().format(joined.toLocal())) ??
                          'Member since ${DateFormat.yMMMd().format(joined.toLocal())}',
                      key: const ValueKey('member-page-since'),
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Where they are right now and what comes next — the live check-in,
/// the current reservation, or the next booking as a full sentence, then
/// the upcoming list, each row opening the reservation.
class _NowCard extends StatelessWidget {
  const _NowCard({
    required this.info,
    required this.upcoming,
    required this.targets,
    required this.onOpen,
  });

  final ReservationInfo? info;
  final List<Reservation> upcoming;
  final Map<String, String> targets;
  final void Function(Reservation reservation) onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final success = AppStatusColors.successOf(theme.brightness);
    final (IconData icon, Color color, String line) = switch (info) {
      CheckedInNow(:final reservation) => (
          Icons.event_available,
          success,
          l10n?.memberPageCheckedIn(
                  reservation.spaceNameFrom(targets),
                  DateFormat.Hm().format(reservation.startsAt.toLocal())) ??
              'Checked in · ${reservation.spaceNameFrom(targets)} · since ${DateFormat.Hm().format(reservation.startsAt.toLocal())}',
        ),
      ReservedNow(:final reservation) => (
          Icons.event_seat_outlined,
          theme.colorScheme.primary,
          l10n?.memberPageReservedNow(
                  reservation.spaceNameFrom(targets),
                  DateFormat.Hm().format(reservation.endsAt.toLocal())) ??
              'Reserved now · ${reservation.spaceNameFrom(targets)} · until ${DateFormat.Hm().format(reservation.endsAt.toLocal())}',
        ),
      UpcomingReservation(:final reservation) => (
          Icons.event_outlined,
          theme.colorScheme.onSurfaceVariant,
          l10n?.memberPageNext(_MemberPageBody.bookingLabel(
                  reservation, reservation.spaceNameFrom(targets))) ??
              'Next: ${_MemberPageBody.bookingLabel(reservation, reservation.spaceNameFrom(targets))}',
        ),
      null => (
          Icons.event_busy_outlined,
          theme.colorScheme.onSurfaceVariant,
          l10n?.directoryNoUpcoming ?? 'No upcoming reservations',
        ),
    };
    final rest = info == null
        ? upcoming
        : upcoming.where((r) => r.id != info!.reservation.id).toList();
    return Card(
      key: const ValueKey('member-page-now'),
      child: Padding(
        padding: AppSpacing.lgAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n?.memberPageNowHeading ?? 'Right now',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            InkWell(
              key: const ValueKey('member-page-now-line'),
              borderRadius: AppRadius.mdAll,
              onTap: info == null ? null : () => onOpen(info!.reservation),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(children: [
                  Icon(icon, size: 20, color: color),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(line,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: color)),
                  ),
                ]),
              ),
            ),
            for (final r in rest)
              InkWell(
                key: ValueKey('member-page-reservation-${r.id}'),
                borderRadius: AppRadius.mdAll,
                onTap: () => onOpen(r),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(children: [
                    Icon(Icons.event_outlined,
                        size: 20, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        _MemberPageBody.bookingLabel(
                            r, r.spaceNameFrom(targets)),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        size: 18, color: theme.colorScheme.onSurfaceVariant),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ManageTile extends StatelessWidget {
  const _ManageTile({
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

class _Chip extends StatelessWidget {
  const _Chip(this.label,
      {required this.foreground, this.background, this.outlined = false});

  final String label;
  final Color foreground;
  final Color? background;
  final bool outlined;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs / 2),
        decoration: BoxDecoration(
          color: background,
          border: outlined ? Border.all(color: foreground) : null,
          borderRadius: AppRadius.xlAll,
        ),
        child: Text(label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: foreground)),
      );
}

/// "Seen 20 h ago" — the directory's relative last-seen label, shared
/// with the row chip (#825: it now says what the number means).
String relativeLastSeen(
  AppLocalizations? l10n,
  DateTime now,
  DateTime lastSeenAt,
) {
  final diff = now.difference(lastSeenAt);
  if (diff.inMinutes < 60) {
    final minutes = diff.inMinutes < 1 ? 1 : diff.inMinutes;
    return l10n?.directoryLastSeenMinutes(minutes) ?? 'Seen $minutes min ago';
  }
  if (diff.inHours < 24) {
    return l10n?.directoryLastSeenHours(diff.inHours) ??
        'Seen ${diff.inHours} h ago';
  }
  return l10n?.directoryLastSeenDays(diff.inDays) ??
      'Seen ${diff.inDays} d ago';
}

/// #887 — takes an unredeemed handover back; the member stays managed.
Future<void> _revokeHandover(
    BuildContext context, WidgetRef ref, Member member) async {
  final l10n = AppLocalizations.of(context);
  final ok = await runGuarded(
    context,
    domain: 'workspace',
    message: 'revoke handover failed',
    errorText: l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
    action: () =>
        ref.read(workspaceRepositoryProvider).revokeHandover(member.id),
  );
  if (!ok || !context.mounted) return;
  AppSnack.success(context, l10n?.managedProfileRevoked ?? 'Handover revoked');
}
