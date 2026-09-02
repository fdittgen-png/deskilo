// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/time/clock.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/app_snack.dart';
import '../../../l10n/app_localizations.dart';
import '../../reservations/presentation/widgets/reservation_detail_sheet.dart';
import '../../workspace/domain/member.dart';
import '../../workspace/domain/workspace_feature.dart';
import 'screens/member_page.dart';
import '../../../core/links/link_launcher.dart';
import '../../plan/providers/floor_plan_providers.dart';
import '../../reservations/domain/reservation.dart';
import '../../reservations/providers/reservation_providers.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/directory_status.dart';
import '../providers/directory_providers.dart';
import 'screens/directory_screen.dart';

/// Opens a member's profile from ANYWHERE, resolving what the sheet
/// needs from providers (#695).
///
/// The messaging centre has a member id and nothing else; the directory
/// has already loaded profiles, presence and reservations by the time it
/// draws a row. This bridges the two so both show the same thing —
/// reservations, the live check-in, status, and the contact details the
/// viewer is allowed to see.
Future<void> openMemberProfile(
  BuildContext context,
  WidgetRef ref, {
  required String memberId,
}) async {
  final members = ref.read(workspaceMembersProvider).value ?? const <Member>[];
  final member = members.where((m) => m.id == memberId).firstOrNull;
  if (member == null) return;
  // #825 — one page per person when its flag is on.
  if (ref
      .read(enabledFeaturesSyncProvider)
      .contains(WorkspaceFeature.memberPage)) {
    await openMemberPage(context, memberId);
    return;
  }
  final names = ref.read(memberNamesProvider).value ?? const {};
  final profiles = ref.read(memberProfilesProvider).value ?? const {};
  final reservations =
      ref.read(directoryReservationsProvider).value ?? const <Reservation>[];
  final now = ref.read(clockProvider).now();
  if (!context.mounted) return;
  await showMemberProfileSheet(
    context,
    member: member,
    name: names[memberId] ?? '',
    isSelf: ref.read(myMemberProvider).value?.id == memberId,
    profile: profiles[member.userId],
    presence: resolveDirectoryPresence(
      lastSeenAt: profiles[member.userId]?.lastSeenAt,
      now: now,
      isSelf: ref.read(myMemberProvider).value?.id == memberId,
    ),
    reservationInfo: resolveReservationInfo(
      memberId: memberId,
      reservations: reservations,
      now: now,
    ),
    // The member's own bookings, upcoming first — the same slice the
    // directory row shows, computed here because the screen's private
    // filter is not reachable and is two lines anyway.
    memberReservations: [
      for (final r in reservations)
        if (r.memberId == memberId && r.endsAt.isAfter(now)) r,
    ]..sort((a, b) => a.startsAt.compareTo(b.startsAt)),
    targetNames: ref.read(targetNamesProvider).value ?? const {},
    now: now,
    onWhatsapp: (uri) => _launchLink(context, ref, uri),
    // Through the shared helper (#422): opening the sheet directly here
    // discards the popped target, and "Show on plan" then silently does
    // nothing.
    onOpenReservation: (r) => showReservationDetail(context, ref, r),
  );
}

/// #825 — pushes the member page: the route when a router hosts the
/// caller (deep-linkable), a plain page push otherwise.
Future<void> openMemberPage(BuildContext context, String memberId) async {
  if (GoRouter.maybeOf(context) != null) {
    await context.push('/member/$memberId');
  } else {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => MemberPage(memberId: memberId),
    ));
  }
}

/// Opens [uri], reporting a failure rather than dying quietly.
///
/// A top-level twin of the directory state's own `_openLink`, because
/// [openMemberProfile] is reachable from features that have no
/// directory screen behind them.
Future<void> _launchLink(
  BuildContext context,
  WidgetRef ref,
  Uri uri,
) async {
  final l10n = AppLocalizations.of(context);
  try {
    final handled = await ref.read(linkLauncherProvider)(uri);
    if (!handled) throw StateError('no handler for $uri');
  } catch (e, st) {
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
