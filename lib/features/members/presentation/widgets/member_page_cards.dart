// SPDX-License-Identifier: AGPL-3.0-or-later
// Identity, presence and management rows of the member profile.
part of '../screens/member_page.dart';

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
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final online = presence.kind == DirectoryPresenceKind.online;
    final chips = <Widget>[
      if (member.isOwner)
        _Chip(l10n.memberRoleOwner,
            foreground: theme.colorScheme.onPrimary,
            background: theme.colorScheme.primary),
      if (member.isAdmin && !member.isOwner)
        _Chip(l10n.memberRoleAdmin,
            foreground: theme.colorScheme.primary, outlined: true),
      if (member.coOwner == CoOwnerStatus.active)
        _Chip(l10n.memberCoOwnerChip,
            foreground: theme.colorScheme.primary, outlined: true),
      if (member.coOwner == CoOwnerStatus.passive)
        _Chip(l10n.memberCoOwnerPassiveChip,
            foreground: theme.colorScheme.onSurfaceVariant, outlined: true),
      if (member.isKiosk)
        _Chip(l10n.memberKioskLabel,
            foreground: theme.colorScheme.onSurfaceVariant, outlined: true),
      if (member.isManaged)
        _Chip(l10n.managedProfileChip,
            foreground: theme.colorScheme.tertiary, outlined: true),
      if (member.status == MemberStatus.pending)
        _Chip(l10n.memberStatusPending,
            foreground: theme.colorScheme.onError,
            background: theme.colorScheme.error),
      if (member.status == MemberStatus.paused)
        _Chip(l10n.memberStatusPaused,
            foreground: theme.colorScheme.onSurfaceVariant, outlined: true),
      if (member.status == MemberStatus.exited)
        _Chip(l10n.memberStatusExited,
            foreground: theme.colorScheme.onSurfaceVariant, outlined: true),
    ];
    final presenceText = online
        ? (l10n.directoryOnline)
        : presence.lastSeenAt == null
            ? (l10n.memberPageNeverSeen)
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
                        ? (l10n.memberPageYou(name))
                        : name,
                    style: theme.textTheme.titleLarge,
                  ),
                  // #928 — the member number, as the invoice prints it.
                  if (member.memberNumber.isNotEmpty)
                    Text(
                      member.memberNumber,
                      key: const ValueKey('member-page-number'),
                      style: theme.textTheme.bodySmall,
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
                      l10n.memberPageSince(
                              DateFormat.yMMMd().format(joined.toLocal())),
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
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final success = AppStatusColors.successOf(theme.brightness);
    final (IconData icon, Color color, String line) = switch (info) {
      CheckedInNow(:final reservation) => (
          Icons.event_available,
          success,
          l10n.memberPageCheckedIn(
                  reservation.spaceNameFrom(targets),
                  appFormatOf(context).time(reservation.startsAt)),
        ),
      ReservedNow(:final reservation) => (
          Icons.event_seat_outlined,
          theme.colorScheme.primary,
          l10n.memberPageReservedNow(
                  reservation.spaceNameFrom(targets),
                  appFormatOf(context).time(reservation.endsAt)),
        ),
      UpcomingReservation(:final reservation) => (
          Icons.event_outlined,
          theme.colorScheme.onSurfaceVariant,
          l10n.memberPageNext(_MemberPageBody.bookingLabel(appFormatOf(context),
                  reservation, reservation.spaceNameFrom(targets))),
        ),
      null => (
          Icons.event_busy_outlined,
          theme.colorScheme.onSurfaceVariant,
          l10n.directoryNoUpcoming,
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
            Text(l10n.memberPageNowHeading,
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
                        _MemberPageBody.bookingLabel(appFormatOf(context),
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

/// What the page's tiles read, gathered once by the page's build.
class _PageCtx {
  const _PageCtx({
    required this.context,
    required this.ref,
    required this.member,
    required this.name,
    required this.l10n,
    required this.me,
    required this.features,
    required this.perms,
    required this.email,
    required this.policies,
    required this.isSelf,
    required this.active,
    required this.pending,
    required this.canAdmin,
    required this.isOwner,
    required this.whatsappUri,
    required this.canMessage,
    required this.servicesOn,
    required this.reportsOn,
    required this.kioskOn,
    required this.coOwnerOn,
    required this.levelOn,
    required this.rolesOn,
    required this.negotiationVisible,
  });

  final BuildContext context;
  final WidgetRef ref;
  final Member member;
  final String name;
  final AppLocalizations l10n;
  final Member? me;
  final Set<WorkspaceFeature> features;
  final Set<WorkspacePermission> perms;
  final String email;
  final BookingPolicies policies;
  final bool isSelf;
  final bool active;
  final bool pending;
  final bool canAdmin;
  final bool isOwner;
  final Uri? whatsappUri;
  final bool canMessage;
  final bool servicesOn;
  final bool reportsOn;
  final bool kioskOn;
  final bool coOwnerOn;
  final bool levelOn;
  final bool rolesOn;
  final bool negotiationVisible;

  /// Opens [uri] with the platform; a refusal is traced and told.
  Future<void> launch(Uri uri) async {
    try {
      final handled = await ref.read(linkLauncherProvider)(uri);
      if (!handled) throw StateError('no handler for $uri');
    } on Object catch (e, st) {
      TraceLogger.instance.error(
        'members',
        'link launch failed',
        error: e,
        stackTrace: st,
      );
      if (!context.mounted) return;
      AppSnack.error(context, l10n.workspaceGenericError);
    }
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

List<Widget> _memberMoneyTiles(
  Member m,
  Set<WorkspaceFeature> f,
  Set<WorkspacePermission> p,
) => [
  // carnets, VIES, certificates
  if (f.contains(WorkspaceFeature.carnets) && !m.isKiosk)
    MemberCarnetTile(
      memberId: m.id,
      canSell: p.contains(WorkspacePermission.issueInvoices),
    ), // #1279
  if (f.contains(WorkspaceFeature.viesVerification) &&
      !m.isKiosk &&
      p.contains(WorkspacePermission.issueInvoices))
    ViesCheckTile(workspaceId: m.workspaceId, memberId: m.id), // #2354
  if (f.contains(WorkspaceFeature.salesTax) &&
      !m.isKiosk &&
      p.contains(WorkspacePermission.manageBilling))
    MemberTaxCertificatesTile(
      workspaceId: m.workspaceId,
      memberId: m.id,
      canManage: true,
    ), // #2362
];
List<Widget> _quickActions(_PageCtx c) {
  final context = c.context;
  final ref = c.ref;
  final member = c.member;
  final name = c.name;
  final l10n = c.l10n;
  final perms = c.perms;
  final email = c.email;
  final isSelf = c.isSelf;
  final active = c.active;
  final canAdmin = c.canAdmin;
  final whatsappUri = c.whatsappUri;
  final canMessage = c.canMessage;
  final servicesOn = c.servicesOn;
  final reportsOn = c.reportsOn;
  return <Widget>[
    if (canMessage)
      FilledButton.tonalIcon(
        key: const ValueKey('member-page-action-message'),
        icon: const Icon(Icons.chat_bubble_outline),
        label: Text(l10n.memberMessagesAction),
        onPressed: () =>
            openDirectConversation(context, ref, memberId: member.id),
      ),
    if (whatsappUri != null)
      FilledButton.tonalIcon(
        key: const ValueKey('member-page-action-wa'),
        icon: const Icon(Icons.chat_outlined),
        label: Text(l10n.directoryWhatsapp),
        onPressed: () => c.launch(whatsappUri),
      ),
    if (email.isNotEmpty && !isSelf)
      FilledButton.tonalIcon(
        key: const ValueKey('member-page-action-email'),
        icon: const Icon(Icons.mail_outline),
        label: Text(l10n.memberPageEmailAction),
        onPressed: () =>
            c.launch(Uri(scheme: 'mailto', path: email)),
      ),
    // #2137 — record_service_charge accepts manageServices too.
    if (servicesOn &&
        (canAdmin || perms.contains(WorkspacePermission.manageServices)) &&
        !member.isKiosk &&
        active)
      FilledButton.tonalIcon(
        key: const ValueKey('member-page-action-service'),
        icon: const Icon(Icons.room_service_outlined),
        label: Text(l10n.memberPageAddService),
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
        label: Text(l10n.memberSendAgreement),
        onPressed: () => sendMemberAgreement(context, ref, member, name),
      ),
  ];
}

List<Widget> _membershipTiles(_PageCtx c) {
  final workspace = c.ref.watch(currentWorkspaceProvider).value;
  final context = c.context;
  final ref = c.ref;
  final member = c.member;
  final l10n = c.l10n;
  final perms = c.perms;
  final isSelf = c.isSelf;
  final active = c.active;
  final pending = c.pending;
  final canAdmin = c.canAdmin;
  final isOwner = c.isOwner;
  final kioskOn = c.kioskOn;
  final coOwnerOn = c.coOwnerOn;
  final rolesOn = c.rolesOn;
  return <Widget>[
    if (pending && !isSelf && canAdmin) ...[
      _ManageTile(
        tileKey: const ValueKey('member-page-approve'),
        icon: Icons.how_to_reg_outlined,
        title: l10n.memberApprove,
        onTap: () => decideMemberJoin(context, ref, member, approve: true),
      ),
      _ManageTile(
        tileKey: const ValueKey('member-page-reject'),
        icon: Icons.person_off_outlined,
        title: l10n.memberRejectJoin,
        onTap: () => decideMemberJoin(context, ref, member, approve: false),
      ),
    ],
    // #887 — the admin runs a managed member's identity and hands
    // the profile over with a bound invitation.
    if (member.isManaged && canAdmin) ...[
      _ManageTile(
        tileKey: const ValueKey('member-page-managed-edit'),
        icon: Icons.contact_mail_outlined,
        title: l10n.managedProfileEdit,
        // #915 — the address comes from BEHIND the rule, and asking
        // for it is written down. An admin the rule does not name sees
        // the name on the tile and nothing under it.
        subtitle:
            (ref.watch(managedIdentityProvider(member.id)).value?.identity ??
                    PersonalInfo.empty)
                .postalBlock(
                  workspaceCountry: workspace?.countryCode ?? '',
                  // #912 — the title the person asked for, in the reader's
                  // language, exactly as the document will print it.
                  courtesyWord: courtesyWord(
                    l10n,
                    (ref
                                .watch(managedIdentityProvider(member.id))
                                .value
                                ?.identity ??
                            PersonalInfo.empty)
                        .courtesy,
                  ),
                )
                .replaceAll('\n', ', '),
        onTap: () => context.push('/members/managed?member=${member.id}'),
      ),
      if (workspace != null)
        _ManageTile(
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
      _ManageTile(
        tileKey: const ValueKey('member-page-revoke-handover'),
        icon: Icons.link_off_outlined,
        title: l10n.managedProfileRevoke,
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
            ? (l10n.memberReactivate)
            : (l10n.memberPause),
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
            ? (l10n.memberMakeMember)
            : (l10n.memberMakeAdmin),
        subtitle: member.isAdmin
            ? (l10n.memberRoleAdmin)
            : (l10n.memberRoleMember),
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
        title: l10n.coOwnerAction,
        subtitle: switch (member.coOwner) {
          CoOwnerStatus.active => l10n.memberCoOwnerChip,
          CoOwnerStatus.passive => l10n.memberCoOwnerPassiveChip,
          CoOwnerStatus.none => l10n.memberPageNone,
        },
        onTap: () => pickMemberCoOwner(context, ref, member),
      ),
    if (isOwner && coOwnerOn && member.coOwner != CoOwnerStatus.none && active)
      _ManageTile(
        tileKey: const ValueKey('member-page-coowner-activate'),
        icon: Icons.military_tech_outlined,
        title: l10n.coOwnerActivate,
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
            ? (l10n.memberUnmakeKiosk)
            : (l10n.memberMakeKiosk),
        onTap: () => toggleMemberKiosk(context, ref, member),
      ),
    if (isSelf && member.isKiosk)
      _ManageTile(
        tileKey: const ValueKey('member-page-kiosk-self'),
        icon: Icons.tablet_mac,
        title: l10n.memberUnmakeKiosk,
        onTap: () => revertMyKiosk(context, ref, member),
      ),
  ];
}

List<Widget> _bookingTiles(_PageCtx c) {
  final context = c.context;
  final ref = c.ref;
  final member = c.member;
  final l10n = c.l10n;
  final perms = c.perms;
  final policies = c.policies;
  final isSelf = c.isSelf;
  final active = c.active;
  final canAdmin = c.canAdmin;
  final levelOn = c.levelOn;
  return <Widget>[
    // #2137 — the booking allowances are also manageReservations'.
    if ((canAdmin || perms.contains(WorkspacePermission.manageReservations)) &&
        !isSelf &&
        !member.isKiosk &&
        active) ...[
      _ManageTile(
        tileKey: const ValueKey('member-page-reservation-limit'),
        icon: Icons.stacked_bar_chart_outlined,
        title: l10n.memberReservationLimitLabel,
        subtitle: member.maxActiveReservations == null
            ? (l10n.memberReservationLimitNone)
            : '${member.maxActiveReservations}',
        onTap: () => pickMemberReservationLimit(context, ref, member),
      ),
      _ManageTile(
        tileKey: const ValueKey('member-page-simultaneous'),
        icon: Icons.splitscreen_outlined,
        title: l10n.memberSimultaneousLimitLabel,
        subtitle: member.maxSimultaneousReservations == null
            ? (l10n.memberPageWorkspaceDefaultValue(
                BookingPolicies.allowanceFor(null, policies),
              ))
            : '${member.maxSimultaneousReservations}',
        onTap: () => pickMemberSimultaneousLimit(context, ref, member),
      ),
      // #985 — who this member is for VAT.
      if (canAdmin &&
          ref
              .watch(enabledFeaturesSyncProvider)
              .contains(WorkspaceFeature.vatCounterparty))
        _ManageTile(
          tileKey: const ValueKey('member-page-vat-treatment'),
          icon: Icons.account_balance_outlined,
          title: l10n.memberVatTreatmentLabel,
          subtitle: vatTreatmentName(
            l10n,
            VatTreatment.fromWire(member.vatTreatment),
          ),
          onTap: () => pickMemberVatTreatment(context, ref, member),
        ),
      // #1916 — whether this customer acts as a business or a consumer.
      if (perms.contains(WorkspacePermission.issueInvoices) &&
          ref
              .watch(enabledFeaturesSyncProvider)
              .contains(WorkspaceFeature.invoicing))
        _ManageTile(
          tileKey: const ValueKey('member-page-customer-capacity'),
          icon: Icons.storefront_outlined,
          title: l10n.customerCapacityLabel,
          subtitle: customerCapacityName(l10n, member.customerCapacity),
          onTap: () => pickMemberCustomerCapacity(context, ref, member),
        ),
      // #2358 — where this customer receives e-invoices.
      if (perms.contains(WorkspacePermission.issueInvoices) &&
          ref
              .watch(enabledFeaturesSyncProvider)
              .contains(WorkspaceFeature.invoicing))
        MemberEInvoiceAddressTile(member: member),
      // #945 — the site whose address this member's documents carry.
      if (canAdmin &&
          ref
              .watch(enabledFeaturesSyncProvider)
              .contains(WorkspaceFeature.multiSite))
        _ManageTile(
          tileKey: const ValueKey('member-page-home-site'),
          icon: Icons.location_city_outlined,
          title: l10n.memberHomeSiteLabel,
          subtitle:
              (ref.watch(sitesProvider).value ?? const <Site>[])
                  .where(
                    (s) => member.homeSiteId == null
                        ? s.isDefault
                        : s.id == member.homeSiteId,
                  )
                  .map((s) => s.name)
                  .firstOrNull ??
              (l10n.memberHomeSiteDefault),
          onTap: () => pickMemberHomeSite(context, ref, member),
        ),
      if (levelOn)
        SwitchListTile(
          key: const ValueKey('member-page-level'),
          secondary: Icon(
            member.canReserveLevel ? Icons.layers : Icons.layers_outlined,
          ),
          title: Text(l10n.memberPageLevelTitle),
          subtitle: Text(
            member.canReserveLevel
                ? (l10n.levelPermissionAllowed)
                : (l10n.levelPermissionDenied),
          ),
          value: member.canReserveLevel,
          onChanged: (_) => toggleMemberLevelPermission(context, ref, member),
        ),
    ],
  ];
}

List<Widget> _billingTiles(_PageCtx c) {
  final context = c.context;
  final ref = c.ref;
  final member = c.member;
  final name = c.name;
  final l10n = c.l10n;
  final features = c.features;
  final perms = c.perms;
  final active = c.active;
  final isOwner = c.isOwner;
  final negotiationVisible = c.negotiationVisible;
  return <Widget>[
    ..._memberMoneyTiles(member, features, perms),
    if (isOwner && !member.isKiosk)
      _ManageTile(
        tileKey: const ValueKey('member-page-subscription'),
        icon: Icons.percent,
        title: l10n.memberSubscriptionLabel,
        subtitle: subscriptionText(l10n, member.subscriptionPct),
        onTap: () => pickMemberSubscription(context, ref, member),
      ),
    if (isOwner && !member.isKiosk && active)
      _ManageTile(
        tileKey: const ValueKey('member-page-overage'),
        icon: member.overagePolicy == OveragePolicy.blocked
            ? Icons.speed_outlined
            : Icons.speed,
        title: l10n.memberOveragePolicyLabel,
        subtitle: switch (member.overagePolicy) {
          OveragePolicy.blocked => l10n.overagePolicyBlocked,
          OveragePolicy.payg => l10n.overagePolicyPayg,
          OveragePolicy.package => l10n.overagePolicyPackage,
        },
        onTap: () => pickMemberOveragePolicy(context, ref, member),
      ),
    if (negotiationVisible && !member.isKiosk && active)
      MemberNegotiationTile(
        memberId: member.id,
        memberName: name,
        isOwner: isOwner,
      ),
  ];
}

List<Widget> _accessTiles(_PageCtx c) {
  final context = c.context;
  final ref = c.ref;
  final member = c.member;
  final name = c.name;
  final l10n = c.l10n;
  final active = c.active;
  final canAdmin = c.canAdmin;
  return <Widget>[
    if (canAdmin && !member.isKiosk && !member.isOwner && active)
      _ManageTile(
        tileKey: const ValueKey('member-page-badges'),
        icon: Icons.qr_code_2_outlined,
        title: l10n.memberBadgesTooltip,
        onTap: () => showMemberBadgesDialog(context, ref, member, name),
      ),
  ];
}

Future<void> _revokeHandover(
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
