// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/links/link_launcher.dart';
import '../../../../core/presence/presence_rules.dart';
import '../../../../core/settings/directory_windows.dart';
import '../../../../core/text/collation.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/async_read_body.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../../reservations/domain/reservation.dart';
import '../../../reservations/presentation/widgets/reservation_detail_sheet.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../../workspace/domain/member.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/presentation/widgets/open_conversation.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../application/directory_card.dart';
import '../../domain/directory_status.dart';
import '../../providers/directory_providers.dart';
import '../member_profile_link.dart';
import '../widgets/directory_member_row.dart';


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
class DirectoryScreen extends ConsumerStatefulWidget {
  const DirectoryScreen({super.key});

  @override
  ConsumerState<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends ConsumerState<DirectoryScreen> {
  /// Presence decays: the profile snapshot is fetched once, so after
  /// [PresenceRules.onlineWindow] on an open screen EVERYONE drifted to
  /// "offline" while their heartbeats kept arriving. Re-read it on the
  /// heartbeat's own cadence — and let `now` advance with it, so the
  /// relative labels count up instead of freezing.
  Timer? _presenceTimer;

  /// #4069 — the search above the list: by name and e-mail.
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => _update(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The shell keeps every branch mounted behind the visible one
    // (IndexedStack): TickerMode is the framework's own "am I the child
    // on screen" signal, so a hidden directory polls nothing.
    _armPresence(visible: TickerMode.valuesOf(context).enabled);
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  /// [members] whose name or e-mail holds what is typed, case and accents
  /// aside; every one while nothing is typed.
  List<Member> _matching(
    List<Member> members,
    Map<String, String> names,
    Map<String, String> emails,
  ) {
    final query = foldForSearch(_search.text.trim());
    if (query.isEmpty) return members;
    return [
      for (final m in members)
        if (foldForSearch(names[m.id] ?? '').contains(query) ||
            foldForSearch(emails[m.id] ?? '').contains(query))
          m,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = ref.read(clockProvider).now();
    final membersAsync = ref.watch(workspaceMembersProvider);
    final names = ref.watch(memberNamesProvider).value ?? const {};
    // Emails are an ADMIN surface (#410): the provider (and the server)
    // hand plain members the empty map, so their directory is unchanged.
    final emails = ref.watch(memberEmailsProvider).value ?? const {};
    final rawProfiles =
        ref.watch(memberProfilesProvider).value ?? const {};
    final reservations =
        ref.watch(directoryReservationsProvider).value ?? const <Reservation>[];
    // #1154 — grouped ONCE per build, not rescanned per row.
    final reservationsByMember = reservationsByMemberOf(reservations);
    final windows = ref.watch(directoryWindowsProvider);
    final targets = ref.watch(targetNamesProvider).value ?? const {};
    final myMemberId = ref.watch(myMemberProvider).value?.id;
    // WhatsApp affordances (swipe, chat buttons, group tile) ride the
    // whatsappIntegration feature (hierarchy pass): off = every
    // affordance disappears at this single point.
    final whatsappOn = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.whatsappIntegration);
    // Member notes (#456) — the send affordance on rows and sheets.
    final pageOn = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.memberPage);
    final notesOn = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.memberNotifications);
    // The owner-set group link (#231) shows the tile for ALL members.
    final groupUri = whatsappOn
        ? ref.watch(currentWorkspaceProvider).value?.whatsappGroupUri
        : null;
    // Feature off → strip the numbers, so every whatsappUri-derived
    // affordance (row swipe, chat buttons, sheet) vanishes together.
    final profiles = whatsappOn
        ? rawProfiles
        : {
            for (final entry in rawProfiles.entries)
              entry.key: entry.value.copyWith(whatsapp: ''),
          };

    // No own Scaffold since #230: the directory is a shell branch — the
    // shell's app bar already shows the localized Members title.
    return switch (membersAsync) {
      AsyncData(value: final members) => Builder(
        builder: (context) {
          final everyone =
              members.where((m) => m.status == MemberStatus.active).toList()
                ..sort(
                  (a, b) => compareNames((names[a.id] ?? ''), (names[b.id] ?? '')),
                );
          final active = _matching(everyone, names, emails);
          return RefreshIndicator(
            onRefresh: () => _refresh(ref),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (groupUri != null)
                  DirectoryGroupTile(onOpen: () => _openLink(context, ref, groupUri)),
                ..._searchAndNoOne(
                  l10n,
                  anyone: everyone.isNotEmpty,
                  found: active.isNotEmpty,
                ),
                if (everyone.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: EmptyState(
                      icon: Icons.people_outline,
                      title: l10n.directoryEmpty,
                    ),
                  )
                else
                  for (final member in active)
                    DirectoryMemberRow(
                      card: DirectoryCard(
                        member: member,
                        name: names[member.id] ?? '',
                        email: emails[member.id] ?? '',
                        isSelf: member.id == myMemberId,
                        profile: profiles[member.userId],
                        presence: resolveDirectoryPresence(
                          lastSeenAt: profiles[member.userId]?.lastSeenAt,
                          now: now,
                          isSelf: member.id == myMemberId,
                          onlineWindow: windows.onlineWindow,
                        ),
                        reservationInfo: resolveReservationInfo(
                          memberId: member.id,
                          reservations: reservationsByMember[member.id] ??
                              const <Reservation>[],
                          now: now,
                          upcomingWindow: windows.upcomingWindow,
                        ),
                        memberReservations: upcomingReservationsFor(
                          member.id,
                          reservationsByMember[member.id] ??
                              const <Reservation>[],
                          now,
                        ),
                        targetNames: targets,
                        now: now,
                      ),
                      onWhatsapp: (uri) => _openLink(context, ref, uri),
                      onOpenReservation: (reservation) =>
                          _openReservation(context, reservation),
                      // #825 — the member page when its flag is on.
                      onOpenPage: pageOn
                          ? () => openMemberPage(context, member.id)
                          : null,
                      // Messaging refactor: the profile opens the same
                      // conversation thread as everywhere else — read
                      // AND send in one place.
                      onNotify: notesOn && member.id != myMemberId
                          ? () => openDirectConversation(
                                context,
                                ref,
                                memberId: member.id,
                              )
                          : null,
                    ),
              ],
            ),
          );
        },
      ),
      AsyncError(:final error) => ReadFailureBanner(
        error: error,
        onRetry: () => ref.invalidate(workspaceMembersProvider),
      ),
      _ => const LoadingView(),
    };
  }

  /// #4069 — the search above the list, while the space has anyone to
  /// find; and a search that finds no one says so, with the way to see
  /// everyone again.
  List<Widget> _searchAndNoOne(
    AppLocalizations l10n, {
    required bool anyone,
    required bool found,
  }) => [
    if (anyone)
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenGutter,
          AppSpacing.sm,
          AppSpacing.screenGutter,
          AppSpacing.xs,
        ),
        child: AppTextField(
          key: const ValueKey('directory-search'),
          controller: _search,
          label: l10n.directorySearchLabel,
          textInputAction: TextInputAction.search,
        ),
      ),
    if (anyone && !found) ...[
      EmptyState(
        key: const ValueKey('directory-search-none'),
        icon: Icons.search_off,
        title: l10n.directorySearchNone(_search.text.trim()),
      ),
      Center(
        child: TextButton(
          key: const ValueKey('directory-search-clear'),
          onPressed: _search.clear,
          child: Text(l10n.discoveryClearSearch),
        ),
      ),
    ],
  ];

  /// Lets the section extensions rebuild (setState is protected).
  void _update(VoidCallback fn) => setState(fn);

  void _armPresence({required bool visible}) {
    if (visible == (_presenceTimer != null)) return;
    _presenceTimer?.cancel();
    _presenceTimer = visible
        ? Timer.periodic(PresenceRules.heartbeatInterval, (_) {
            if (!mounted) return;
            ref.invalidate(memberProfilesProvider);
            _update(() {});
          })
        : null;
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref
      ..invalidate(workspaceMembersProvider)
      ..invalidate(memberNamesProvider)
      ..invalidate(memberEmailsProvider)
      ..invalidate(memberProfilesProvider)
      ..invalidate(reservationsForMonthProvider)
      ..invalidate(directoryReservationsProvider)
      ..invalidate(targetNamesProvider);
    await ref.read(workspaceMembersProvider.future);
  }

  /// Opens a member's booking through the shared helper, which owns the
  /// "Show on plan" jump (#422 — opening the sheet directly discarded
  /// the popped target and the button silently did nothing here).
  void _openReservation(BuildContext context, Reservation reservation) {
    unawaited(showReservationDetail(context, ref, reservation));
  }

  Future<void> _openLink(BuildContext context, WidgetRef ref, Uri uri) async {
    final l10n = context.l10n;
    try {
      final handled = await ref.read(linkLauncherProvider)(uri);
      if (!handled) throw StateError('no handler for $uri');
    } on Object catch (e, st) {
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
        l10n.workspaceGenericError,
      );
    }
  }
}
