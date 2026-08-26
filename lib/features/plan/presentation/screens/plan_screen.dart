// SPDX-License-Identifier: 0BSD
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/help/help_hint.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/seat_state_colors.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../core/ui/motion.dart';
import '../../../../core/ui/view_toggle.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/providers/event_providers.dart';
import '../../../reservations/domain/default_booking_period.dart';
import '../../../reservations/domain/walk_up_window.dart';
import '../../../reservations/domain/reservation.dart';
import '../../../reservations/providers/default_period_controller.dart';
import '../../../reservations/domain/reservation_repository.dart';
import '../../../members/providers/directory_providers.dart';
import '../../../reservations/domain/seat_state_logic.dart';
import '../../../reservations/domain/space_code.dart';
import '../../../reservations/presentation/widgets/booking_controls.dart';
import '../../../reservations/presentation/widgets/message_reserver.dart';
import '../../../reservations/presentation/widgets/space_scan.dart';
import '../../../reservations/presentation/widgets/booking_sheet.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../../../core/time/workspace_time.dart';
import '../../../workspace/domain/booking_granularity.dart';
import '../../../profile/domain/profile.dart';
import '../../../workspace/domain/member.dart';
import '../../../reservations/domain/booking_error_text.dart';
import '../../../reservations/presentation/booking_feedback.dart';
import '../../../workspace/domain/workspace_availability.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/floor_plan.dart';
import '../../domain/half_day_windows.dart';
import '../../domain/level.dart';
import '../../domain/seat.dart';
import '../../domain/seat_block_policy.dart';
import '../../providers/default_level_controller.dart';
import '../../providers/floor_plan_providers.dart';
import '../../providers/plan_focus_controller.dart';
import '../seat_occupancy.dart';
import '../widgets/seat_photos.dart';
import '../widgets/admin_seat_actions.dart';
import '../widgets/check_in_sheets.dart';
import '../widgets/plan_canvas.dart';

/// Default walk-up duration when nothing caps it earlier (spec §4.2;
/// becomes a workspace setting with the Epic-#5 rules engine).
const Duration _kDefaultStay = Duration(hours: 4);

/// Snapping of the header's from/to time chips (#184): 15-minute steps,
/// matching the old slider's granularity.
const int _kSnapMinutes = 15;

/// Latest selectable browse-window end within a day (#184): 23:45 — the
/// last 15-minute slot, so the default window never rolls past midnight.
const int _kLastSlotHour = 23;
const int _kLastSlotMinute = 45;

/// Live floor plan: seat states now, walk-up check-in, check-out (spec §4).
class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  Timer? _minuteTick;

  /// Browse-window state (spec §6, #184): null = live "now" mode;
  /// otherwise the start of the browsed time frame whose occupancy is
  /// rendered. [_browseEnd] is null exactly when [_browse] is null;
  /// otherwise it is always after [_browse] (invariant kept by every
  /// setter in this file).
  DateTime? _browse;

  /// End of the browsed window; see [_browse].
  DateTime? _browseEnd;
  bool _listView = false;

  /// Seat ringed on the canvas after a calendar "Show on plan" jump
  /// (#182). Cleared again by the next interaction that changes what the
  /// canvas shows: a seat tap, a level-chip tap, or any time-scroller
  /// change (from/to chip pick, date pick, Now).
  String? _highlightedSeatId;
  // #576 — the space the last "Show on plan" targeted: table, office or
  // the whole floor. Cleared with the seat highlight.
  String? _highlightedDeskId;
  String? _highlightedOfficeId;
  bool _highlightLevel = false;

  @override
  void initState() {
    super.initState();
    // Re-evaluate seat states as time passes.
    _minuteTick = Timer.periodic(
      const Duration(minutes: 1),
      (_) => setState(() {}),
    );
    // #182: a focus request may already be pending when this screen is
    // first built (the ref.listen in build only catches later changes).
    // Post-frame so applying it never mutates providers during build.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final pending = ref.read(planFocusControllerProvider);
      if (pending == null) return;
      // Reserve-first boot: on a freshly built Plan branch the level
      // controller's initial load may still be in flight — applied too
      // early, its completion would clobber the transient level with
      // the stored default. Let it settle first.
      try {
        await ref.read(selectedLevelIdProvider.future);
      } catch (e, st) {
        // trace-exempt: level loading failures surface via the plan's own
        // error state; the jump still runs on whatever level shows.
        debugPrint('level preload before focus failed: $e\n$st');
      }
      if (!mounted) return;
      _applyFocus(pending);
    });
  }

  /// Drops every show-on-plan highlight (#182/#576) — seat ring and
  /// space rings together, on any interaction that moves the view.
  void _clearHighlights() {
    _highlightedSeatId = null;
    _highlightedDeskId = null;
    _highlightedOfficeId = null;
    _highlightLevel = false;
  }

  /// Consumes a calendar "Show on plan" request (#182): switch the level
  /// transiently (never persisting the member's default), browse to the
  /// reservation start when it is still ahead (otherwise stay live), leave
  /// list view, ring the seat — then clear the one-shot signal.
  void _applyFocus(PlanFocus focus) {
    ref.read(selectedLevelIdProvider.notifier).showTransient(focus.levelId);
    final at = focus.at;
    final from =
        // #490 — keep the INSTANT; .toLocal() on a TZDateTime lands in
        // package:timezone's default-UTC tz.local (#417).
        (at != null && at.isAfter(ref.read(clockProvider).now()))
            ? at
            : null;
    setState(() {
      _listView = false;
      _highlightedSeatId = focus.seatId;
      _highlightedDeskId = focus.deskId;
      _highlightedOfficeId = focus.officeId;
      _highlightLevel = focus.wholeLevel;
      _browse = from;
      // Provisional default window (#184); refined to the reservation's own
      // end once the day's reservations are in.
      _browseEnd = from == null ? null : _defaultEndFor(from);
    });
    if (from != null) unawaited(_resolveFocusWindowEnd(focus, from));
    // Clear after the frame: mutating the provider inside its own change
    // notification would re-enter the listeners.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(planFocusControllerProvider.notifier).clear();
    });
  }

  /// #184: widen/narrow the focus window to the jumped-to reservation's own
  /// `[startsAt, endsAt)` once the browsed day's reservations resolve. The
  /// end is clamped to the day's last slot when the reservation crosses
  /// midnight. Whole-office jumps (no seatId) keep the default window.
  Future<void> _resolveFocusWindowEnd(PlanFocus focus, DateTime from) async {
    final seatId = focus.seatId;
    if (seatId == null) return;
    List<Reservation> reservations;
    try {
      reservations =
          await ref.read(reservationsForDayProvider(dayKeyOf(from)).future);
    } catch (e, st) {
      debugPrint('focus window resolution failed: $e\n$st');
      TraceLogger.instance.error('plan', 'focus window resolution failed',
          error: e, stackTrace: st);
      return;
    }
    // The user may have moved on while the day was loading.
    if (!mounted || _browse != from) return;
    final covering = reservations
        .where((r) => r.seatId == seatId && r.coversInstant(from))
        .firstOrNull;
    if (covering == null) return;
    var end = covering.endsAt;
    final last = _lastSlotOf(from);
    if (end.isAfter(last)) end = last;
    if (!end.isAfter(from)) return;
    setState(() => _browseEnd = end);
  }

  /// The day's last selectable slot (#184): 23:45 of [day] — in the
  /// WORKSPACE's clock (#490), so a device in another timezone browses
  /// the same day everyone else sees.
  DateTime _lastSlotOf(DateTime day) {
    final local = WorkspaceTime.wall(day);
    return WorkspaceTime.at(
      local.year,
      local.month,
      local.day,
      _kLastSlotHour,
      _kLastSlotMinute,
    );
  }

  /// Default window end for a start at [from] (#184): the default stay,
  /// clamped to the day's last slot — and never at/before [from] (a start
  /// on the last slot spills 15 minutes into the next day as the only
  /// remaining valid window).
  DateTime _defaultEndFor(DateTime from) {
    var end = from.add(_kDefaultStay);
    final last = _lastSlotOf(from);
    if (end.isAfter(last)) end = last;
    if (!end.isAfter(from)) end = from.add(_timeSnap);
    return end;
  }

  /// One configured slot (0032) — legacy flexible keeps the 15-minute
  /// snap of #184.
  int get _snapMinutes => _granularity.stepMinutes ?? _kSnapMinutes;

  Duration get _timeSnap => Duration(minutes: _snapMinutes);

  /// Snaps [t] down to the previous slot of the configured step (#184),
  /// on the WORKSPACE clock (#490).
  DateTime _snapToSlot(DateTime t) {
    final local = WorkspaceTime.wall(t);
    final m = (local.hour * 60 + local.minute) ~/ _snapMinutes * _snapMinutes;
    return WorkspaceTime.at(
        local.year, local.month, local.day, m ~/ 60, m % 60);
  }

  @override
  void dispose() {
    _minuteTick?.cancel();
    super.dispose();
  }

  /// Booking granularity of the active workspace (#200/#201). Loading or
  /// unknown reads as [BookingGranularity.flexible] so nothing flashes —
  /// the header only switches to the half-day chips once the rule is in.
  BookingGranularity get _granularity =>
      ref.read(bookingGranularityProvider).value ??
      BookingGranularity.flexible;

  /// Whether the workspace is open on the local day of [at] (#186): open
  /// weekday and no closure day. Unknown (providers still loading or
  /// errored) counts as open — the server guard stays the authority, the
  /// error mapping below explains its refusals.
  bool _isWorkspaceOpenAt(DateTime at) {
    final openWeekdays = ref.read(openWeekdaysProvider).value;
    final closures = ref.read(closureDaysProvider).value;
    if (openWeekdays == null || closures == null) return true;
    return isWorkspaceOpenOn(WorkspaceTime.dateOf(at), openWeekdays, closures);
  }

  /// Forward to the shared mapper with this screen's slot size
  /// (maintainability audit: the 42-line switch was pasted per screen).
  String _errorText(AppLocalizations? l10n, Object error, String fallback) =>
      bookingErrorText(l10n, error, fallback,
          stepMinutes: _granularity.stepMinutes);


  Future<void> _onSeatTap(
    FloorPlan plan,
    Seat seat,
    List<Reservation> reservations,
    DateTime now,
  ) async {
    // Any seat interaction dismisses the calendar-jump ring (#182).
    if (_highlightedSeatId != null) {
      setState(_clearHighlights);
    }
    final l10n = AppLocalizations.of(context);
    // Closed day (#186): no sheet at all — the server would reject any
    // booking touching it (`assert_workspace_open`, migration 0013).
    if (!_isWorkspaceOpenAt(now)) {
      AppSnack.info(
        context,
        l10n?.planClosedDay ?? 'Closed on this day',
        replace: true,
      );
      return;
    }
    final myMemberId = ref.read(myMemberProvider).value?.id;
    // Browsing a time frame (#184): the whole window must be free; live
    // mode keeps the instant semantics.
    final windowEnd = _browseEnd;
    final state = windowEnd == null
        ? seatStateAt(
            plan: plan,
            seat: seat,
            reservations: reservations,
            myMemberId: myMemberId,
            at: now,
          )
        : seatStateInRange(
            plan: plan,
            seat: seat,
            reservations: reservations,
            myMemberId: myMemberId,
            from: now,
            to: windowEnd,
          );
    Reservation? coveringReservation() => windowEnd == null
        ? reservationOnSeatAt(
            plan: plan,
            seat: seat,
            reservations: reservations,
            at: now,
          )
        : reservationOnSeatInRange(
            plan: plan,
            seat: seat,
            reservations: reservations,
            from: now,
            to: windowEnd,
          );

    switch (state) {
      case SeatState.blocked:
        // Owners (and delegated admins, #161) can lift the block; everyone
        // else just gets the explanation.
        if (_canManageSeatBlocks) {
          await _blockedSeatSheet(seat);
        } else {
          AppSnack.info(
            context,
            l10n?.planSeatBlocked ?? 'This seat is blocked for maintenance.',
            replace: true,
          );
        }
      case SeatState.free:
        await _bookingSheet(plan, seat, reservations, now);
      case SeatState.mine:
        final mine = coveringReservation();
        if (mine != null) await _mySeatSheet(seat, mine);
      case SeatState.reserved:
      case SeatState.occupied:
        final other = coveringReservation();
        if (other == null) return;
        final names = ref.read(memberNamesProvider).value ?? const {};
        final name = names[other.memberId] ?? '';
        // Admin powers on another member's seat: check them in while
        // present (#408 — live mode, window open, bookForOthers gate) and
        // overrule — remove the reservation with notification (#412 —
        // any admin/owner, any time). The server re-checks everything.
        final offerCheckIn = _browse == null &&
            _canCheckInForOthers &&
            other.checkInWindowOpen(ref.read(clockProvider).now(),
                granularity: ref.read(bookingGranularityProvider).value);
        final canOverrule =
            ref.read(myMemberProvider).value?.canAdminister ?? false;
        if (offerCheckIn || canOverrule) {
          await runAdminSeatActions(
            context,
            ref,
            seat: seat,
            other: other,
            name: name,
            offerCheckIn: offerCheckIn,
            stepMinutes: _granularity.stepMinutes,
            // #622 — admins get the message affordance ON TOP of their
            // admin actions (messaging's own flag gates it).
            offerMessage: canMessageReserver(ref, other),
          );
          return;
        }
        final template = state == SeatState.occupied
            ? (l10n?.planOccupiedBy(name) ?? 'Occupied by $name')
            : (l10n?.planReservedBy(name) ?? 'Reserved by $name');
        final until =
            DateFormat.Hm().format(WorkspaceTime.wall(other.endsAt));
        final infoLine =
            '$template · ${l10n?.planUntil(until) ?? 'until $until'}';
        // #622 — a REGULAR member can message the holder instead of a
        // dead-end info snack; flag off keeps the plain explanation.
        if (canMessageReserver(ref, other)) {
          await showBlockedSpaceSheet(
            context,
            ref,
            title: seat.name,
            infoLine: infoLine,
            blocking: other,
            name: name,
            spaceName: seat.name,
          );
          return;
        }
        AppSnack.info(
          context,
          infoLine,
          replace: true,
        );
    }
  }

  /// Whether the signed-in member may check in ANOTHER member's
  /// reservation (#408): admins/owners while the bookForOthers feature
  /// is on — the same gate as the "Book for" picker.
  bool get _canCheckInForOthers =>
      ref
          .read(enabledFeaturesSyncProvider)
          .contains(WorkspaceFeature.bookForOthers) &&
      (ref.read(myMemberProvider).value?.canAdminister ?? false);

  /// Sheet on another member's reserved seat for admins (#408): the
  /// member is standing there, check them in directly. The kiosk
  /// precedent — the subject confirmed the reservation; no pending
  /// event. Authorization and window are re-checked server-side (0077).

  /// Whether the signed-in member may toggle seat maintenance blocks
  /// (#161): owner always, admins with the adminSeatBlocking feature.
  bool get _canManageSeatBlocks => canManageSeatBlocks(
        member: ref.read(myMemberProvider).value,
        features: ref.read(enabledFeaturesSyncProvider),
      );

  /// Writes the seat's maintenance block via the set_seat_block RPC and
  /// refreshes the plan so the new state renders immediately (#161).
  Future<void> _setSeatBlock(Seat seat, {DateTime? from, DateTime? to}) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref
          .read(floorPlanRepositoryProvider)
          .setSeatBlock(seat.id, from: from, to: to);
    } catch (e, st) {
      debugPrint('set seat block failed: $e\n$st');
      TraceLogger.instance
          .error('plan', 'set seat block failed', error: e, stackTrace: st);
      if (!mounted) return;
      AppSnack.error(
        context,
        l10n?.workspaceGenericError ??
            'Something went wrong. Please try again.',
        replace: true,
      );
      return;
    }
    if (!mounted) return;
    ref.invalidate(floorPlanProvider);
  }

  /// Sheet on a blocked seat for owners/delegated admins (#161): explains
  /// the block and offers to make the seat reservable again.
  Future<void> _blockedSeatSheet(Seat seat) async {
    final l10n = AppLocalizations.of(context);
    final blockedText =
        l10n?.planSeatBlocked ?? 'This seat is blocked for maintenance.';
    final unblock = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(seat.name.isEmpty ? blockedText : seat.name),
              subtitle: seat.name.isEmpty ? null : Text(blockedText),
            ),
            ListTile(
              leading: const Icon(Icons.event_seat_outlined),
              title: Text(l10n?.planMakeReservable ?? 'Make reservable'),
              onTap: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (unblock != true || !mounted) return;
    await _setSeatBlock(seat);
  }

  /// Live mode: atomic walk-up check-in starting now. Browse mode: punctual
  /// reservation over the browsed window (spec §5.1, #184).
  Future<void> _bookingSheet(
    FloorPlan plan,
    Seat seat,
    List<Reservation> reservations,
    DateTime start,
  ) async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    // Defense in depth (#161): the tap handler never routes blocked seats
    // here, but a stale plan could — the RPCs reject them anyway.
    if (seat.isBlockedAt(start)) {
      AppSnack.info(
        context,
        l10n?.planSeatBlocked ?? 'This seat is blocked for maintenance.',
        replace: true,
      );
      return;
    }
    final walkUp = _browse == null;

    final features = ref.read(enabledFeaturesSyncProvider);

    // Admins and owners book for other members (#106) — when the owner
    // left the feature on (#146). No candidates = no "Book for" picker.
    final myMember = ref.read(myMemberProvider).value;
    final names = ref.read(memberNamesProvider).value ?? const {};
    final candidates = (features.contains(WorkspaceFeature.bookForOthers) &&
            (myMember?.canAdminister ?? false))
        ? [
            for (final m in (ref.read(workspaceMembersProvider).value ??
                    const <Member>[])
                .where((m) => m.status == MemberStatus.active))
              (id: m.id, name: names[m.id] ?? ''),
          ]
        : const <({String id, String name})>[];

    final next = nextReservationOnSeat(
      plan: plan,
      seat: seat,
      reservations: reservations,
      at: start,
    );
    // Browse mode (#184): the sheet opens on the browsed window's end.
    // Walk-up keeps the default stay — under half-day granularity (#201)
    // it ends at the current half-day boundary instead (before 13:00 →
    // 13:00, after → next-day 00:00) and the end is not adjustable. Both
    // stay capped by the next reservation as a safety net (a
    // range-filtered free seat cannot be capped below the window, but a
    // stale plan could).
    final granularity = _granularity;
    final dayBased = granularity.isDayBased;
    var end = walkUp
        ? (granularity == BookingGranularity.halfDay
            // #586 — a member whose default period is FULL DAY walks up
            // for the whole day; everyone else keeps the current half.
            ? (ref.read(defaultPeriodProvider).value ==
                        DefaultBookingPeriod.fullDay &&
                    HalfDayWindows.fullDay(start).end.isAfter(start)
                ? HalfDayWindows.fullDay(start).end
                : HalfDayWindows.windowForNow(start).end)
            // Full-day (0032) and hours (#446) walk-ups end at the end
            // of the working day (overtime-safe via walkUpWindow);
            // minute grids keep the default stay.
            : granularity == BookingGranularity.fullDay ||
                    granularity == BookingGranularity.hours
                ? walkUpWindow(granularity, start).end
                : start.add(_kDefaultStay))
        : (_browseEnd ?? start.add(_kDefaultStay));
    var capped = false;
    if (next != null && next.startsAt.isBefore(end)) {
      end = next.startsAt;
      capped = true;
    }

    final choice = await showModalBottomSheet<BookingChoice>(
      context: context,
      isScrollControlled: true,
      builder: (context) => BookingSheet(
        seatId: seat.id,
        seatName: seat.name,
        start: start,
        initialEnd: end,
        cap: next?.startsAt,
        capped: capped,
        granularity: granularity,
        walkUp: walkUp,
        fixedEnd: dayBased,
        members: candidates,
        myMemberId: myMember?.id,
        allowSeries: features.contains(WorkspaceFeature.seriesBooking),
        allowBlocking: _canManageSeatBlocks,
      ),
    );
    if (choice == null) return;

    // Not a booking at all: start an open-ended maintenance block (#161).
    if (choice.block) {
      await _setSeatBlock(seat, from: ref.read(clockProvider).now().toUtc());
      return;
    }

    final forOther =
        choice.forMemberId != null && choice.forMemberId != myMember?.id;
    try {
      if (forOther) {
        await ref.read(reservationRepositoryProvider).createFor(
              workspaceId: workspace.id,
              subjectMemberId: choice.forMemberId!,
              seatId: seat.id,
              startsAt: walkUp ? start : choice.start,
              endsAt: choice.end,
            );
        final who = names[choice.forMemberId] ?? '';
        if (!mounted) return;
        AppSnack.success(
          context,
          l10n?.planBookedForPending(who) ?? 'Sent to $who for confirmation.',
          replace: true,
        );
      } else if (choice.pattern == null) {
        await ref.read(reservationRepositoryProvider).create(
              workspaceId: workspace.id,
              seatId: seat.id,
              startsAt: walkUp ? start : choice.start,
              endsAt: choice.end,
              checkIn: walkUp,
            );
        // #663: SAY it worked. This path — the ordinary booking and the
        // walk-up check-in, by far the most used — used to end in
        // silence, leaving the seat's colour change as the only signal.
        // When the refresh lags, that is indistinguishable from nothing
        // having happened, and the member's only move is to try again.
        if (!mounted) return;
        announceBooking(
          context,
          l10n,
          checkedIn: walkUp,
          start: walkUp ? start : choice.start,
          end: choice.end,
          spaceName: seat.name,
        );
      } else {
        final result = await ref.read(reservationRepositoryProvider).createSeries(
              workspaceId: workspace.id,
              seatId: seat.id,
              firstStart: choice.start,
              firstEnd: choice.end,
              pattern: choice.pattern!,
              until: choice.until!,
            );
        if (mounted) await _seriesResultDialog(result);
      }
    } catch (e, st) {
      debugPrint('booking failed: $e\n$st');
      TraceLogger.instance
          .error('plan', 'booking failed', error: e, stackTrace: st);
      if (!mounted) return;
      // #186: a closed-day refusal is not "the seat was taken" — every
      // booking path here (walk-up, future reserve, series, book-for-
      // other) shares this catch, so all four get the mapping.
      AppSnack.error(
        context,
        _errorText(
          l10n,
          e,
          l10n?.planCheckInFailed ??
              'Could not check in — the seat may have just been taken.',
        ),
        replace: true,
      );
      return;
    }
    invalidateBookingData(ref);
  }

  /// Explicit exception report after booking a series (spec §5.2).
  Future<void> _seriesResultDialog(SeriesResult result) async {
    final l10n = AppLocalizations.of(context);
    final dateFormat = DateFormat.MMMEd();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          l10n?.seriesBookedCount(result.booked.length) ??
              '${result.booked.length} bookings created',
        ),
        content: result.skipped.isEmpty
            ? null
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n?.seriesSkippedTitle ??
                        'Skipped (already taken):',
                  ),
                  const SizedBox(height: 8),
                  for (final d in result.skipped)
                    Text(dateFormat.format(WorkspaceTime.dateOf(d))),
                ],
              ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n?.commonOk ?? 'OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _mySeatSheet(Seat seat, Reservation mine) async {
    final l10n = AppLocalizations.of(context);
    // Presence rule (#408): check-in means "I am standing here NOW" —
    // the real clock decides, never the browsed instant.
    final action = await showMySeatSheet(
      context,
      seat: seat,
      mine: mine,
      now: ref.read(clockProvider).now(),
      granularity: ref.read(bookingGranularityProvider).value,
    );
    if (action == null) return;
    final repo = ref.read(reservationRepositoryProvider);
    try {
      switch (action) {
        case 'checkout':
          await repo.checkOut(mine.id);
        case 'checkin':
          await repo.checkIn(mine.id);
        case 'cancel':
          await repo.cancel(mine.id);
      }
    } catch (e, st) {
      debugPrint('reservation $action failed: $e\n$st');
      TraceLogger.instance.error('plan', 'reservation $action failed',
          error: e, stackTrace: st);
      if (!mounted) return;
      // #186: the check-in RPC also asserts the workspace is open
      // (migration 0013) — map its refusal like the booking paths.
      AppSnack.error(
        context,
        _errorText(
          l10n,
          e,
          l10n?.workspaceGenericError ??
              'Something went wrong. Please try again.',
        ),
        replace: true,
      );
      return;
    }
    invalidateBookingData(ref);
  }

  @override
  Widget build(BuildContext context) {
    // #182: the calendar's "Show on plan" jump. This screen stays alive in
    // the shell's indexed stack, so the listener survives tab switches.
    ref.listen(planFocusControllerProvider, (_, focus) {
      if (focus != null) _applyFocus(focus);
    });

    final l10n = AppLocalizations.of(context);
    final levels = ref.watch(levelsProvider).value;
    if (levels == null) {
      return const LoadingView();
    }
    if (levels.isEmpty) {
      return EmptyState(
        icon: Icons.map_outlined,
        title: l10n?.planNoLevels ?? 'The workspace has no floor plan yet.',
      );
    }

    // Stored per-workspace default (#159); wait for the one-time read so
    // the plan opens directly on the member's level, no flash of level 1.
    // A failed read falls through to the first level instead of spinning.
    final selectedAsync = ref.watch(selectedLevelIdProvider);
    if (selectedAsync.isLoading && !selectedAsync.hasValue) {
      return const LoadingView();
    }
    final selectedId = selectedAsync.value;
    final level = levels.where((l) => l.id == selectedId).firstOrNull ??
        levels.first;

    final now = ref.watch(clockProvider).now();
    final at = _browse ?? now;
    // Browsing (#184): occupancy over the whole [at, windowEnd) frame;
    // null in live mode, where the instant semantics apply.
    final windowEnd = _browseEnd;
    final planAsync = ref.watch(floorPlanProvider(level.id));
    // The window may straddle TWO device-local day keys: workspace-clock
    // windows (day-based granularities) start on the previous device
    // date when the device sits west of the workspace. Fetch both ends
    // and merge, hub cross-month style.
    final reservations = reservationsAcrossWindow(
      ref,
      at,
      // Live mode has no end — the instant's own day key suffices.
      windowEnd ?? at.add(const Duration(microseconds: 1)),
    );
    final myMemberId = ref.watch(myMemberProvider).value?.id;
    final names = ref.watch(memberNamesProvider).value ?? const {};
    // #620 — occupant profile photos on every map, kiosk or not.
    final photosOn = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.planMemberPhotos);
    final memberUserIds = {
      for (final m in ref.watch(workspaceMembersProvider).value ?? <Member>[])
        m.id: m.userId,
    };
    final memberProfiles =
        ref.watch(memberProfilesProvider).value ?? const <String, Profile>{};

    // Closed day (#186): banner + muted seats + gated taps instead of
    // green "bookable" seats the server would reject. Watched (not the
    // read-based [_isWorkspaceOpenAt]) so the plan reacts to availability
    // edits; unknown while loading counts as open.
    final openWeekdays = ref.watch(openWeekdaysProvider).value;
    final closures = ref.watch(closureDaysProvider).value;
    final dayOpen = openWeekdays == null || closures == null ||
        isWorkspaceOpenOn(WorkspaceTime.dateOf(at), openWeekdays, closures);

    // Half-day granularity (#201): watched so the header swaps the time
    // chips for the Morning/Afternoon/Day chips once the rule resolves;
    // loading/unknown renders the flexible header (no flash of the wrong
    // affordance — flexible is also the rule's default).
    final granularity = ref.watch(bookingGranularityProvider).value ??
        BookingGranularity.flexible;

    // The level chips share the scroller's top row (#159). In landscape the
    // header moves into a side panel so the level fills the rest — the plan
    // gets nearly the whole screen instead of a thin strip under the chips.
    // wrap=true in the landscape sidebar: vertical space is plentiful
    // there, so the controls flow onto lines instead of hiding behind
    // the portrait row's horizontal scroll.
    final header = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // #606 — the plan's contextual how-to; gated inside the widget.
        // #611 — eased in/out at the call site instead of popping.
        const MotionReveal(child: HelpHint(HelpHintId.plan)),
        _scrollerRow(at, granularity, levels, level),
        MotionReveal(
          child: dayOpen
              ? const SizedBox.shrink(key: ValueKey('plan-open-day'))
              : _closedDayBanner(l10n),
        ),
      ],
    );
    // Floor switcher floats over the view (indoor-maps idiom, UX pass):
    // levels belong to the map, not the header. Hosts the reserve-level
    // action beneath the floors.
    final levelOverlay = (levels.length > 1 || _levelReserveVisible(level))
        ? Positioned(
            top: AppSpacing.sm,
            right: AppSpacing.sm,
            child: LevelSelector(
              keyPrefix: 'plan',
              levels: levels.length > 1 ? levels : const <Level>[],
              current: level,
              onSelected: (id) {
                setState(_clearHighlights);
                ref.read(selectedLevelIdProvider.notifier).select(id);
              },
              trailing: _levelReserveVisible(level)
                  ? IconButton(
                      key: const ValueKey('plan-reserve-level'),
                      tooltip:
                          l10n?.levelReserveButton ?? 'Reserve level',
                      icon: const Icon(Icons.layers_outlined),
                      onPressed: () => _reserveLevel(level),
                    )
                  : null,
            ),
          )
        : null;
    final content = Expanded(
          // #209: cross-fade the list/canvas toggle (and the transitions
          // out of loading/error). Distinct subtree keys make the switcher
          // treat the two views as different children; the fade stays
          // OUTSIDE the InteractiveViewer, so pan/zoom is untouched.
          child: AnimatedSwitcher(
            duration: AppMotion.viewSwitchOf(context),
            child: switch (planAsync) {
            AsyncData(value: final plan) => _listView
                ? KeyedSubtree(
                    key: const ValueKey('plan-list-view'),
                    child: _seatList(plan, reservations, names, at,
                        dayOpen: dayOpen),
                  )
                : SeatPhotoLoader(
                    key: const ValueKey('plan-canvas-view'),
                    seatUserIds: !photosOn
                        ? const {}
                        : {
                            for (final seat in plan.seats)
                              if (occupantOnSeat(
                                    plan: plan,
                                    seat: seat,
                                    reservations: reservations,
                                    from: at,
                                    to: windowEnd,
                                  )?.memberId
                                  case final occupantMemberId?)
                                if (memberUserIds[occupantMemberId] case final userId?)
                                  if (memberProfiles[userId]?.hasAvatar ?? false)
                                    seat.id: userId,
                          },
                    builder: (context, seatPhotos) => PlanCanvas(
                    seatPhotos: seatPhotos,
                    paintKey: const ValueKey('live-plan-canvas'),
                    plan: plan,
                    // Double tap = whole-space reserve / check-in
                    // (field request); only registered while the
                    // feature is on so single taps stay instant
                    // otherwise.
                    onSpaceDoubleTap: ref
                            .watch(enabledFeaturesSyncProvider)
                            .contains(WorkspaceFeature.levelBooking)
                        ? (desk, office) => showSpaceSheet(
                              context,
                              kind: desk != null
                                  ? SpaceKind.desk
                                  : office != null
                                      ? SpaceKind.office
                                      : SpaceKind.level,
                              level: level,
                              office: office ??
                                  plan.offices
                                      .where((o) => o.id == desk?.officeId)
                                      .firstOrNull,
                              desk: desk,
                              plan: plan,
                              // Seed the reserve picker with the frame
                              // being browsed (0065).
                              initialWindow: windowEnd == null
                                  ? null
                                  : (start: at, end: windowEnd),
                            )
                        : null,
                    seatStates: seatStatesFor(
                      plan: plan,
                      reservations: reservations,
                      myMemberId: myMemberId,
                      from: at,
                      to: windowEnd,
                      dayOpen: dayOpen,
                    ),
                    // #575 — the day-phase rings: served / running /
                    // still ahead, per browsed day.
                    seatDayPhases: seatDayPhasesFor(
                      plan: plan,
                      reservations: reservations,
                      at: at,
                      dayOpen: dayOpen,
                    ),
                    seatLabels: {
                      for (final seat in plan.seats)
                        seat.id: occupantLabelFor(
                          plan: plan,
                          seat: seat,
                          reservations: reservations,
                          names: names,
                          from: at,
                          to: windowEnd,
                        ),
                    },
                    // #462: whole-office/desk/level bookings mark the
                    // SPACE itself, with the occupant's name, for all.
                    spaceOverlays: spaceOverlaysFor(
                      plan: plan,
                      reservations: reservations,
                      names: names,
                      myMemberId: myMemberId,
                      from: at,
                      to: windowEnd,
                    ),
                    highlightedSeatId: _highlightedSeatId,
                    highlightedDeskId: _highlightedDeskId,
                    highlightedOfficeId: _highlightedOfficeId,
                    highlightLevel: _highlightLevel,
                    onlineSeatIds: onlineSeatIdsFor(
                      plan: plan,
                      reservations: reservations,
                      members:
                          ref.watch(workspaceMembersProvider).value ??
                              const [],
                      profiles:
                          ref.watch(memberProfilesProvider).value ??
                              const {},
                      from: at,
                      to: windowEnd,
                      now: now,
                    ),
                    deskOpacity: (ref
                                .watch(currentWorkspaceProvider)
                                .value
                                ?.deskOpacity ??
                            100) /
                        100,
                    background:
                        ref.watch(levelBackgroundProvider(level.id)).value,
                    images: {
                      // Single watch per image (perf audit): the double
                      // watch subscribed twice per image on every rebuild.
                      for (final image in plan.images)
                        image.id: ?ref.watch(planImageProvider(image.id)).value,
                    },
                    onSeatTap: (seat) =>
                        _onSeatTap(plan, seat, reservations, at),
                  ),
                  ),
            AsyncError() => Center(
                child: Text(
                  l10n?.workspaceGenericError ??
                      'Something went wrong. Please try again.',
                ),
              ),
            _ => const LoadingView(),
            },
          ),
        );
    final overlaidContent = levelOverlay == null
        ? content
        : Expanded(
            child: Stack(children: [
              // The switcher child fills; the floor buttons float above.
              Positioned.fill(
                child: Column(children: [content]),
              ),
              levelOverlay,
            ]),
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Landscape (and wide tablets): controls in a side panel, the level
        // fills the rest. Portrait: the familiar stacked layout.
        if (constraints.maxWidth > constraints.maxHeight) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                // #478: narrower sidebar — the plan is the content.
                  width:
                      (constraints.maxWidth * 0.3).clamp(260.0, 380.0),
                child: SingleChildScrollView(child: header),
              ),
              const VerticalDivider(width: 1),
              overlaidContent,
            ],
          );
        }
        return Column(children: [header, overlaidContent]);
      },
    );
  }

  /// The time scroller (spec §6, #184): list/plan toggle · date · from→to
  /// time chips (Material clock dial) · Now. Under half-day granularity
  /// (#201) the two time chips give way to the Morning/Afternoon/Day
  /// choice chips — the only selectable windows there.
  Widget _scrollerRow(
    DateTime at,
    BookingGranularity granularity,
    List<Level> levels,
    Level level,
  ) {
    final l10n = AppLocalizations.of(context);
    final dayBased = granularity.isDayBased;
    // Day-based chips describe a WORKSPACE-local day: deriving it via
    // device toLocal() shifts a day whenever the workspace midnight
    // lands on the previous device date (Pacific device, Paris space).
    final local =
        dayBased ? WorkspaceTime.dateOf(at) : WorkspaceTime.wall(at);
    final live = _browse == null;
    final endLocal =
        WorkspaceTime.wall(_browseEnd ?? _defaultEndFor(at));
    // ONE compact header row (space refactor): toggle · date · window ·
    // level · now — horizontally scrollable so every control keeps its
    // 48dp target on narrow phones (#284 idiom) while the plan canvas
    // gets the reclaimed rows. In the landscape sidebar ([wrap]) the
    // same controls flow onto lines instead — nothing hides there.
    final controls = <Widget>[
          // #211: the shared canvas/list toggle idiom (icon segments with
          // tooltips) instead of a lone flipping IconButton.
          ViewToggle<bool>(
            key: const ValueKey('plan-view-switch'),
            options: [
              ViewToggleOption(
                value: false,
                icon: Icons.map_outlined,
                tooltip: l10n?.planMapViewTooltip ?? 'Plan view',
              ),
              ViewToggleOption(
                value: true,
                icon: Icons.view_list_outlined,
                tooltip: l10n?.planListViewTooltip ?? 'List view',
              ),
            ],
            selected: _listView,
            onChanged: (listView) => setState(() => _listView = listView),
          ),
          TextButton(
            key: const ValueKey('plan-date-button'),
            onPressed: () async {
              final pickerNow = ref.read(clockProvider).now();
              final picked = await showDatePicker(
                context: context,
                initialDate: local,
                firstDate: pickerNow.subtract(const Duration(days: 365)),
                lastDate: pickerNow.add(const Duration(days: 365)),
              );
              if (picked == null) return;
              if (!mounted) return;
              final DateTime from;
              final DateTime end;
              if (dayBased) {
                // Half-day mode (#201): re-derive the canonical window on
                // the picked day — the currently selected half where one
                // is (live or a non-canonical #182 focus window browses
                // the whole day).
                final builder =
                    _selectedHalfDayBuilder(local) ?? HalfDayWindows.fullDay;
                final window =
                    builder(DateTime(picked.year, picked.month, picked.day));
                from = window.start;
                end = window.end;
              } else {
                // Keep the window's times on the newly picked day (#184).
                from = DateTime(
                  picked.year,
                  picked.month,
                  picked.day,
                  local.hour,
                  local.minute,
                );
                var kept = DateTime(
                  picked.year,
                  picked.month,
                  picked.day,
                  endLocal.hour,
                  endLocal.minute,
                );
                if (!kept.isAfter(from)) kept = _defaultEndFor(from);
                end = kept;
              }
              setState(() {
                _clearHighlights();
                _browse = from;
                _browseEnd = end;
              });
            },
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.calendar_month_outlined, size: 18),
              const SizedBox(width: 4),
              Text(DateFormat.MMMd().format(local)),
            ]),
          ),
          // The shared window controls, inline (space refactor): the
          // former full-width chips row is gone.
          WindowControls(
            keyPrefix: 'plan',
            granularity: granularity,
            day: local,
            isSelected: (w) =>
                _browse == w.start && _browseEnd == w.end,
            onPickWindow: (w) => setState(() {
              // Window change drops the #182 jump highlight like every
              // other time-scroller interaction.
              _clearHighlights();
              _browse = w.start;
              _browseEnd = w.end;
            }),
            from: local,
            to: endLocal,
            onPickFrom: _pickFrom,
            onPickTo: _pickTo,
            muted: live,
          ),
          // 'Now' returns to the live instant — shown only while
          // browsing (contextual; an always-visible disabled button was
          // header noise).
          if (!live)
            IconButton(
              key: const ValueKey('plan-now-button'),
              tooltip: l10n?.planNowButton ?? 'Now',
              icon: const Icon(Icons.schedule_outlined),
              onPressed: () => setState(() {
                _clearHighlights();
                _browse = null;
                _browseEnd = null;
              }),
            ),
    ];
    // A Wrap, never a scroll: every control stays visible at any width
    // (the scroll-row hid half the header on phones — field report).
    // Normally one line; narrow widths flow onto a second.
    return Padding(
      padding: AppSpacing.smH,
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: controls,
      ),
    );
  }

  /// Whether the reserve-level affordance shows for [level] (0050):
  /// feature on + level bookable + the member may book one themselves OR
  /// may assign one (owner always, admin with adminLevelAssign).
  bool _levelReserveVisible(Level level) {
    final features = ref.watch(enabledFeaturesSyncProvider);
    if (!features.contains(WorkspaceFeature.levelBooking)) return false;
    if (!level.bookableAsWhole) return false;
    final me = ref.watch(myMemberProvider).value;
    if (me == null || me.status != MemberStatus.active) return false;
    // #412 (0079): owners/admins are implicitly allowed to book too.
    return me.canReserveLevel || me.canAdminister ||
        _canAssignLevel(me, features);
  }

  bool _canAssignLevel(Member me, Set<WorkspaceFeature> features) =>
      me.actsAsOwner ||
      (me.canAdminister &&
          features.contains(WorkspaceFeature.adminLevelAssign));

  /// Books [level] as ONE reservation — for myself (needs the personal
  /// grant) or, for owners/delegated admins, assigned to another member
  /// (their confirmation flow applies, #106).
  ///
  /// #638: this used to open a SECOND whole-space sheet of its own, with
  /// the assignment dropdown but a static window — no period picker, no
  /// series — while the double-tap path opened [SpaceSheet] with the
  /// picker but no assignment. They converged on [SpaceSheet]; this
  /// method now only computes the roster and the seed window it needs.
  Future<void> _reserveLevel(Level level) async {
    final me = ref.read(myMemberProvider).value;
    if (ref.read(currentWorkspaceProvider).value == null || me == null) {
      return;
    }
    final features = ref.read(enabledFeaturesSyncProvider);
    final names = await ref.read(memberNamesProvider.future);
    // Await the roster (unlike the seat sheet, this can be the first
    // reader) so the assignment dropdown never renders half-loaded.
    final candidates = _canAssignLevel(me, features)
        ? [
            for (final m in (await ref.read(workspaceMembersProvider.future))
                .where((m) =>
                    m.status == MemberStatus.active && !m.isKiosk))
              (id: m.id, name: names[m.id] ?? ''),
          ]
        : const <({String id, String name})>[];
    if (!mounted) return;

    final start = _browse ?? ref.read(clockProvider).now();
    final granularity = _granularity;
    final end = _browseEnd ??
        (granularity == BookingGranularity.halfDay
            // #586 — the member's default period drives the suggestion.
            ? (ref.read(defaultPeriodProvider).value ==
                        DefaultBookingPeriod.fullDay &&
                    HalfDayWindows.fullDay(start).end.isAfter(start)
                ? HalfDayWindows.fullDay(start).end
                : HalfDayWindows.windowForNow(start).end)
            : granularity == BookingGranularity.fullDay
                ? HalfDayWindows.fullDay(start).end
                : start.add(_kDefaultStay));

    await showSpaceSheet(
      context,
      kind: SpaceKind.level,
      level: level,
      plan: ref.read(floorPlanProvider(level.id)).value,
      initialWindow: (start: start, end: end),
      members: candidates,
    );
  }


  /// The canonical builder whose window on [day] the current browse
  /// window matches — null when live or browsing a non-canonical window
  /// (a legacy reservation reached via the #182 focus jump).
  HalfDayWindow Function(DateTime day)? _selectedHalfDayBuilder(
    DateTime day,
  ) {
    const builders = [
      HalfDayWindows.morning,
      HalfDayWindows.afternoon,
      HalfDayWindows.fullDay,
    ];
    for (final builder in builders) {
      final window = builder(day);
      if (_browse == window.start && _browseEnd == window.end) {
        return builder;
      }
    }
    return null;
  }

  /// Half-day header chips (#201): Morning / Afternoon / Day replace the
  /// from→to time chips — a tap enters (or moves) browse mode with the
  /// canonical window on the browsed day (today when live). Live mode
  /// shows no selection; "Now" resets to live as usual.

  /// Closed-day banner under the header row (#186): the workspace is not
  /// open on the browsed/live day (weekday not open or closure day), so
  /// nothing below is bookable. Shared [InlineBanner] since #210.
  Widget _closedDayBanner(AppLocalizations? l10n) {
    return InlineBanner(
      key: const ValueKey('plan-closed-banner'),
      icon: Icons.event_busy,
      text: l10n?.planClosedDay ?? 'Closed on this day',
    );
  }

  /// From-chip tap (#184): clock-dial pick of the window start. Live mode
  /// enters browsing with the picked start and a default-length window;
  /// browse mode moves the start, keeping the duration where the day
  /// allows it.
  Future<void> _pickFrom() async {
    final current =
        WorkspaceTime.wall(_browse ?? ref.read(clockProvider).now());
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (picked == null) return;
    if (!mounted) return;
    final wasLive = _browse == null;
    final duration =
        wasLive ? _kDefaultStay : _browseEnd!.difference(_browse!);
    final from = _snapToSlot(WorkspaceTime.at(
      current.year,
      current.month,
      current.day,
      picked.hour,
      picked.minute,
    ));
    var end = from.add(duration);
    final last = _lastSlotOf(from);
    if (end.isAfter(last)) end = last;
    if (!end.isAfter(from)) end = from.add(_timeSnap);
    setState(() {
      _clearHighlights();
      _browse = from;
      _browseEnd = end;
    });
  }

  /// To-chip tap (#184): clock-dial pick of the window end. Live mode
  /// enters browsing with the start snapped to "now"; a pick at/before the
  /// start is rejected with a snackbar instead of silently rolling over to
  /// the next day (the booking sheet's own "Until" keeps its roll-over).
  Future<void> _pickTo() async {
    final now = ref.read(clockProvider).now();
    final from = _browse ?? _snapToSlot(now);
    final fromWall = WorkspaceTime.wall(from);
    final currentEnd =
        WorkspaceTime.wall(_browseEnd ?? _defaultEndFor(_browse ?? now));
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(currentEnd),
    );
    if (picked == null) return;
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final end = _snapToSlot(WorkspaceTime.at(
      fromWall.year,
      fromWall.month,
      fromWall.day,
      picked.hour,
      picked.minute,
    ));
    if (!end.isAfter(from)) {
      AppSnack.error(
        context,
        l10n?.planEndBeforeStart ?? 'End must be after start.',
        replace: true,
      );
      return;
    }
    setState(() {
      _clearHighlights();
      _browse = from;
      _browseEnd = end;
    });
  }

  /// Chronological reservations of the browsed day (spec §6 list view).
  /// #104: the list view mirrors the plan — every seat of the level with
  /// its state over the browsed window (live: at this instant), tappable
  /// exactly like the canvas.
  Widget _seatList(
    FloorPlan plan,
    List<Reservation> reservations,
    Map<String, String> names,
    DateTime at, {
    required bool dayOpen,
  }) {
    final l10n = AppLocalizations.of(context);
    final timeFormat = DateFormat.Hm();
    final myMemberId = ref.watch(myMemberProvider).value?.id;

    if (plan.seats.isEmpty) {
      return EmptyState(
        icon: Icons.event_seat_outlined,
        title: l10n?.planNoSeats ?? 'This level has no seats yet.',
      );
    }

    String contextOf(Seat seat) {
      final desk =
          plan.desks.where((d) => d.id == seat.deskId).firstOrNull;
      final office = desk == null
          ? null
          : plan.offices.where((o) => o.id == desk.officeId).firstOrNull;
      return [office?.name, desk?.name]
          .whereType<String>()
          .where((n) => n.isNotEmpty)
          .join(' · ');
    }

    final seats = [...plan.seats]..sort((a, b) => a.name.compareTo(b.name));

    return ListView.builder(
      itemCount: seats.length,
      itemBuilder: (context, index) {
        final seat = seats[index];
        // Browsing (#184): the row mirrors the canvas — occupancy over the
        // whole window, instant-based in live mode. Closed day (#186):
        // every row muted like the canvas, tap gated in [_onSeatTap].
        final windowEnd = _browseEnd;
        final state = !dayOpen
            ? SeatState.blocked
            : windowEnd == null
                ? seatStateAt(
                    plan: plan,
                    seat: seat,
                    reservations: reservations,
                    myMemberId: myMemberId,
                    at: at,
                  )
                : seatStateInRange(
                    plan: plan,
                    seat: seat,
                    reservations: reservations,
                    myMemberId: myMemberId,
                    from: at,
                    to: windowEnd,
                  );
        final covering = windowEnd == null
            ? reservationOnSeatAt(
                plan: plan,
                seat: seat,
                reservations: reservations,
                at: at,
              )
            : reservationOnSeatInRange(
                plan: plan,
                seat: seat,
                reservations: reservations,
                from: at,
                to: windowEnd,
              );
        final until = covering == null
            ? null
            : timeFormat.format(covering.endsAt.toLocal());
        final who = covering == null
            ? ''
            : (names[covering.memberId] ?? '');
        // Closed day (#186): the muted state is the day's, not the
        // seat's — say so instead of the maintenance-block text.
        final stateText = !dayOpen
            ? (l10n?.planClosedDay ?? 'Closed on this day')
            : switch (state) {
                SeatState.free => l10n?.planStateFree ?? 'Free',
                SeatState.blocked => l10n?.planSeatBlocked ??
                    'This seat is blocked for maintenance.',
                SeatState.mine =>
                  '${l10n?.planStateYours ?? 'Yours'} · ${l10n?.planUntil(until ?? '') ?? 'until $until'}',
                SeatState.reserved =>
                  '${l10n?.planReservedBy(who) ?? 'Reserved by $who'} · ${l10n?.planUntil(until ?? '') ?? 'until $until'}',
                SeatState.occupied =>
                  '${l10n?.planOccupiedBy(who) ?? 'Occupied by $who'} · ${l10n?.planUntil(until ?? '') ?? 'until $until'}',
              };
        final accent = SeatStateColors.of(
          state,
          brightness: Theme.of(context).brightness,
        );
        // #575 — the same day-phase glance as the canvas ring: a dot
        // beside the seat icon (green = running, half green = still
        // ahead today, grey = already served).
        final phase = !dayOpen
            ? SeatDayPhase.none
            : seatDayPhaseAt(
                plan: plan,
                seat: seat,
                reservations: reservations,
                at: at,
              );
        final freeColor = SeatStateColors.of(
          SeatState.free,
          brightness: Theme.of(context).brightness,
        );
        final phaseColor = switch (phase) {
          SeatDayPhase.ongoing => freeColor,
          SeatDayPhase.upcoming => freeColor.withValues(alpha: 0.5),
          SeatDayPhase.past => SeatStateColors.of(
              SeatState.blocked,
              brightness: Theme.of(context).brightness,
            ),
          SeatDayPhase.none => null,
        };
        return ListTile(
          leading: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                switch (state) {
                  SeatState.free => Icons.event_seat_outlined,
                  SeatState.blocked => Icons.block,
                  _ => Icons.event_seat,
                },
                color: accent,
              ),
              if (phaseColor != null)
                Positioned(
                  right: -3,
                  top: -3,
                  child: Container(
                    key: ValueKey('seat-day-phase-${seat.id}'),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: phaseColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          title: Text(seat.name.isEmpty ? contextOf(seat) : seat.name),
          subtitle: Text(
            [contextOf(seat), stateText]
                .where((s) => seat.name.isNotEmpty || s != contextOf(seat))
                .where((s) => s.isNotEmpty)
                .join('\n'),
          ),
          isThreeLine: seat.name.isNotEmpty && contextOf(seat).isNotEmpty,
          onTap: () => _onSeatTap(plan, seat, reservations, at),
        );
      },
    );
  }

}
