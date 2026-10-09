// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../../core/vat/vat_treatment.dart';
import '../../../../core/motion/motion.dart';
import '../../../../l10n/app_localizations_en.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../workspace/presentation/member_labels.dart';
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
import '../../../workspace/presentation/member_customer_capacity.dart';
import '../../../workspace/presentation/member_vat_treatment.dart';
import '../../../workspace/presentation/widgets/member_roles_card.dart';
import '../../../workspace/presentation/widgets/open_conversation.dart';
import '../../../workspace/presentation/widgets/invite_sheet.dart';
import '../../../workspace/domain/invite_uri.dart';
import '../../../../core/trace/guarded.dart';
import '../../../money/presentation/widgets/payment_terms_card.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/directory_status.dart';
import '../../providers/directory_providers.dart';
import '../widgets/member_contact_card.dart';
import '../widgets/member_money_card.dart';
import '../../../profile/presentation/courtesy_words.dart';
import '../../../profile/domain/personal_info.dart';
import '../../../workspace/domain/site.dart';
import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../money/presentation/widgets/member_carnet_tile.dart';

part '../widgets/member_page_cards.dart';

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
  static String bookingLabel(AppFormat format, Reservation reservation, String seatName) {
    final local = reservation.startsAt.toLocal();
    final day =
        '${DateFormat.E().format(local)} ${DateFormat.d().format(local)}';
    final when = '$day · ${format.time(reservation.startsAt)}';
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
    final rolesOn = features.contains(WorkspaceFeature.roleAssignment);
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
      // #2137 — record_service_charge accepts manageServices too.
      if (servicesOn &&
          (canAdmin || perms.contains(WorkspacePermission.manageServices)) &&
          !member.isKiosk &&
          active)
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
          // #915 — the address comes from BEHIND the rule, and asking
          // for it is written down. An admin the rule does not name sees
          // the name on the tile and nothing under it.
          subtitle: (ref.watch(managedIdentityProvider(member.id)).value?.identity ?? PersonalInfo.empty)
              .postalBlock(
                workspaceCountry: workspace?.countryCode ?? '',
                // #912 — the title the person asked for, in the reader's
                // language, exactly as the document will print it.
                courtesyWord: courtesyWord(
                    l10n,
                    (ref.watch(managedIdentityProvider(member.id)).value?.identity ?? PersonalInfo.empty)
                        .courtesy),
              )
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
          subtitle: memberStatusLabel(l10n, member.status),
          onTap: () => toggleMemberPaused(context, ref, member),
        ),
      // #2085 — with roleAssignment the Roles card gives this one too.
      if (isOwner && !member.isOwner && !member.isKiosk && active && !rolesOn)
        _ManageTile(
          tileKey: const ValueKey('member-page-role'),
          icon: member.isAdmin
              ? Icons.remove_moderator_outlined
              : Icons.add_moderator_outlined,
          title: member.isAdmin
              ? (l10n?.memberMakeMember ?? 'Take back the Administrator role')
              : (l10n?.memberMakeAdmin ?? 'Give the Administrator role'),
          subtitle: member.isAdmin
              ? (l10n?.memberRoleAdmin ?? 'Administrator')
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
              l10n?.memberCoOwnerPassiveChip ?? 'Successor',
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
      if (perms.contains(WorkspacePermission.operateKiosk) &&
          !member.isOwner &&
          active &&
          (member.isKiosk || kioskOn))
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
      // #2137 — the booking allowances are also manageReservations'.
      if ((canAdmin || perms.contains(WorkspacePermission.manageReservations)) && !isSelf && !member.isKiosk && active) ...[
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
        // #985 — who this member is for VAT.
        if (canAdmin && ref.watch(enabledFeaturesSyncProvider).contains(WorkspaceFeature.vatCounterparty))
          _ManageTile(
            tileKey: const ValueKey('member-page-vat-treatment'),
            icon: Icons.account_balance_outlined,
            title: l10n?.memberVatTreatmentLabel ?? 'VAT treatment',
            subtitle: vatTreatmentName(
                l10n, VatTreatment.fromWire(member.vatTreatment)),
            onTap: () => pickMemberVatTreatment(context, ref, member),
          ),
        // #1916 — whether this customer acts as a business or a consumer.
        if (perms.contains(WorkspacePermission.issueInvoices) &&
            ref.watch(enabledFeaturesSyncProvider).contains(WorkspaceFeature.invoicing))
          _ManageTile(
            tileKey: const ValueKey('member-page-customer-capacity'),
            icon: Icons.storefront_outlined,
            title: l10n?.customerCapacityLabel ?? 'Customer capacity',
            subtitle: customerCapacityName(l10n, member.customerCapacity),
            onTap: () => pickMemberCustomerCapacity(context, ref, member),
          ),
        // #945 — the site whose address this member's documents carry.
        if (canAdmin && ref.watch(enabledFeaturesSyncProvider).contains(WorkspaceFeature.multiSite))
          _ManageTile(
            tileKey: const ValueKey('member-page-home-site'),
            icon: Icons.location_city_outlined,
            title: l10n?.memberHomeSiteLabel ?? 'Home site',
            subtitle: (ref.watch(sitesProvider).value ?? const <Site>[])
                    .where((s) => member.homeSiteId == null ? s.isDefault : s.id == member.homeSiteId)
                    .map((s) => s.name)
                    .firstOrNull ??
                (l10n?.memberHomeSiteDefault ?? 'Workspace address'),
            onTap: () => pickMemberHomeSite(context, ref, member),
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
      if (features.contains(WorkspaceFeature.carnets) && !member.isKiosk)
        MemberCarnetTile(memberId: member.id,
            canSell: perms.contains(WorkspacePermission.issueInvoices)), // #1279
      if (isOwner && !member.isKiosk)
        _ManageTile(
          tileKey: const ValueKey('member-page-subscription'),
          icon: Icons.percent,
          title: l10n?.memberSubscriptionLabel ?? 'Subscription',
          subtitle: subscriptionText(l10n, member.subscriptionPct),
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
      body: _MemberSections(
        sections: [
          _MemberSection(
            'profile',
            (l10n ?? AppLocalizationsEn()).uxProfileSection,
            [
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
                // #1187 — the actions were a Wrap of buttons each sized to
                // its own label: three rows, three widths, ragged right. Two
                // equal columns instead, and a lone last button spans them,
                // so the group reads as a group.
                LayoutBuilder(
                  key: const ValueKey('member-page-actions'),
                  builder: (context, constraints) {
                    const gap = AppSpacing.sm;
                    final cell = (constraints.maxWidth - gap) / 2;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final (i, action) in quickActions.indexed)
                          SizedBox(
                            key: ValueKey('member-page-cell-$i'),
                            // A lone last button spans both columns rather
                            // than sitting half-width beside nothing.
                            width: i == quickActions.length - 1 && i.isEven
                                ? constraints.maxWidth
                                : cell,
                            child: action,
                          ),
                      ],
                    );
                  },
                ),
              ],
              // Role-gated INSIDE each card, as on the old sheet.
              MemberContactCard(member: member, isSelf: isSelf),
              MemberMoneyCard(memberId: member.id, isSelf: isSelf),
            ],
          ),
          // #2085 — the one place a member is given a role.
          if (rolesOn &&
              !member.isKiosk &&
              (isSelf ||
                  canAdmin ||
                  perms.contains(WorkspacePermission.manageRoles)))
            _MemberSection('roles', l10n?.memberRolesTitle ?? 'Roles', [
              MemberRolesCard(member: member, name: name),
            ], showHeading: false),
          if (groups.isNotEmpty)
            _MemberSection(
              'manage',
              l10n?.memberPageManageHeading ?? 'Manage',
              [
                for (final (title, tiles) in groups)
                  Card(
                    margin: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            AppSpacing.md,
                            AppSpacing.lg,
                            0,
                          ),
                          child: Text(
                            title,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        ...tiles,
                      ],
                    ),
                  ),
              ],
            ),
          if (features.contains(WorkspaceFeature.memberPaymentTerms) &&
              (isSelf || canAdmin))
            _MemberSection(
              'payment-terms',
              l10n?.paymentTermsTitle ?? 'Payment conditions',
              [PaymentTermsCard(member: member, isSelf: isSelf)],
              showHeading: false,
            ),
        ],
      ),
    );
  }

}

class _MemberSection {
  const _MemberSection(this.id, this.title, this.children, {this.showHeading = true});

  final String id;
  final String title;
  final List<Widget> children;
  final bool showHeading;
}

/// The same section shortcuts and reading width as Profile and account.
/// All sections stay mounted so keyboard focus and guide highlights can reach
/// a control below the fold without switching away from the member's form.
class _MemberSections extends StatefulWidget {
  const _MemberSections({required this.sections});

  final List<_MemberSection> sections;

  @override
  State<_MemberSections> createState() => _MemberSectionsState();
}

class _MemberSectionsState extends State<_MemberSections> {
  final _anchors = <String, GlobalKey>{};
  final _focus = <String, FocusNode>{};

  @override
  void dispose() {
    for (final node in _focus.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _jump(String id) {
    final target = _anchors[id]?.currentContext;
    if (target == null) return;
    _focus[id]?.requestFocus();
    Scrollable.ensureVisible(
      target,
      duration: motionDuration(context, MotionTokens.standard),
    );
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Column(
        children: [
          Padding(
            padding: AppSpacing.smAll,
            child: Wrap(
              key: const ValueKey('member-section-navigation'),
              spacing: AppSpacing.xs,
              children: [
                for (final section in widget.sections)
                  TextButton(
                    key: ValueKey('member-section-${section.id}'),
                    onPressed: () => _jump(section.id),
                    child: Text(section.title),
                  ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              key: const ValueKey('member-page-sections'),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                for (final section in widget.sections)
                    Focus(
                      key: _anchors.putIfAbsent(section.id, GlobalKey.new),
                      focusNode: _focus.putIfAbsent(
                        section.id,
                        () => FocusNode(skipTraversal: true),
                      ),
                    child: section.showHeading
                        ? FormSection(
                            key: ValueKey('member-page-${section.id}'),
                            title: section.title,
                            children: section.children,
                          )
                        : Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: section.children,
                            ),
                          ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
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
    final hours = diff.inHours;
    return l10n?.directoryLastSeenHours(hours) ??
        (hours == 1 ? 'Seen 1 hour ago' : 'Seen $hours hours ago');
  }
  final days = diff.inDays;
  return l10n?.directoryLastSeenDays(days) ??
      (days == 1 ? 'Seen 1 day ago' : 'Seen $days days ago');
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
