// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'directory_screen.dart';


/// The presence chip for [presence] — unchanged rendering from #224 —
/// or null when the member was never seen (offline without a heartbeat
/// renders no presence chip at all). Shared by the row and the detail
/// sheet — [keyPrefix] keeps their [ValueKey]s distinct so tests can
/// target each surface.
Widget? _presenceChip(
  BuildContext context, {
  required AppLocalizations l10n,
  required String memberId,
  required DirectoryPresence presence,
  required DateTime now,
  String keyPrefix = 'directory-status',
}) {
  final theme = Theme.of(context);
  return switch (presence.kind) {
    DirectoryPresenceKind.online => _StatusChip(
      chipKey: ValueKey('$keyPrefix-$memberId'),
      label: l10n.directoryOnline,
      foreground: AppStatusColors.successOf(theme.brightness),
      outlined: true,
    ),
    DirectoryPresenceKind.offline =>
      presence.lastSeenAt == null
          ? null
          : _StatusChip(
              chipKey: ValueKey('$keyPrefix-$memberId'),
              label: relativeLastSeen(l10n, now, presence.lastSeenAt!),
              foreground: theme.colorScheme.onSurfaceVariant,
            ),
  };
}

/// Label of the upcoming-reservation chip (#237): localized weekday +
/// day and start time in the calendar's house style ([DateFormat.E] /
/// [DateFormat.d] / [DateFormat.Hm]) plus the seat name when the plan
/// knows one — "Tue 21 · 09:00 · A1".
String _upcomingLabel(AppFormat format, Reservation reservation, String seatName) {
  final local = reservation.startsAt.toLocal();
  final day =
      '${DateFormat.E().format(local)} ${DateFormat.d().format(local)}';
  final when = '$day · ${format.time(reservation.startsAt)}';
  return seatName.isEmpty ? when : '$when · $seatName';
}

/// The reservation chip for [info] (#237), or null without one. Styles
/// mirror the resolver priority: checked in keeps the filled success
/// style from #224, reserved-now is outlined primary, an upcoming
/// booking is outlined neutral so it visually ranks below both.
/// [keyPrefix] keeps row and sheet [ValueKey]s distinct.
Widget? _reservationChip(
  BuildContext context, {
  required AppLocalizations l10n,
  required String memberId,
  required ReservationInfo? info,
  required Map<String, String> targetNames,
  String keyPrefix = 'directory-res',
}) {
  if (info == null) return null;
  final theme = Theme.of(context);
  final brightness = theme.brightness;
  final reservation = info.reservation;
  // #587 — a deleted target falls back to its audit substitution text.
  final seatName = reservation.spaceNameFrom(targetNames);
  return switch (info) {
    CheckedInNow() => _StatusChip(
      chipKey: ValueKey('$keyPrefix-$memberId'),
      label: seatName.isEmpty
          ? (l10n.directoryCheckedIn)
          : (l10n.directoryCheckedInSeat(seatName)),
      foreground: AppStatusColors.onSuccessOf(brightness),
      background: AppStatusColors.successOf(brightness),
    ),
    ReservedNow() => _StatusChip(
      chipKey: ValueKey('$keyPrefix-$memberId'),
      label: seatName.isEmpty
          ? (l10n.directoryReservedNow)
          : (l10n.directoryReservedNowSeat(seatName)),
      foreground: theme.colorScheme.primary,
      outlined: true,
    ),
    UpcomingReservation() => _StatusChip(
      chipKey: ValueKey('$keyPrefix-$memberId'),
      label: _upcomingLabel(appFormatOf(context), reservation, seatName),
      foreground: theme.colorScheme.onSurfaceVariant,
      outlined: true,
    ),
  };
}

/// A compact role badge shown after the name on a directory row and in
/// the detail sheet header — owner (primary, filled) and admin (outlined)
/// only; a regular member carries the default role and gets no badge, so
/// the badge itself signals elevated rights at a glance. Roles are
/// additive flags (spec §2) — owner outranks admin.
Widget? _roleBadge(
  BuildContext context, {
  required AppLocalizations l10n,
  required Member member,
}) {
  final theme = Theme.of(context);
  if (member.isOwner) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xs),
      child: _StatusChip(
        chipKey: ValueKey('directory-role-${member.id}'),
        label: l10n.memberRoleOwner,
        foreground: theme.colorScheme.onPrimary,
        background: theme.colorScheme.primary,
      ),
    );
  }
  if (member.isAdmin) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xs),
      child: _StatusChip(
        chipKey: ValueKey('directory-role-${member.id}'),
        label: l10n.memberRoleAdmin,
        foreground: theme.colorScheme.primary,
        outlined: true,
      ),
    );
  }
  return null;
}

/// The member's public-profile bottom sheet (#232): avatar, name, role
/// (roles are additive flags, spec §2 — owner wins the single label),
/// the automatic reservation + presence chips (#237), the self-set
/// status line (#231) and the WhatsApp contact button when the member
/// shared a number (#223).
/// #695 — PUBLIC so the messaging centre opens the SAME profile the
/// directory does, rather than growing a second one that drifts.
///
/// It stays in this file because three of its parts — the presence
/// chip, the reservation chip and the reservation tile — are shared with
/// the directory rows above. Moving the sheet alone would have split a
/// widget from its own pieces; moving all four would have moved half the
/// screen. [openMemberProfile] below is the door for other features.
Future<void> showMemberProfileSheet(
  BuildContext context, {
  required Member member,
  required String name,
  required bool isSelf,
  required Profile? profile,
  required DirectoryPresence presence,
  required ReservationInfo? reservationInfo,
  required List<Reservation> memberReservations,
  required Map<String, String> targetNames,
  required DateTime now,
  required void Function(Uri uri) onWhatsapp,
  required void Function(Reservation reservation) onOpenReservation,
  // Member notes (#456): null hides the affordance (feature off, self).
  VoidCallback? onNotify,
}) {
  return showAppSheet<void>(
    context: context,
    // Scrollable so a full sheet (role + chip + status + button) never
    // overflows small viewports.
    isScrollControlled: true,
    builder: (sheetContext) {
      final l10n = sheetContext.l10n;
      final theme = Theme.of(sheetContext);
      final role = member.isOwner
          ? (l10n.memberRoleOwner)
          : member.isAdmin
          ? (l10n.memberRoleAdmin)
          : (l10n.memberRoleMember);
      final chips = <Widget>[
        ?_reservationChip(
          sheetContext,
          l10n: l10n,
          memberId: member.id,
          info: reservationInfo,
          targetNames: targetNames,
          keyPrefix: 'directory-sheet-res',
        ),
        ?_presenceChip(
          sheetContext,
          l10n: l10n,
          memberId: member.id,
          presence: presence,
          now: now,
          keyPrefix: 'directory-sheet-status',
        ),
      ];
      final statusText = profile?.statusText ?? '';
      final whatsappUri = profile?.whatsappUri;
      return Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.xl,
          right: AppSpacing.xl,
          top: AppSpacing.xl,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.xl,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  MemberAvatar(
                    userId: member.userId,
                    name: name,
                    hasAvatar: profile?.hasAvatar ?? false,
                    radius: 24,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: isSelf ? FontWeight.bold : null,
                          ),
                        ),
                        Text(
                          role,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (chips.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: chips,
                ),
              ],
              if (statusText.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(statusText, style: theme.textTheme.bodyMedium),
              ],
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.directoryReservationsHeading,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              if (memberReservations.isEmpty)
                Text(
                  l10n.directoryNoUpcoming,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                for (final reservation in memberReservations)
                  _ReservationTile(
                    key: ValueKey('directory-reservation-tile-${reservation.id}'),
                    reservation: reservation,
                    seatName: reservation.spaceNameFrom(targetNames),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      onOpenReservation(reservation);
                    },
                  ),
              // #704 — contact, then money, on the profile of the
              // person they belong to. Each is role-gated INSIDE its own
              // widget: this sheet opens from four places, and a gate
              // repeated four times is one that gets forgotten once.
              MemberContactCard(member: member, isSelf: isSelf),
              MemberMoneyCard(memberId: member.id, isSelf: isSelf),
              const SizedBox(height: AppSpacing.lg),
              if (onNotify != null) ...[
                FilledButton.icon(
                  key: ValueKey('directory-sheet-notify-${member.id}'),
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: Text(
                      l10n.memberNotifyAction),
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    onNotify();
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (whatsappUri != null) ...[
                FilledButton.icon(
                  key: ValueKey('directory-sheet-wa-${member.id}'),
                  icon: const Icon(Icons.chat_outlined),
                  label: Text(l10n.directoryWhatsapp),
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    onWhatsapp(whatsappUri);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              TextButton(
                key: const ValueKey('directory-contact-close'),
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: Text(l10n.directoryClose),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Tappable card above the list opening the owner-set WhatsApp group
/// (#231/#232); the caller renders it only when a link is configured.
class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      key: const ValueKey('directory-group'),
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenGutter,
        vertical: AppSpacing.sm,
      ),
      child: ListTile(
        key: const ValueKey('directory-open-group'),
        leading: const Icon(Icons.groups_outlined),
        title: Text(l10n.directoryOpenGroup),
        trailing: const Icon(Icons.open_in_new),
        onTap: onOpen,
      ),
    );
  }
}
