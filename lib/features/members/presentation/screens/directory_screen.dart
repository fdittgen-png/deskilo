// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/links/link_launcher.dart';
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
import '../../../reservations/domain/reservation.dart';
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
                      targetNames: targets,
                      now: now,
                      onWhatsapp: (uri) => _openLink(context, ref, uri),
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
  required Map<String, String> targetNames,
  required DateTime now,
  required void Function(Uri uri) onWhatsapp,
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
                  CircleAvatar(
                    child: Text(
                      name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
                    ),
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
    required this.targetNames,
    required this.now,
    required this.onWhatsapp,
  });

  final Member member;
  final String name;
  final bool isSelf;
  final Profile? profile;
  final DirectoryPresence presence;
  final ReservationInfo? reservationInfo;
  final Map<String, String> targetNames;
  final DateTime now;
  final void Function(Uri uri) onWhatsapp;

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

    final tile = ListTile(
      leading: CircleAvatar(
        child: Text(name.isEmpty ? '?' : name.substring(0, 1).toUpperCase()),
      ),
      title: Text(
        name,
        style: isSelf ? const TextStyle(fontWeight: FontWeight.bold) : null,
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
        targetNames: targetNames,
        now: now,
        onWhatsapp: onWhatsapp,
      ),
    );

    if (whatsappUri == null) return tile;

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
        color: AppStatusColors.successOf(brightness),
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
      child: tile,
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
