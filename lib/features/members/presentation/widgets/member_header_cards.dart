// SPDX-License-Identifier: AGPL-3.0-or-later
// #2494 — the identity cards at the top of the member profile: who they are
// and what they are doing now. Split out of member_page (was a part file).
import 'package:flutter/material.dart';
import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../profile/presentation/widgets/member_avatar.dart';
import '../../../reservations/domain/reservation.dart';
import '../../../workspace/domain/member.dart';
import '../../domain/directory_status.dart';
import '../last_seen_label.dart';

/// Who they are, at a glance: photo with the presence dot, name, role
/// chips, their own status line, when they were last seen, since when
/// they are a member.
class MemberHeaderCard extends StatelessWidget {
  const MemberHeaderCard({
    super.key,
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
        MemberChip(l10n.memberRoleOwner,
            foreground: theme.colorScheme.onPrimary,
            background: theme.colorScheme.primary),
      if (member.isAdmin && !member.isOwner)
        MemberChip(l10n.memberRoleAdmin,
            foreground: theme.colorScheme.primary, outlined: true),
      if (member.coOwner == CoOwnerStatus.active)
        MemberChip(l10n.memberCoOwnerChip,
            foreground: theme.colorScheme.primary, outlined: true),
      if (member.coOwner == CoOwnerStatus.passive)
        MemberChip(l10n.memberCoOwnerPassiveChip,
            foreground: theme.colorScheme.onSurfaceVariant, outlined: true),
      if (member.isKiosk)
        MemberChip(l10n.memberKioskLabel,
            foreground: theme.colorScheme.onSurfaceVariant, outlined: true),
      if (member.isManaged)
        MemberChip(l10n.managedProfileChip,
            foreground: theme.colorScheme.tertiary, outlined: true),
      if (member.status == MemberStatus.pending)
        MemberChip(l10n.memberStatusPending,
            foreground: theme.colorScheme.onError,
            background: theme.colorScheme.error),
      if (member.status == MemberStatus.paused)
        MemberChip(l10n.memberStatusPaused,
            foreground: theme.colorScheme.onSurfaceVariant, outlined: true),
      if (member.status == MemberStatus.exited)
        MemberChip(l10n.memberStatusExited,
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
                              appFormatOf(context).dates(DateShape.date).format(appFormatOf(context).wall(joined))),
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
class MemberNowCard extends StatelessWidget {
  const MemberNowCard({
    super.key,
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
          l10n.memberPageNext(_memberBookingLabel(appFormatOf(context),
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
                        _memberBookingLabel(appFormatOf(context),
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

class MemberChip extends StatelessWidget {
  const MemberChip(this.label,
      {super.key,
      required this.foreground,
      this.background,
      this.outlined = false});

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

/// "Wed 2 · 08:00 · A1" — the directory's house style for a booking.
String _memberBookingLabel(
  AppFormat format,
  Reservation reservation,
  String seatName,
) {
  final local = format.wall(reservation.startsAt);
  final day =
      '${format.dates(DateShape.weekday).format(local)} ${format.dates(DateShape.day).format(local)}';
  final when = '$day · ${format.time(reservation.startsAt)}';
  return seatName.isEmpty ? when : '$when · $seatName';
}
