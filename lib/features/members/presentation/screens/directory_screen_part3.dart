// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'directory_screen.dart';


/// One directory row: avatar initial, name (bold when it is me), the
/// self-set status line when present, the reservation + presence chips
/// (#237) flowing in a [Wrap], trailing WhatsApp button when the member
/// shared a number. Tap opens the detail sheet; rows of sharing members
/// additionally swipe right to WhatsApp — no swipe affordance exists at
/// all without a number.
class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.name,
    this.email = '',
    required this.isSelf,
    required this.profile,
    required this.presence,
    required this.reservationInfo,
    required this.memberReservations,
    required this.targetNames,
    required this.now,
    required this.onWhatsapp,
    required this.onOpenReservation,
    this.onNotify,
    this.onOpenPage,
  });

  final Member member;
  final String name;

  /// #825 — set when the member page is on: the tap goes there.
  final VoidCallback? onOpenPage;

  /// The member's email — non-empty only for admin/owner viewers
  /// (#410, member_emails RPC); '' renders nothing.
  final String email;
  final bool isSelf;
  final Profile? profile;
  final DirectoryPresence presence;
  final ReservationInfo? reservationInfo;
  final List<Reservation> memberReservations;
  final Map<String, String> targetNames;
  final DateTime now;
  final void Function(Uri uri) onWhatsapp;
  final void Function(Reservation reservation) onOpenReservation;

  /// Member notes (#456): null hides the affordance.
  final VoidCallback? onNotify;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    final chips = <Widget>[
      ?_reservationChip(
        context,
        l10n: l10n,
        memberId: member.id,
        info: reservationInfo,
        targetNames: targetNames,
      ),
      ?_presenceChip(
        context,
        l10n: l10n,
        memberId: member.id,
        presence: presence,
        now: now,
      ),
    ];
    final statusText = profile?.statusText ?? '';
    final whatsappUri = profile?.whatsappUri;

    final online = presence.kind == DirectoryPresenceKind.online;
    final onSite = reservationInfo is CheckedInNow;
    final tile = ListTile(
      key: const ValueKey('directory-whatsapp'),
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          MemberAvatar(
            userId: member.userId,
            name: name,
            hasAvatar: profile?.hasAvatar ?? false,
          ),
          // Presence at a glance: a ringed dot on the avatar — green
          // when online — before any text is read.
          if (online)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppStatusColors.successOf(brightness),
                  border: Border.all(
                    color: theme.colorScheme.surface,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style:
                  isSelf ? const TextStyle(fontWeight: FontWeight.bold) : null,
            ),
          ),
          ?_roleBadge(context, l10n: l10n, member: member),
        ],
      ),
      subtitle: chips.isEmpty && statusText.isEmpty && email.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (email.isNotEmpty)
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (statusText.isNotEmpty)
                  Text(
                    statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
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
              ],
            ),
      trailing: whatsappUri == null
          ? null
          : IconButton(
              key: ValueKey('directory-wa-${member.id}'),
              icon: const Icon(Icons.chat_outlined),
              tooltip: l10n.directoryWhatsapp,
              onPressed: () => onWhatsapp(whatsappUri),
            ),
      // #825 — the member page when its flag is on; the sheet otherwise.
      onTap: () => onOpenPage != null
          ? onOpenPage!()
          : showMemberProfileSheet(
              context,
              member: member,
              name: name,
              isSelf: isSelf,
              profile: profile,
              presence: presence,
              reservationInfo: reservationInfo,
              memberReservations: memberReservations,
              targetNames: targetNames,
              now: now,
              onWhatsapp: onWhatsapp,
              onOpenReservation: onOpenReservation,
              onNotify: onNotify,
            ),
    );

    // Presence-forward card: soft elevation for every member, a warm
    // success-tinted surface for whoever is checked in RIGHT NOW — the
    // room's live roster pops without reordering the list.
    final cardColor = onSite
        ? Color.alphaBlend(
            AppStatusColors.successOf(brightness).withValues(alpha: 0.10),
            theme.colorScheme.surfaceContainerLow,
          )
        : theme.colorScheme.surfaceContainerLow;
    final card = Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenGutter,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        borderRadius: AppRadius.lgAll,
        boxShadow: AppElevation.low(brightness),
      ),
      child: Material(
        color: cardColor,
        borderRadius: AppRadius.lgAll,
        clipBehavior: Clip.antiAlias,
        child: tile,
      ),
    );

    if (whatsappUri == null) return card;

    // Swipe right to chat (#232). `confirmDismiss` always resolves false:
    // the launch is a side effect and the row snaps back — Dismissible
    // never actually removes it from the list.
    return Dismissible(
      key: ValueKey('directory-swipe-${member.id}'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        onWhatsapp(whatsappUri);
        return false;
      },
      background: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenGutter,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppStatusColors.successOf(brightness),
          borderRadius: AppRadius.lgAll,
        ),
        alignment: AlignmentDirectional.centerStart,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenGutter,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat, color: AppStatusColors.onSuccessOf(brightness)),
            const SizedBox(width: AppSpacing.sm),
            Text(
              l10n.directoryWhatsapp,
              style: TextStyle(color: AppStatusColors.onSuccessOf(brightness)),
            ),
          ],
        ),
      ),
      child: card,
    );
  }
}

/// One tappable reservation in the member detail sheet: weekday + day,
/// start time and seat/office name (the [_upcomingLabel] house style),
/// with a filled marker when the member is already checked in. Tapping
/// opens the full [ReservationDetailSheet] for that booking.
class _ReservationTile extends StatelessWidget {
  const _ReservationTile({
    super.key,
    required this.reservation,
    required this.seatName,
    required this.onTap,
  });

  final Reservation reservation;
  final String seatName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checkedIn = reservation.status == ReservationStatus.checkedIn;
    return InkWell(
      key: ValueKey('directory-sheet-reservation-${reservation.id}'),
      borderRadius: AppRadius.mdAll,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Icon(
              checkedIn ? Icons.event_available : Icons.event_outlined,
              size: 20,
              color: checkedIn
                  ? AppStatusColors.successOf(theme.brightness)
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                _upcomingLabel(appFormatOf(context), reservation, seatName),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// Small pill chip: filled ([background] set), outlined, or bare muted
/// text — state is never conveyed by color alone (spec §11), the label
/// always spells it out.
class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.chipKey,
    required this.label,
    required this.foreground,
    this.background,
    this.outlined = false,
  });

  final Key chipKey;
  final String label;
  final Color foreground;
  final Color? background;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: chipKey,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs / 2,
      ),
      decoration: BoxDecoration(
        color: background,
        border: outlined ? Border.all(color: foreground) : null,
        borderRadius: AppRadius.xlAll,
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: foreground),
      ),
    );
  }
}
