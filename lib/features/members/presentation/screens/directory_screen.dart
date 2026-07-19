// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/links/link_launcher.dart';
import '../../../../core/theme/app_elevation.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../../profile/domain/profile.dart';
import '../../../profile/presentation/widgets/member_avatar.dart';
import '../../../reservations/domain/reservation.dart';
import '../../../reservations/presentation/widgets/reservation_detail_sheet.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../../workspace/domain/member.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/directory_status.dart';
import '../../providers/directory_providers.dart';

/// Member directory (#224, epic #222): every member sees the workspace's
/// ACTIVE members (alphabetical) with live indicators, and a WhatsApp
/// button for members who opted into sharing their number (#223).
///
/// Since #237 every row (and the detail sheet) carries TWO independent
/// chips side by side: a reservation chip — checked in (filled, with
/// seat name) > reserved now (outlined primary) > next upcoming booking
/// within 14 days (outlined neutral, "{weekday} {day} · {HH:mm} ·
/// {seat}") — and the presence chip — online (outlined) > relative
/// last-seen (muted text; no chip when never seen).
///
/// Directory v2 (#232, epic #229) adds the self-set status line (#231)
/// under the name, a tap-to-open public-profile sheet, swipe-right to
/// WhatsApp on rows of sharing members, and the owner-configured
/// WhatsApp-group tile (#231) above the list.
///
/// Deliberately NOT role-gated (unlike /members, the owner management
/// screen): visibility of names and WhatsApp numbers inside a workspace
/// is exactly what the profiles RLS already grants.
class DirectoryScreen extends ConsumerWidget {
  const DirectoryScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref
      ..invalidate(workspaceMembersProvider)
      ..invalidate(memberNamesProvider)
      ..invalidate(memberProfilesProvider)
      ..invalidate(reservationsForMonthProvider)
      ..invalidate(directoryReservationsProvider)
      ..invalidate(targetNamesProvider);
    await ref.read(workspaceMembersProvider.future);
  }

  /// Opens a member's booking in the shared [ReservationDetailSheet] —
  /// the same surface the calendar uses, so cancel/edit affordances apply
  /// to one's own upcoming bookings and stay read-only for everyone else.
  void _openReservation(BuildContext context, Reservation reservation) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ReservationDetailSheet(reservation: reservation),
    );
  }

  Future<void> _openLink(BuildContext context, WidgetRef ref, Uri uri) async {
    final l10n = AppLocalizations.of(context);
    try {
      final handled = await ref.read(linkLauncherProvider)(uri);
      if (!handled) throw StateError('no handler for $uri');
    } catch (e, st) {
      debugPrint('whatsapp launch failed: $e\n$st');
      TraceLogger.instance.error(
        'members',
        'whatsapp launch failed',
        error: e,
        stackTrace: st,
      );
      if (!context.mounted) return;
      AppSnack.error(
        context,
        l10n?.workspaceGenericError ??
            'Something went wrong. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final membersAsync = ref.watch(workspaceMembersProvider);
    final names = ref.watch(memberNamesProvider).value ?? const {};
    final profiles = ref.watch(memberProfilesProvider).value ?? const {};
    final reservations =
        ref.watch(directoryReservationsProvider).value ?? const <Reservation>[];
    final targets = ref.watch(targetNamesProvider).value ?? const {};
    final myMemberId = ref.watch(myMemberProvider).value?.id;
    // The owner-set group link (#231) shows the tile for ALL members.
    final groupUri = ref
        .watch(currentWorkspaceProvider)
        .value
        ?.whatsappGroupUri;

    // No own Scaffold since #230: the directory is a shell branch — the
    // shell's app bar already shows the localized Members title.
    return switch (membersAsync) {
      AsyncData(value: final members) => Builder(
        builder: (context) {
          final active =
              members.where((m) => m.status == MemberStatus.active).toList()
                ..sort(
                  (a, b) => (names[a.id] ?? '').toLowerCase().compareTo(
                    (names[b.id] ?? '').toLowerCase(),
                  ),
                );
          return RefreshIndicator(
            onRefresh: () => _refresh(ref),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (groupUri != null)
                  _GroupTile(onOpen: () => _openLink(context, ref, groupUri)),
                if (active.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: EmptyState(
                      icon: Icons.people_outline,
                      title: l10n?.directoryEmpty ?? 'No members yet.',
                    ),
                  )
                else
                  for (final member in active)
                    _MemberRow(
                      member: member,
                      name: names[member.id] ?? '',
                      isSelf: member.id == myMemberId,
                      profile: profiles[member.userId],
                      presence: resolveDirectoryPresence(
                        lastSeenAt: profiles[member.userId]?.lastSeenAt,
                        now: now,
                      ),
                      reservationInfo: resolveReservationInfo(
                        memberId: member.id,
                        reservations: reservations,
                        now: now,
                      ),
                      memberReservations: _upcomingFor(
                        member.id,
                        reservations,
                        now,
                      ),
                      targetNames: targets,
                      now: now,
                      onWhatsapp: (uri) => _openLink(context, ref, uri),
                      onOpenReservation: (reservation) =>
                          _openReservation(context, reservation),
                    ),
              ],
            ),
          );
        },
      ),
      AsyncError() => Center(
        child: Text(
          l10n?.workspaceGenericError ??
              'Something went wrong. Please try again.',
        ),
      ),
      _ => const LoadingView(),
    };
  }
}

/// This member's still-active bookings from [now] onward, soonest first
/// — what the detail sheet lists (#237's [directoryReservations] window,
/// i.e. up to two weeks out). A booking already running (checked in or
/// covering now) is included; cancelled/past ones are dropped.
List<Reservation> _upcomingFor(
  String memberId,
  List<Reservation> reservations,
  DateTime now,
) {
  final upcoming = reservations
      .where(
        (r) =>
            r.memberId == memberId && r.isActive && r.endsAt.isAfter(now),
      )
      .toList()
    ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  return upcoming;
}

/// Compact relative last-seen label for the offline chip.
String _relativeLastSeen(
  AppLocalizations? l10n,
  DateTime now,
  DateTime lastSeenAt,
) {
  final diff = now.difference(lastSeenAt);
  if (diff.inMinutes < 60) {
    final minutes = diff.inMinutes < 1 ? 1 : diff.inMinutes;
    return l10n?.directoryLastSeenMinutes(minutes) ?? '$minutes min';
  }
  if (diff.inHours < 24) {
    return l10n?.directoryLastSeenHours(diff.inHours) ?? '${diff.inHours} h';
  }
  return l10n?.directoryLastSeenDays(diff.inDays) ?? '${diff.inDays} d';
}

/// The presence chip for [presence] — unchanged rendering from #224 —
/// or null when the member was never seen (offline without a heartbeat
/// renders no presence chip at all). Shared by the row and the detail
/// sheet — [keyPrefix] keeps their [ValueKey]s distinct so tests can
/// target each surface.
Widget? _presenceChip(
  BuildContext context, {
  required AppLocalizations? l10n,
  required String memberId,
  required DirectoryPresence presence,
  required DateTime now,
  String keyPrefix = 'directory-status',
}) {
  final theme = Theme.of(context);
  return switch (presence.kind) {
    DirectoryPresenceKind.online => _StatusChip(
      chipKey: ValueKey('$keyPrefix-$memberId'),
      label: l10n?.directoryOnline ?? 'Online',
      foreground: AppStatusColors.successOf(theme.brightness),
      outlined: true,
    ),
    DirectoryPresenceKind.offline =>
      presence.lastSeenAt == null
          ? null
          : _StatusChip(
              chipKey: ValueKey('$keyPrefix-$memberId'),
              label: _relativeLastSeen(l10n, now, presence.lastSeenAt!),
              foreground: theme.colorScheme.onSurfaceVariant,
            ),
  };
}

/// Label of the upcoming-reservation chip (#237): localized weekday +
/// day and start time in the calendar's house style ([DateFormat.E] /
/// [DateFormat.d] / [DateFormat.Hm]) plus the seat name when the plan
/// knows one — "Tue 21 · 09:00 · A1".
String _upcomingLabel(Reservation reservation, String seatName) {
  final local = reservation.startsAt.toLocal();
  final day =
      '${DateFormat.E().format(local)} ${DateFormat.d().format(local)}';
  final when = '$day · ${DateFormat.Hm().format(local)}';
  return seatName.isEmpty ? when : '$when · $seatName';
}

/// The reservation chip for [info] (#237), or null without one. Styles
/// mirror the resolver priority: checked in keeps the filled success
/// style from #224, reserved-now is outlined primary, an upcoming
/// booking is outlined neutral so it visually ranks below both.
/// [keyPrefix] keeps row and sheet [ValueKey]s distinct.
Widget? _reservationChip(
  BuildContext context, {
  required AppLocalizations? l10n,
  required String memberId,
  required ReservationInfo? info,
  required Map<String, String> targetNames,
  String keyPrefix = 'directory-res',
}) {
  if (info == null) return null;
  final theme = Theme.of(context);
  final brightness = theme.brightness;
  final reservation = info.reservation;
  final seatName =
      targetNames[reservation.seatId ?? reservation.officeId] ?? '';
  return switch (info) {
    CheckedInNow() => _StatusChip(
      chipKey: ValueKey('$keyPrefix-$memberId'),
      label: seatName.isEmpty
          ? (l10n?.directoryCheckedIn ?? 'Checked in')
          : (l10n?.directoryCheckedInSeat(seatName) ??
                'Checked in · $seatName'),
      foreground: AppStatusColors.onSuccessOf(brightness),
      background: AppStatusColors.successOf(brightness),
    ),
    ReservedNow() => _StatusChip(
      chipKey: ValueKey('$keyPrefix-$memberId'),
      label: seatName.isEmpty
          ? (l10n?.directoryReservedNow ?? 'Reserved now')
          : (l10n?.directoryReservedNowSeat(seatName) ??
                'Reserved now · $seatName'),
      foreground: theme.colorScheme.primary,
      outlined: true,
    ),
    UpcomingReservation() => _StatusChip(
      chipKey: ValueKey('$keyPrefix-$memberId'),
      label: _upcomingLabel(reservation, seatName),
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
  required AppLocalizations? l10n,
  required Member member,
}) {
  final theme = Theme.of(context);
  if (member.isOwner) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xs),
      child: _StatusChip(
        chipKey: ValueKey('directory-role-${member.id}'),
        label: l10n?.memberRoleOwner ?? 'Owner',
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
        label: l10n?.memberRoleAdmin ?? 'Admin',
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
Future<void> _showMemberSheet(
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
}) {
  return showModalBottomSheet<void>(
    context: context,
    // Scrollable so a full sheet (role + chip + status + button) never
    // overflows small viewports.
    isScrollControlled: true,
    builder: (sheetContext) {
      final l10n = AppLocalizations.of(sheetContext);
      final theme = Theme.of(sheetContext);
      final role = member.isOwner
          ? (l10n?.memberRoleOwner ?? 'Owner')
          : member.isAdmin
          ? (l10n?.memberRoleAdmin ?? 'Admin')
          : (l10n?.memberRoleMember ?? 'Member');
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
                l10n?.directoryReservationsHeading ?? 'Reservations',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              if (memberReservations.isEmpty)
                Text(
                  l10n?.directoryNoUpcoming ?? 'No upcoming reservations',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                for (final reservation in memberReservations)
                  _ReservationTile(
                    reservation: reservation,
                    seatName: targetNames[reservation.seatId ??
                            reservation.officeId] ??
                        '',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      onOpenReservation(reservation);
                    },
                  ),
              const SizedBox(height: AppSpacing.lg),
              if (whatsappUri != null) ...[
                FilledButton.icon(
                  key: ValueKey('directory-sheet-wa-${member.id}'),
                  icon: const Icon(Icons.chat_outlined),
                  label: Text(l10n?.directoryWhatsapp ?? 'Chat on WhatsApp'),
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    onWhatsapp(whatsappUri);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: Text(l10n?.directoryClose ?? 'Close'),
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
    final l10n = AppLocalizations.of(context);
    return Card(
      key: const ValueKey('directory-group'),
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenGutter,
        vertical: AppSpacing.sm,
      ),
      child: ListTile(
        leading: const Icon(Icons.groups_outlined),
        title: Text(l10n?.directoryOpenGroup ?? 'Open WhatsApp group'),
        trailing: const Icon(Icons.open_in_new),
        onTap: onOpen,
      ),
    );
  }
}

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
    required this.isSelf,
    required this.profile,
    required this.presence,
    required this.reservationInfo,
    required this.memberReservations,
    required this.targetNames,
    required this.now,
    required this.onWhatsapp,
    required this.onOpenReservation,
  });

  final Member member;
  final String name;
  final bool isSelf;
  final Profile? profile;
  final DirectoryPresence presence;
  final ReservationInfo? reservationInfo;
  final List<Reservation> memberReservations;
  final Map<String, String> targetNames;
  final DateTime now;
  final void Function(Uri uri) onWhatsapp;
  final void Function(Reservation reservation) onOpenReservation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
      subtitle: chips.isEmpty && statusText.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
              tooltip: l10n?.directoryWhatsapp ?? 'Chat on WhatsApp',
              onPressed: () => onWhatsapp(whatsappUri),
            ),
      onTap: () => _showMemberSheet(
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
              l10n?.directoryWhatsapp ?? 'Chat on WhatsApp',
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
                _upcomingLabel(reservation, seatName),
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
