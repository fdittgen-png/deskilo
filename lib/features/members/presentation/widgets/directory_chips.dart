// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2494 — the directory's chips and its reservation tile, shared by the
// row and the profile sheet (moved from directory_screen_part2/3.dart).
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../reservations/domain/reservation.dart';
import '../../application/directory_card.dart';
import '../../domain/directory_status.dart';
import '../screens/member_page.dart' show relativeLastSeen;

/// The presence chip for [card] — unchanged rendering from #224 — or
/// null when the member was never seen (offline without a heartbeat
/// renders no presence chip at all). Shared by the row and the detail
/// sheet — [keyPrefix] keeps their [ValueKey]s distinct so tests can
/// target each surface.
Widget? directoryPresenceChip(
  BuildContext context,
  AppLocalizations l10n,
  DirectoryCard card, {
  String keyPrefix = 'directory-status',
}) {
  if (!card.showsPresence) return null;
  final theme = Theme.of(context);
  final key = ValueKey('$keyPrefix-${card.member.id}');
  if (card.online) {
    return DirectoryStatusChip(
      chipKey: key,
      label: l10n.directoryOnline,
      foreground: AppStatusColors.successOf(theme.brightness),
      outlined: true,
    );
  }
  return DirectoryStatusChip(
    chipKey: key,
    label: relativeLastSeen(l10n, card.now, card.presence.lastSeenAt!),
    foreground: theme.colorScheme.onSurfaceVariant,
  );
}

/// Label of the upcoming-reservation chip (#237): localized weekday +
/// day and start time in the calendar's house style ([DateFormat.E] /
/// [DateFormat.d] / [DateFormat.Hm]) plus the seat name when the plan
/// knows one — "Tue 21 · 09:00 · A1".
String directoryUpcomingLabel(
    AppFormat format, Reservation reservation, String seatName) {
  final local = reservation.startsAt.toLocal();
  final day =
      '${DateFormat.E().format(local)} ${DateFormat.d().format(local)}';
  final when = '$day · ${format.time(reservation.startsAt)}';
  return seatName.isEmpty ? when : '$when · $seatName';
}

/// The reservation chip for [card] (#237), or null without one. Styles
/// mirror the resolver priority: checked in keeps the filled success
/// style from #224, reserved-now is outlined primary, an upcoming
/// booking is outlined neutral so it visually ranks below both.
/// [keyPrefix] keeps row and sheet [ValueKey]s distinct.
Widget? directoryReservationChip(
  BuildContext context,
  AppLocalizations l10n,
  DirectoryCard card, {
  String keyPrefix = 'directory-res',
}) {
  final info = card.reservationInfo;
  if (info == null) return null;
  final theme = Theme.of(context);
  final brightness = theme.brightness;
  final seatName = card.seatName;
  final key = ValueKey('$keyPrefix-${card.member.id}');
  return switch (info) {
    CheckedInNow() => DirectoryStatusChip(
      chipKey: key,
      label: seatName.isEmpty
          ? (l10n.directoryCheckedIn)
          : (l10n.directoryCheckedInSeat(seatName)),
      foreground: AppStatusColors.onSuccessOf(brightness),
      background: AppStatusColors.successOf(brightness),
    ),
    ReservedNow() => DirectoryStatusChip(
      chipKey: key,
      label: seatName.isEmpty
          ? (l10n.directoryReservedNow)
          : (l10n.directoryReservedNowSeat(seatName)),
      foreground: theme.colorScheme.primary,
      outlined: true,
    ),
    UpcomingReservation() => DirectoryStatusChip(
      chipKey: key,
      label: directoryUpcomingLabel(
          appFormatOf(context), info.reservation, seatName),
      foreground: theme.colorScheme.onSurfaceVariant,
      outlined: true,
    ),
  };
}

/// A compact role badge shown after the name on a directory row — owner
/// (primary, filled) and admin (outlined) only; a regular member carries
/// the default role and gets no badge, so the badge itself signals
/// elevated rights at a glance.
Widget? directoryRoleBadge(
  BuildContext context,
  AppLocalizations l10n,
  DirectoryCard card,
) {
  final theme = Theme.of(context);
  final key = ValueKey('directory-role-${card.member.id}');
  final chip = switch (card.role) {
    DirectoryRole.owner => DirectoryStatusChip(
      chipKey: key,
      label: l10n.memberRoleOwner,
      foreground: theme.colorScheme.onPrimary,
      background: theme.colorScheme.primary,
    ),
    DirectoryRole.admin => DirectoryStatusChip(
      chipKey: key,
      label: l10n.memberRoleAdmin,
      foreground: theme.colorScheme.primary,
      outlined: true,
    ),
    DirectoryRole.member => null,
  };
  if (chip == null) return null;
  return Padding(
    padding: const EdgeInsets.only(left: AppSpacing.xs),
    child: chip,
  );
}

/// One tappable reservation in the member detail sheet: weekday + day,
/// start time and seat/office name (the [directoryUpcomingLabel] house
/// style), with a filled marker when the member is already checked in.
/// Tapping opens the full reservation detail sheet for that booking.
class DirectoryReservationTile extends StatelessWidget {
  const DirectoryReservationTile({
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
                directoryUpcomingLabel(
                    appFormatOf(context), reservation, seatName),
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
class DirectoryStatusChip extends StatelessWidget {
  const DirectoryStatusChip({
    super.key,
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
