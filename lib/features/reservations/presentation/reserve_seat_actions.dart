// SPDX-License-Identifier: 0BSD
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/time/clock.dart';
import '../../../core/time/workspace_time.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/app_snack.dart';
import '../../../l10n/app_localizations.dart';
import '../../plan/domain/floor_plan.dart';
import '../../plan/domain/seat.dart';
import '../../plan/presentation/widgets/admin_seat_actions.dart';
import '../../plan/presentation/widgets/check_in_sheets.dart';
import '../../plan/providers/floor_plan_providers.dart';
import '../../workspace/domain/booking_granularity.dart';
import '../../workspace/domain/member.dart';
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../../plan/domain/seat_block_policy.dart';
import '../domain/booking_error_text.dart';
import '../../plan/domain/half_day_windows.dart';
import '../domain/default_booking_period.dart';
import '../domain/reservation.dart';
import '../domain/seat_state_logic.dart';
import '../domain/walk_up_window.dart';
import '../../events/providers/event_providers.dart';
import '../providers/default_period_controller.dart';
import '../providers/reservation_providers.dart';
import 'booking_feedback.dart';
import 'booking_trace_points.dart';
import 'widgets/booking_sheet.dart';
import 'widgets/message_reserver.dart';
import 'widgets/series_result_dialog.dart';

/// ACTING ON A SEAT (#687), lifted out of the Reserve hub.
///
/// This is the Plan tab's job, ported when that tab was deleted: tap a
/// seat and get the right thing — book it, walk up to it, check in or
/// out of your own, act on someone else's as an admin, block it for
/// maintenance, or be told who has it and offered a message.
///
/// A mixin rather than a widget, because none of it RENDERS: every
/// branch opens a sheet or calls a repository and reports what happened.
/// The hub keeps the screen; this keeps the decisions.
///
/// The host supplies the handful of things these decisions need — the
/// live/browsing distinction above all, which changes what a tap MEANS
/// rather than just what it books.
mixin ReserveSeatActions<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  /// LIVE = today with no hand-picked window. A free-seat tap is then a
  /// walk-up ("I am sitting here"), and seats are judged at the INSTANT
  /// rather than across a window — a desk booked for 16:00 must not read
  /// as taken all afternoon.
  bool get isLive;

  /// #772 — the browsed window contains now (workspace wall time).
  bool get windowIsNow;

  BookingGranularity get granularity;

  /// The window a booking would take when not walking up.
  HalfDayWindow get bookingWindow;

  /// Whether the workspace is open at [at] (#186): a closed day refuses
  /// server-side, so the tap must not open a sheet at all.
  bool isWorkspaceOpenAt(DateTime at);

  /// Default end for a start, clamped to the day's last slot.
  DateTime defaultEndFor(DateTime from);

  /// The day's last selectable slot.
  DateTime lastSlotOf(DateTime day);

  /// Opens a reservation's detail sheet.
  Future<void> openReservation(Reservation reservation);

  /// Maps a server refusal to the sentence that says what to do about
  /// it — closed day, seat just taken, beyond quota. A generic
  /// "something went wrong" to someone standing at a desk is useless.
  String _errorText(AppLocalizations? l10n, Object error, String fallback) =>
      bookingErrorText(l10n, error, fallback,
          stepMinutes: granularity.stepMinutes);

  /// Members an admin may book FOR (#106), when the owner left the
  /// feature on. Empty = no "Book for" picker at all.
  List<({String id, String name})> get _bookingCandidates {
    final features = ref.read(enabledFeaturesSyncProvider);
    final myMember = ref.read(myMemberProvider).value;
    if (!features.contains(WorkspaceFeature.bookForOthers) ||
        !(myMember?.canAdminister ?? false)) {
      return const [];
    }
    final names = ref.read(memberNamesProvider).value ?? const {};
    return [
      for (final m
          in (ref.read(workspaceMembersProvider).value ?? const <Member>[])
              .where((m) => m.status == MemberStatus.active))
        (id: m.id, name: names[m.id] ?? ''),
    ];
  }

  /// Whether I may check in ANOTHER member's reservation (#408):
  /// admins/owners while bookForOthers is on — the same gate as the
  /// "Book for" picker.
  bool get _canCheckInForOthers =>
      ref
          .read(enabledFeaturesSyncProvider)
          .contains(WorkspaceFeature.bookForOthers) &&
      (ref.read(myMemberProvider).value?.canAdminister ?? false);

  /// Whether I may toggle seat maintenance blocks (#161): owner always,
  /// admins with the adminSeatBlocking feature.
  bool get _canManageSeatBlocks => canManageSeatBlocks(
        member: ref.read(myMemberProvider).value,
        features: ref.read(enabledFeaturesSyncProvider),
      );

  /// THE tap. Everything above is what it dispatches to.
  Future<void> onSeatTap(
    FloorPlan plan,
    Seat seat,
    List<Reservation> reservations,
    HalfDayWindow window,
  ) async {
    final l10n = AppLocalizations.of(context);
    // Closed day (#186): no sheet at all — the server would reject any
    // booking touching it (`assert_workspace_open`, migration 0013).
    if (!isWorkspaceOpenAt(window.start)) {
      traceClosedDay(seat, window.start);
      AppSnack.info(
        context,
        l10n?.planClosedDay ?? 'Closed on this day',
        replace: true,
      );
      return;
    }
    final myMemberId = ref.read(myMemberProvider).value?.id;
    if (myMemberId == null) traceMemberIdentityMissing(seat);
    // #687 — LIVE mode judges the seat at THIS INSTANT, browsing judges
    // it across the window.
    //
    // The difference matters and the range answer is wrong for a
    // walk-up: a seat that is empty now but booked by someone at 16:00
    // is "reserved" across a four-hour window, so tapping it would
    // refuse to seat the person standing in front of it. Point-in-time
    // says free, and the booking sheet caps the stay at 16:00 — which is
    // what the Plan tab did, and what "I am sitting here" means.
    final state = isLive
        ? seatStateAt(
            plan: plan,
            seat: seat,
            reservations: reservations,
            myMemberId: myMemberId,
            at: ref.read(clockProvider).now(),
          )
        : seatStateInRange(
            plan: plan,
            seat: seat,
            reservations: reservations,
            myMemberId: myMemberId,
            from: window.start,
            to: window.end,
          );
    traceSeatTap(
      seat: seat,
      state: state,
      live: isLive,
      granularity: granularity,
      member: myMemberId,
    );
    switch (state) {
      case SeatState.blocked:
        // #687 — blocking MANAGEMENT lives here now. It used to say "that
        // stays on the Plan tab", and there is no Plan tab.
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
        await bookingSheet(seat, reservations, window,
            plan: plan, walkUp: isLive);
      case SeatState.mine:
        final mine = _coveringReservation(plan, seat, reservations, window);
        // #687 — MANAGEMENT, not just visibility: check in, check out,
        // cancel. The hub used to defer this to the Plan tab.
        if (mine != null) {
          await _mySeatSheet(seat, mine);
        } else {
          traceCoveringReservationMissing(
              seat: seat, state: state, live: isLive);
        }
      case SeatState.reserved:
      case SeatState.occupied:
        final other = _coveringReservation(plan, seat, reservations, window);
        if (other == null) return;
        final names = ref.read(memberNamesProvider).value ?? const {};
        final name = names[other.memberId] ?? '';
        // #687 — admin powers on another member's seat came with the
        // Plan tab's job: check them in while they are standing there
        // (#408 — live only, window open, bookForOthers gate) and
        // overrule, which removes the reservation with a notification
        // (#412 — any admin, any time). The server re-checks both.
        final windowOpen = other.checkInWindowOpen(
          ref.read(clockProvider).now(),
          granularity: granularity,
        );
        final offerCheckIn = isLive && _canCheckInForOthers && windowOpen;
        if (!offerCheckIn) {
          traceCheckInNotOffered(
            seat: seat,
            other: other,
            live: isLive,
            mayCheckInOthers: _canCheckInForOthers,
            windowOpen: windowOpen,
          );
        }
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
            stepMinutes: granularity.stepMinutes,
            // #622 — admins get the message affordance ON TOP of their
            // admin actions.
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
        // #622 — a REGULAR member can message the holder instead of
        // reading a dead-end snack; the flag off keeps the plain line.
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
        AppSnack.info(context, infoLine, replace: true);
    }
  }

  /// The reservation the tap is ABOUT, resolved the same way the state
  /// was: at the instant while live, across the window while browsing.
  /// Mixing the two hands the sheet a different booking from the one the
  /// colour came from.
  Reservation? _coveringReservation(
    FloorPlan plan,
    Seat seat,
    List<Reservation> reservations,
    HalfDayWindow window,
  ) =>
      isLive
          ? reservationOnSeatAt(
              plan: plan,
              seat: seat,
              reservations: reservations,
              at: ref.read(clockProvider).now(),
            )
          : reservationOnSeatInRange(
              plan: plan,
              seat: seat,
              reservations: reservations,
              from: window.start,
              to: window.end,
            );

  /// Sheet on a blocked seat for owners/delegated admins (#161):
  /// explains the block and offers to make the seat reservable again.
  Future<void> _blockedSeatSheet(Seat seat) async {
    final l10n = AppLocalizations.of(context);
    final blockedText =
        l10n?.planSeatBlocked ?? 'This seat is blocked for maintenance.';
    final unblock = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            title: Text(seat.name.isEmpty ? blockedText : seat.name),
            subtitle: seat.name.isEmpty ? null : Text(blockedText),
          ),
          ListTile(
            key: const ValueKey('reserve-make-reservable'),
            leading: const Icon(Icons.event_seat_outlined),
            title: Text(l10n?.planMakeReservable ?? 'Make reservable'),
            onTap: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (unblock != true || !mounted) return;
    await runGuarded(
      context,
      domain: 'reservations',
      message: 'set seat block failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () =>
          ref.read(floorPlanRepositoryProvider).setSeatBlock(seat.id),
    );
    if (mounted) ref.invalidate(floorPlanProvider);
  }

  /// My own seat: check in, check out, cancel (#408).
  ///
  /// Presence rule: check-in means "I am standing here NOW", so the REAL
  /// clock decides, never the browsed instant.
  Future<void> _mySeatSheet(Seat seat, Reservation mine) async {
    final l10n = AppLocalizations.of(context);
    final now = ref.read(clockProvider).now();
    final windowOpen = mine.checkInWindowOpen(now, granularity: granularity);
    traceMySeatSheet(
      seat: seat,
      mine: mine,
      windowOpen: windowOpen,
      now: now,
      granularity: granularity,
    );
    final action = await showMySeatSheet(
      context,
      seat: seat,
      mine: mine,
      now: now,
      granularity: granularity,
    );
    traceMySeatAction(mine: mine, action: action, windowOpen: windowOpen);
    if (action == null || !mounted) return;
    final repo = ref.read(reservationRepositoryProvider);
    try {
      await switch (action) {
        'checkout' => repo.checkOut(mine.id),
        'checkin' => repo.checkIn(mine.id),
        _ => repo.cancel(mine.id),
      };
    } catch (e, st) {
      TraceLogger.instance.error(
        'reservations',
        'reservation $action failed',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      // MAPPED, not generic. #186 — the check-in RPC also asserts the
      // workspace is open (migration 0013), and a closed day, a seat
      // taken a second ago and a quota refusal each have their own
      // sentence. A static "something went wrong" here tells someone
      // standing at a desk nothing about what to do next.
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
    if (mounted) invalidateBookingData(ref);
  }

  /// Punctual reservation over the browsed window via the shared
  /// [BookingSheet] (#206) — never a walk-up, never a series, never a
  /// maintenance block (those stay on the Plan tab).
  /// The plan containing [seatId] — the Day/Week hub surfaces span all
  /// levels, so a tapped seat's plan is resolved from the loaded plans
  /// (#452: the next-reservation cap needs it for whole-space rows).
  FloorPlan? _planContaining(String seatId) {
    final levels = ref.read(levelsProvider).value ?? const [];
    for (final level in levels) {
      final plan = ref.read(floorPlanProvider(level.id)).value;
      if (plan != null && plan.seats.any((s) => s.id == seatId)) return plan;
    }
    return null;
  }

  /// The booking sheet, also reached from the Day and Week views where a
  /// free slot is tapped directly.
  /// [walkUp] is whether this tap MEANS "I am sitting here now".
  ///
  /// Only the plan's free-seat tap in live mode does. A Day-row or
  /// Week-cell tap books the slot it names — deriving it from `isLive`
  /// alone turned "reserve tomorrow morning" into a check-in the moment
  /// the hub happened to be showing today.
  Future<void> bookingSheet(
    Seat seat,
    List<Reservation> reservations,
    HalfDayWindow window, {
    FloorPlan? plan,
    bool walkUp = false,
  }) async {
    final liveWindow = !walkUp && windowIsNow;
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    // Defense in depth (#161): the tap handler never routes blocked seats
    // here, but a stale plan could — the RPCs reject them anyway.
    if (seat.isBlockedAt(window.start)) {
      AppSnack.info(
        context,
        l10n?.planSeatBlocked ?? 'This seat is blocked for maintenance.',
        replace: true,
      );
      return;
    }
    final myMemberId = ref.read(myMemberProvider).value?.id;
    final dayBased = granularity.isDayBased;
    // Cap by the next reservation on the seat (plan parity): a
    // range-filtered free seat cannot be capped below the window, but a
    // stale plan could.
    // Whole-space rows need the seat's plan; without one the cap is
    // skipped — the server re-checks every booking anyway.
    final seatPlan = plan ?? _planContaining(seat.id);
    final next = seatPlan == null
        ? null
        : nextReservationOnSeat(
            plan: seatPlan,
            seat: seat,
            reservations: reservations,
            at: window.start,
          );
    // #687 — a WALK-UP ends where the current stint ends, not where the
    // browsed window does. Ported with the Plan tab's job: under
    // half-day granularity that is the current half (or the whole day
    // for a member whose default period IS the day, #586); full-day and
    // hourly grids end with the working day, overtime-safe; a minute
    // grid keeps the default stay.
    //
    // Without this, walking up in a half-day workspace booked the
    // member's default period from NOW — a morning that started at 11:00
    // and ran to midnight.
    var end = !walkUp
        ? window.end
        : switch (granularity) {
            BookingGranularity.halfDay => (ref
                            .read(defaultPeriodProvider)
                            .value ==
                        DefaultBookingPeriod.fullDay &&
                    HalfDayWindows.fullDay(window.start).end
                        .isAfter(window.start))
                ? HalfDayWindows.fullDay(window.start).end
                : HalfDayWindows.windowForNow(window.start).end,
            BookingGranularity.fullDay ||
            BookingGranularity.hours =>
              walkUpWindow(granularity, window.start).end,
            _ => defaultEndFor(window.start),
          };
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
        start: window.start,
        initialEnd: end,
        cap: next?.startsAt,
        capped: capped,
        granularity: granularity,
        // #687 — the hub is the only map surface now, so it owns the
        // walk-up: on a live view a free-seat tap is "I am sitting here",
        // not a reservation for later.
        walkUp: walkUp,
        liveWindow: liveWindow,
        fixedEnd: dayBased,
        members: _bookingCandidates,
        myMemberId: myMemberId,
        // Series is available from the hub too now (was Plan-only): the
        // repeat picker shows when the workspace enables it.
        allowSeries: ref
            .read(enabledFeaturesSyncProvider)
            .contains(WorkspaceFeature.seriesBooking),
        // #687 — blocking a free seat for maintenance (#161) came with
        // the Plan tab's job. The sheet has always offered it; the hub
        // passed false because the Plan tab owned the power.
        allowBlocking: _canManageSeatBlocks,
      ),
    );
    if (choice == null || !mounted) return;
    // Blocking is not a booking: it takes the seat OUT of service from
    // now, open-ended, and returns before any reservation is created.
    if (choice.block) {
      await runGuarded(
        context,
        domain: 'reservations',
        message: 'set seat block failed',
        errorText: l10n?.workspaceGenericError ??
            'Something went wrong. Please try again.',
        action: () => ref.read(floorPlanRepositoryProvider).setSeatBlock(
              seat.id,
              from: ref.read(clockProvider).now().toUtc(),
            ),
      );
      if (mounted) ref.invalidate(floorPlanProvider);
      return;
    }

    try {
      // #687 — booking FOR someone else (#106). The hub showed no picker
      // and, once it did, still ignored `forMemberId` — which would have
      // booked the seat for ME while naming someone else on the sheet.
      // A confirmation request, never a check-in: the subject has not
      // agreed to anything yet.
      if (choice.forMemberId != null && choice.forMemberId != myMemberId) {
        await ref.read(reservationRepositoryProvider).createFor(
              workspaceId: workspace.id,
              subjectMemberId: choice.forMemberId!,
              seatId: seat.id,
              startsAt: choice.start,
              endsAt: choice.end,
            );
        final who =
            (ref.read(memberNamesProvider).value ?? const {})[
                    choice.forMemberId] ??
                '';
        if (!mounted) return;
        AppSnack.success(
          context,
          l10n?.planBookedForPending(who) ?? 'Sent to $who for confirmation.',
          replace: true,
        );
      } else if (choice.pattern == null) {
        if (!walkUp && !choice.checkInNow && liveWindow) {
          traceReserveWithoutCheckIn(
              seat: seat, start: choice.start, end: choice.end);
        }
        await ref.read(reservationRepositoryProvider).create(
              workspaceId: workspace.id,
              seatId: seat.id,
              startsAt: choice.start,
              endsAt: choice.end,
              // #687 — a LIVE free-seat tap is a walk-up: "I am sitting
              // here", so it checks in atomically. Booking without the
              // check-in left someone at a desk the plan showed as
              // merely reserved.
              checkIn: walkUp || choice.checkInNow,
            );
        // #663: the Reserve hub reported every refusal and no success at
        // all — a booking simply happened, or appeared to. Say which.
        if (!mounted) return;
        announceBooking(context, l10n,
            // #687 — a LIVE tap is a walk-up: it checks in. Reporting
            // `false` here while the server checked them in is the
            // confirmation lying about what just happened.
            checkedIn: walkUp || choice.checkInNow,
            start: choice.start,
            end: choice.end,
            spaceName: seat.name);
      } else {
        final result =
            await ref.read(reservationRepositoryProvider).createSeries(
                  workspaceId: workspace.id,
                  seatId: seat.id,
                  firstStart: choice.start,
                  firstEnd: choice.end,
                  pattern: choice.pattern!,
                  until: choice.until!,
                );
        if (mounted) await showSeriesResultDialog(context, result);
      }
    } catch (e, st) {
      debugPrint('reserve hub booking failed: $e\n$st');
      TraceLogger.instance
          .error('reserve', 'booking failed', error: e, stackTrace: st);
      if (!mounted) return;
      AppSnack.error(
        context,
        _errorText(
          l10n,
          e,
          // #687 — say what was ATTEMPTED. A live tap is a walk-up
          // check-in; "could not reserve" sends someone standing at the
          // desk looking for a reservation they never tried to make.
          walkUp
              ? (l10n?.planCheckInFailed ??
                  'Could not check in — the seat may have just been taken.')
              : (l10n?.reserveBookingFailed ??
                  'Could not reserve — the seat may have just been taken.'),
        ),
        replace: true,
      );
      return;
    }
    if (!mounted) return;
    invalidateBookingData(ref);
  }
}
