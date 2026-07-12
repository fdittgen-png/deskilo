// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../../../reservations/providers/reservation_providers.dart';
import '../../../workspace/domain/member.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/directory_status.dart';
import '../../providers/directory_providers.dart';

/// Member directory (#224, epic #222): every member sees the workspace's
/// ACTIVE members (alphabetical) with a live status chip — checked in
/// (with seat name) > online > reserved today > offline (relative
/// last-seen; no chip when never seen) — and a WhatsApp button for
/// members who opted into sharing their number (#223).
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
      ..invalidate(reservationsForDayProvider)
      ..invalidate(targetNamesProvider);
    await ref.read(workspaceMembersProvider.future);
  }

  Future<void> _openWhatsapp(
    BuildContext context,
    WidgetRef ref,
    Uri uri,
  ) async {
    final l10n = AppLocalizations.of(context);
    try {
      final handled = await ref.read(linkLauncherProvider)(uri);
      if (!handled) throw StateError('no handler for $uri');
    } catch (e, st) {
      debugPrint('whatsapp launch failed: $e\n$st');
      TraceLogger.instance.error('members', 'whatsapp launch failed',
          error: e, stackTrace: st);
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
    final today =
        ref.watch(reservationsForDayProvider(dayKeyOf(now))).value ??
            const [];
    final targets = ref.watch(targetNamesProvider).value ?? const {};
    final myMemberId = ref.watch(myMemberProvider).value?.id;

    // No own Scaffold since #230: the directory is a shell branch — the
    // shell's app bar already shows the localized Members title.
    return switch (membersAsync) {
      AsyncData(value: final members) => Builder(builder: (context) {
          final active = members
              .where((m) => m.status == MemberStatus.active)
              .toList()
            ..sort((a, b) => (names[a.id] ?? '')
                .toLowerCase()
                .compareTo((names[b.id] ?? '').toLowerCase()));
          if (active.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => _refresh(ref),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: EmptyState(
                      icon: Icons.people_outline,
                      title: l10n?.directoryEmpty ?? 'No members yet.',
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => _refresh(ref),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                for (final member in active)
                  _MemberRow(
                    member: member,
                    name: names[member.id] ?? '',
                    isSelf: member.id == myMemberId,
                    profile: profiles[member.userId],
                    status: resolveDirectoryStatus(
                      memberId: member.id,
                      profile: profiles[member.userId],
                      todayReservations: today,
                      targetNames: targets,
                      now: now,
                    ),
                    now: now,
                    onWhatsapp: (uri) =>
                        _openWhatsapp(context, ref, uri),
                  ),
              ],
            ),
          );
        }),
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

/// One directory row: avatar initial, name (bold when it is me), status
/// chip, trailing WhatsApp button when the member shared a number.
class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.name,
    required this.isSelf,
    required this.profile,
    required this.status,
    required this.now,
    required this.onWhatsapp,
  });

  final Member member;
  final String name;
  final bool isSelf;
  final Profile? profile;
  final DirectoryStatus status;
  final DateTime now;
  final void Function(Uri uri) onWhatsapp;

  String _relativeLastSeen(AppLocalizations? l10n, DateTime lastSeenAt) {
    final diff = now.difference(lastSeenAt);
    if (diff.inMinutes < 60) {
      final minutes = diff.inMinutes < 1 ? 1 : diff.inMinutes;
      return l10n?.directoryLastSeenMinutes(minutes) ?? '$minutes min';
    }
    if (diff.inHours < 24) {
      return l10n?.directoryLastSeenHours(diff.inHours) ??
          '${diff.inHours} h';
    }
    return l10n?.directoryLastSeenDays(diff.inDays) ?? '${diff.inDays} d';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final success = AppStatusColors.successOf(brightness);

    final chip = switch (status.kind) {
      DirectoryStatusKind.checkedIn => _StatusChip(
          memberId: member.id,
          label: status.seatName.isEmpty
              ? (l10n?.directoryCheckedIn ?? 'Checked in')
              : (l10n?.directoryCheckedInSeat(status.seatName) ??
                  'Checked in · ${status.seatName}'),
          foreground: AppStatusColors.onSuccessOf(brightness),
          background: success,
        ),
      DirectoryStatusKind.online => _StatusChip(
          memberId: member.id,
          label: l10n?.directoryOnline ?? 'Online',
          foreground: success,
          outlined: true,
        ),
      DirectoryStatusKind.reservedToday => _StatusChip(
          memberId: member.id,
          label: l10n?.directoryReservedToday ?? 'Reserved today',
          foreground: theme.colorScheme.primary,
          outlined: true,
        ),
      DirectoryStatusKind.offline => status.lastSeenAt == null
          ? null
          : _StatusChip(
              memberId: member.id,
              label: _relativeLastSeen(l10n, status.lastSeenAt!),
              foreground: theme.colorScheme.onSurfaceVariant,
            ),
    };

    final whatsappUri = profile?.whatsappUri;

    return ListTile(
      leading: CircleAvatar(
        child: Text(
          name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
        ),
      ),
      title: Text(
        name,
        style: isSelf ? const TextStyle(fontWeight: FontWeight.bold) : null,
      ),
      subtitle: chip == null
          ? null
          : Wrap(children: [
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: chip,
              ),
            ]),
      trailing: whatsappUri == null
          ? null
          : IconButton(
              key: ValueKey('directory-wa-${member.id}'),
              icon: const Icon(Icons.chat_outlined),
              tooltip: l10n?.directoryWhatsapp ?? 'Chat on WhatsApp',
              onPressed: () => onWhatsapp(whatsappUri),
            ),
    );
  }
}

/// Small pill chip: filled ([background] set), outlined, or bare muted
/// text — state is never conveyed by color alone (spec §11), the label
/// always spells it out.
class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.memberId,
    required this.label,
    required this.foreground,
    this.background,
    this.outlined = false,
  });

  final String memberId;
  final String label;
  final Color foreground;
  final Color? background;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('directory-status-$memberId'),
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
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: foreground),
      ),
    );
  }
}
