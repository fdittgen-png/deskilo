// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The Reserve hub's header (#2494): the closed-day banner, the view controls,
// the date and window controls, the legend and the one help slot. Two rows
// (#699): ROW 1 is what you are looking at, ROW 2 is WHEN you are looking at
// it, plus how the plan draws.









import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/backend/backend_settings.dart';
import '../../../../core/help/help_blocker.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/workspace_time.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../plan/domain/half_day_windows.dart';
import '../../../plan/providers/default_level_controller.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../../workspace/domain/booking_policies.dart';
import '../../../workspace/domain/member.dart';
import '../../../workspace/domain/next_open_day.dart';
import '../../../workspace/domain/workspace.dart';
import '../../../workspace/domain/workspace_availability.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../application/getting_started_hint.dart';
import '../../domain/reservation.dart';
import '../../providers/browsed_level.dart';
import '../../providers/reservation_providers.dart';
import '../getting_started_facts.dart';
import '../widgets/booking_controls.dart';
import '../widgets/booking_window_summary.dart';
import '../widgets/getting_started_card.dart';
import '../widgets/pending_booking_banner.dart';
import '../widgets/reserve_view_menu.dart';
import '../widgets/seat_legend.dart';
import '../widgets/stale_availability_banner.dart';
import 'reserve_hub_host.dart';
import 'reserve_hub_recorder.dart';



/// Whether the workspace is open on a day, and whether that is known yet
/// (#186, #1301 S4): unknown while loading is neither open nor closed.
typedef ReserveDayAvailability = ({bool known, bool open});

/// Watched (not the read-based `isWorkspaceOpenAt`) so the hub reacts to
/// availability edits.
ReserveDayAvailability reserveDayAvailability(WidgetRef ref, DateTime day) {
  final openWeekdays = ref.watch(openWeekdaysProvider).value;
  final closures = ref.watch(closureDaysProvider).value;
  final known = openWeekdays != null && closures != null;
  return (
    known: known,
    open: known && isWorkspaceOpenOn(day, openWeekdays, closures),
  );
}

/// What the header's controls call back to: the pickers need a context and
/// the screen's State, so the screen hands them in.
class ReserveHeaderActions {
  const ReserveHeaderActions({
    required this.pickDate,
    required this.pickFrom,
    required this.pickTo,
    required this.pickWindow,
  });

  final VoidCallback pickDate;
  final VoidCallback pickFrom;
  final VoidCallback pickTo;
  final void Function(HalfDayWindow window) pickWindow;
}

class ReserveHubHeader extends ConsumerWidget {
  const ReserveHubHeader({
    super.key,
    required this.host,
    required this.window,
    required this.actions,
    required this.backToNow,
  });

  final ReserveHubHost host;
  final HalfDayWindow window;
  final ReserveHeaderActions actions;

  /// 'Back to now' (#2016) while browsing, else null.
  final Widget? backToNow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final availability = reserveDayAvailability(ref, host.selectedDay);
    final features = ref.watch(enabledFeaturesSyncProvider);
    // #814 — the legend under the controls, and closed days drawn as closed
    // in every view (not only the plan).
    final gateOn = features.contains(WorkspaceFeature.bookingGate);
    // Keep the policies warm: the gate reads them synchronously at tap time
    // (a cold provider would judge with the defaults).
    if (gateOn) ref.watch(bookingPoliciesProvider);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final guidanceKey = features.contains(WorkspaceFeature.memberGettingStarted)
        ? gettingStartedSeenKey(
            installation: ref.watch(activeBackendProvider).value?.url ?? '',
            accountId: ref.watch(currentAccountIdProvider) ?? '',
            workspaceId: workspace?.id ?? '')
        : null;
    final facts = _gettingStartedFacts(ref, availability);
    final timeViews = host.view != ReserveView.week &&
        host.view != ReserveView.month;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const PendingBookingBanner(), // #1855 — nothing unless an answer is owed
        MotionReveal(child: _closedDayBanner(ref, l10n, availability)),
        const MotionReveal(child: StaleAvailabilityBanner()), // #1305 S3
        HeaderControlRow(children: _viewControls(ref, l10n, guidanceKey)),
        HeaderControlRow(children: _whenControls(ref, timeViews)),
        if (timeViews)
          BookingWindowSummary(
              window: window,
              today: host.today,
              timezone: workspace?.timezone),
        if (gateOn)
          SeatLegend(
            showClosed: host.view == ReserveView.week ||
                host.view == ReserveView.month ||
                host.view == ReserveView.day,
          ),
        // #1853 A — ONE help slot: the Get started next step (#1654), or
        // else the hub's tip carousel (#606); each gated inside.
        MotionReveal(
          child: ReserveHelpHost(
            facts: facts,
            seenKey: guidanceKey,
            onChooseTime: actions.pickDate,
            workspaceId: workspace?.id, // #1636
          ),
        ),
      ],
    );
  }

  Widget _closedDayBanner(
    WidgetRef ref,
    AppLocalizations l10n,
    ReserveDayAvailability availability,
  ) {
    if (availability.open) {
      return const SizedBox.shrink(key: ValueKey('reserve-open-day'));
    }
    // #1301 S4 — loading reads as loading, not as closed.
    if (!availability.known) {
      return const LinearProgressIndicator(
          key: ValueKey('reserve-availability-loading'), minHeight: 2);
    }
    return HelpBlocker(
      id: 'reserve.closed-day',
      child: _ClosedDayBanner(host: host),
    );
  }

  /// ROW 1 — what you are looking at.
  List<Widget> _viewControls(
    WidgetRef ref,
    AppLocalizations l10n,
    String? guidanceKey,
  ) {
    final seatList = host.view == ReserveView.list;
    return <Widget>[
      // #1301 S2 — the time views behind one named control.
      ReserveViewMenu(
        key: const ValueKey('reserve-reserve-view-menu'),
        view: host.view,
        onChanged: (view) {
          host.showView(view);
          ReserveHubRecorder(ref).switchedView(view.name); // #1881
        },
        onGetStarted: gettingStartedReopen(ref, guidanceKey),
      ),
      // Map <-> list, as ONE button showing the icon of what you would switch
      // TO.
      //
      // It was a fifth segment in the toggle above until the tap-target
      // guard caught it: five icon segments squeeze to 45.6dp at phone
      // width, under the 48dp floor. And it never belonged there anyway —
      // Day/Week/Month are TIME views, while map and list are two
      // presentations of the same one. A second two-segment toggle would
      // have shown two map icons in one row; this shows one, and never the
      // one you are already looking at.
      if (host.view == ReserveView.plan || host.view == ReserveView.list)
        IconButton(
          key: const ValueKey('reserve-seat-view-switch'),
          tooltip: seatList ? l10n.planMapViewTooltip : l10n.planListViewTooltip,
          icon: Icon(seatList ? Icons.map_outlined : Icons.view_list_outlined),
          onPressed: () {
            host.showView(seatList ? ReserveView.plan : ReserveView.list);
            ReserveHubRecorder(ref)
                .switchedView(seatList ? 'list' : 'plan'); // #1865
          },
        ),
      ?backToNow,
    ];
  }

  /// ROW 2 — WHEN you are looking at it, plus how the plan draws.
  List<Widget> _whenControls(WidgetRef ref, bool timeViews) {
    return <Widget>[
      TextButton(
        key: const ValueKey('reserve-date-button'),
        // #699 — the default TextButton carries 16dp of padding a side for a
        // two-word label. Trimmed to 8, with the 48dp minimum kept
        // explicitly so the target never follows the padding down.
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          minimumSize: const Size(0, kMinInteractiveDimension),
        ),
        onPressed: actions.pickDate,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.calendar_month_outlined, size: 18),
          const SizedBox(width: 4),
          // #711 — intl's default locale IS the member's format locale now
          // (set by appFormatProvider), so the bare call is the right one; a
          // per-site locale would disagree with every other date on screen.
          Text(DateFormat.MMMd().format(host.selectedDay)),
        ]),
      ),
      // Honest controls: the window chips act on Plan (state filter +
      // booking window) and Day (the window a free-row tap books). Week
      // books per tapped half, Month is an overview — no chips.
      if (timeViews)
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xs),
          child: WindowControls(
            key: const ValueKey('reserve-window-controls'),
            keyPrefix: 'reserve',
            granularity: host.granularity,
            day: host.selectedDay,
            isSelected: (w) => window.start == w.start && window.end == w.end,
            onPickWindow: (w) {
              actions.pickWindow(w);
              ReserveHubRecorder(ref).selectedPeriod(w.start, w.end); // #1865
            },
            from: window.start,
            to: window.end,
            onPickFrom: actions.pickFrom,
            onPickTo: actions.pickTo,
          ),
        ),
    ];
  }

  /// The facts the Get started card judges (#1654).
  GettingStartedFacts _gettingStartedFacts(
    WidgetRef ref,
    ReserveDayAvailability availability,
  ) {
    final features = ref.watch(enabledFeaturesSyncProvider);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final member = ref.watch(myMemberProvider);
    final me = member.value;
    final policies = ref.watch(bookingPoliciesProvider);
    return GettingStartedFacts(
      workspaceName: workspace?.name ?? '',
      production: workspace != null && !workspace.isDevelopment,
      membership: factOf(member).map(_standing),
      dayOpen: availability.known
          ? Fact.ready(availability.open)
          : ref.watch(openWeekdaysProvider).hasError ||
                  ref.watch(closureDaysProvider).hasError
              ? const Fact.offline()
              : const Fact.loading(),
      bookableSpaces: _bookableSpaces(ref),
      allowance: me != null && features.contains(WorkspaceFeature.bookingPolicies)
          ? factOf(policies).map((p) =>
              BookingPolicies.allowanceFor(me.maxSimultaneousReservations, p))
          : const Fact.loading(),
      ownBooking: me == null
          ? const Fact.loading()
          : _ownBooking(ref, me),
    );
  }

  static MembershipStanding _standing(Member? m) => m == null
      ? MembershipStanding.inactive
      : switch (m.status) {
          MemberStatus.pending => MembershipStanding.pending,
          MemberStatus.active => m.isOwner
              ? MembershipStanding.owner
              : m.isAdmin
                  ? MembershipStanding.administrator
                  : MembershipStanding.member,
          _ => MembershipStanding.inactive,
        };

  /// How many spaces the browsed floor offers to book.
  Fact<int> _bookableSpaces(WidgetRef ref) {
    final levels = ref.watch(levelsProvider);
    final browsed = ref.watch(browsedLevelProvider);
    final wanted = browsed == BrowsedLevel.allLevels ? null : browsed;
    final level = levels.value
            ?.where((l) =>
                l.id == (wanted ?? ref.watch(selectedLevelIdProvider).value))
            .firstOrNull ??
        levels.value?.firstOrNull;
    if (level == null) return factOf(levels).map((list) => list.length);
    return factOf(ref.watch(floorPlanProvider(level.id))).map((p) =>
        p.seats.length +
        p.offices.where((o) => o.bookableAsWhole).length +
        p.desks.where((d) => d.bookableAsWhole).length +
        (level.bookableAsWhole ? 1 : 0) +
        levels.value!.length -
        1);
  }

  Fact<BookingEvidence?> _ownBooking(WidgetRef ref, Member me) {
    final targetNames =
        ref.watch(targetNamesProvider).value ?? const <String, String>{};
    return factOf(ref
            .watch(reservationsForDayProvider(dayKeyOf(host.selectedDay))))
        .map((list) {
      final mine = list
          .where((r) =>
              r.memberId == me.id &&
              r.status != ReservationStatus.cancelled &&
              r.status != ReservationStatus.released)
          .toList()
        ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
      return mine.isEmpty
          ? null
          : BookingEvidence(
              id: mine.first.id,
              state: mine.first.status.name,
              spaceName: mine.first.spaceNameFrom(targetNames));
    });
  }
}

/// Closed-day banner (#186 style): the workspace is not open on the selected
/// day, so nothing below is bookable. Shared [InlineBanner] since #210.
class _ClosedDayBanner extends ConsumerWidget {
  const _ClosedDayBanner({required this.host});

  final ReserveHubHost host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // #1196 — the banner used to state the fact and stop there, so a member
    // who opened the hub on a Sunday got a blocked plan, inert chips and no
    // way forward but the date picker, two taps away and not obviously the
    // answer. The next open day is something this screen already knows.
    final next = nextOpenDay(
      // Tomorrow: today is the day being called closed.
      host.selectedDay.add(const Duration(days: 1)),
      openWeekdays: ref.watch(openWeekdaysProvider).value ?? const [],
      closures: ref.watch(closureDaysProvider).value ?? const [],
    );
    final label = next == null
        ? null
        : appFormatOf(context).shortDate(
            WorkspaceTime.at(next.year, next.month, next.day, 12),
          );
    return InlineBanner(
      key: const ValueKey('reserve-closed-banner'),
      icon: Icons.event_busy,
      text: l10n.planClosedDay,
      // A workspace closed for longer than the horizon, or with no open
      // weekday at all, has nothing to point at. Then the banner says only
      // what it always said, which is the honest answer.
      actionLabel: label == null ? null : l10n.planClosedDayShowNext(label),
      onAction: next == null ? null : () => host.selectDay(next),
    );
  }
}
