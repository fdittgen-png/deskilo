// SPDX-License-Identifier: MIT
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException;

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/seat_state_colors.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/providers/event_providers.dart';
import '../../../reservations/domain/reservation.dart';
import '../../../reservations/domain/reservation_repository.dart';
import '../../../reservations/domain/seat_state_logic.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../../workspace/domain/booking_granularity.dart';
import '../../../workspace/domain/member.dart';
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
import '../widgets/floor_plan_painter.dart';
import '../widgets/seat_accessory_row.dart';

/// Cell size of the live plan (denser than the editor).
const double _kCellSize = 14;

/// Default walk-up duration when nothing caps it earlier (spec §4.2;
/// becomes a workspace setting with the Epic-#5 rules engine).
const Duration _kDefaultStay = Duration(hours: 4);

/// Snapping of the header's from/to time chips (#184): 15-minute steps,
/// matching the old slider's granularity.
const int _kSnapMinutes = 15;
const Duration _kTimeSnap = Duration(minutes: _kSnapMinutes);

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pending = ref.read(planFocusControllerProvider);
      if (pending != null) _applyFocus(pending);
    });
  }

  /// Consumes a calendar "Show on plan" request (#182): switch the level
  /// transiently (never persisting the member's default), browse to the
  /// reservation start when it is still ahead (otherwise stay live), leave
  /// list view, ring the seat — then clear the one-shot signal.
  void _applyFocus(PlanFocus focus) {
    ref.read(selectedLevelIdProvider.notifier).showTransient(focus.levelId);
    final at = focus.at;
    final from =
        (at != null && at.isAfter(DateTime.now())) ? at.toLocal() : null;
    setState(() {
      _listView = false;
      _highlightedSeatId = focus.seatId;
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
    var end = covering.endsAt.toLocal();
    final last = _lastSlotOf(from);
    if (end.isAfter(last)) end = last;
    if (!end.isAfter(from)) return;
    setState(() => _browseEnd = end);
  }

  /// The day's last selectable slot (#184): 23:45 local of [day].
  DateTime _lastSlotOf(DateTime day) {
    final local = day.toLocal();
    return DateTime(
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
    final local = from.toLocal();
    var end = local.add(_kDefaultStay);
    final last = _lastSlotOf(local);
    if (end.isAfter(last)) end = last;
    if (!end.isAfter(local)) end = local.add(_kTimeSnap);
    return end;
  }

  /// Snaps [t] down to the previous 15-minute slot (#184), like the old
  /// slider did.
  DateTime _snapToSlot(DateTime t) {
    final local = t.toLocal();
    final m =
        (local.hour * 60 + local.minute) ~/ _kSnapMinutes * _kSnapMinutes;
    return DateTime(local.year, local.month, local.day, m ~/ 60, m % 60);
  }

  @override
  void dispose() {
    _minuteTick?.cancel();
    super.dispose();
  }

  String _firstName(String name) =>
      name.split(' ').firstOrNull ?? name;

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
    return isWorkspaceOpenOn(at.toLocal(), openWeekdays, closures);
  }

  /// Booking failure snackbar text (#186): the server's closed-day
  /// refusal (`assert_workspace_open`, migration 0013) gets its own
  /// explanation instead of [fallback]'s misleading generic one. Same for
  /// the half-day granularity refusal (`enforce_booking_rules`, migration
  /// 0025, #201) — defensive: the half-day UI only produces the canonical
  /// windows, but a stale rule or legacy client path can still trip it.
  String _bookingErrorText(
    AppLocalizations? l10n,
    Object error,
    String fallback,
  ) {
    if (error is PostgrestException &&
        error.message.contains(WorkspaceClosedError.serverSubstring)) {
      return l10n?.planClosedDayError ??
          'The workspace is closed on that day.';
    }
    if (error is PostgrestException &&
        error.message.contains(BookingGranularityError.serverSubstring)) {
      return l10n?.planHalfDayError ?? 'Bookings here are per half day.';
    }
    return fallback;
  }

  Future<void> _onSeatTap(
    FloorPlan plan,
    Seat seat,
    List<Reservation> reservations,
    DateTime now,
  ) async {
    // Any seat interaction dismisses the calendar-jump ring (#182).
    if (_highlightedSeatId != null) {
      setState(() => _highlightedSeatId = null);
    }
    final l10n = AppLocalizations.of(context);
    // Closed day (#186): no sheet at all — the server would reject any
    // booking touching it (`assert_workspace_open`, migration 0013).
    if (!_isWorkspaceOpenAt(now)) {
      _snack(l10n?.planClosedDay ?? 'Closed on this day');
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
          _snack(l10n?.planSeatBlocked ??
              'This seat is blocked for maintenance.');
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
        final template = state == SeatState.occupied
            ? (l10n?.planOccupiedBy(name) ?? 'Occupied by $name')
            : (l10n?.planReservedBy(name) ?? 'Reserved by $name');
        final until = DateFormat.Hm().format(other.endsAt.toLocal());
        _snack('$template · ${l10n?.planUntil(until) ?? 'until $until'}');
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

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
      _snack(l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.');
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
      _snack(l10n?.planSeatBlocked ??
          'This seat is blocked for maintenance.');
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
    final halfDay = _granularity == BookingGranularity.halfDay;
    var end = walkUp
        ? (halfDay
            ? HalfDayWindows.windowForNow(start).end
            : start.add(_kDefaultStay))
        : (_browseEnd ?? start.add(_kDefaultStay));
    var capped = false;
    if (next != null && next.startsAt.isBefore(end)) {
      end = next.startsAt;
      capped = true;
    }

    final choice = await showModalBottomSheet<_BookingChoice>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CheckInSheet(
        seatId: seat.id,
        seatName: seat.name,
        start: start,
        initialEnd: end,
        cap: next?.startsAt,
        capped: capped,
        walkUp: walkUp,
        fixedEnd: halfDay,
        members: candidates,
        myMemberId: myMember?.id,
        allowSeries: features.contains(WorkspaceFeature.seriesBooking),
        allowBlocking: _canManageSeatBlocks,
      ),
    );
    if (choice == null) return;

    // Not a booking at all: start an open-ended maintenance block (#161).
    if (choice.block) {
      await _setSeatBlock(seat, from: DateTime.now().toUtc());
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
              startsAt: start,
              endsAt: choice.end,
            );
        final who = names[choice.forMemberId] ?? '';
        _snack(l10n?.planBookedForPending(who) ??
            'Sent to $who for confirmation.');
      } else if (choice.pattern == null) {
        await ref.read(reservationRepositoryProvider).create(
              workspaceId: workspace.id,
              seatId: seat.id,
              startsAt: start,
              endsAt: choice.end,
              checkIn: walkUp,
            );
      } else {
        final result = await ref.read(reservationRepositoryProvider).createSeries(
              workspaceId: workspace.id,
              seatId: seat.id,
              firstStart: start,
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
      _snack(_bookingErrorText(
        l10n,
        e,
        l10n?.planCheckInFailed ??
            'Could not check in — the seat may have just been taken.',
      ));
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
                    Text(dateFormat.format(d.toLocal())),
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
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                seat.name.isEmpty ? (l10n?.planYourSeat ?? 'Your seat') : seat.name,
              ),
              subtitle: Text(
                '${DateFormat.Hm().format(mine.startsAt.toLocal())} – '
                '${DateFormat.Hm().format(mine.endsAt.toLocal())}',
              ),
            ),
            if (mine.status == ReservationStatus.checkedIn)
              ListTile(
                leading: const Icon(Icons.logout),
                title: Text(l10n?.planCheckOutButton ?? 'Check out'),
                onTap: () => Navigator.of(context).pop('checkout'),
              )
            else
              ListTile(
                leading: const Icon(Icons.login),
                title: Text(l10n?.planCheckInButton ?? 'Check in'),
                onTap: () => Navigator.of(context).pop('checkin'),
              ),
            ListTile(
              leading: const Icon(Icons.cancel_outlined),
              title: Text(
                l10n?.planCancelReservationButton ?? 'Cancel reservation',
              ),
              onTap: () => Navigator.of(context).pop('cancel'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
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
      _snack(_bookingErrorText(
        l10n,
        e,
        l10n?.workspaceGenericError ??
            'Something went wrong. Please try again.',
      ));
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
      return const Center(child: CircularProgressIndicator());
    }
    if (levels.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n?.planNoLevels ?? 'The workspace has no floor plan yet.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Stored per-workspace default (#159); wait for the one-time read so
    // the plan opens directly on the member's level, no flash of level 1.
    // A failed read falls through to the first level instead of spinning.
    final selectedAsync = ref.watch(selectedLevelIdProvider);
    if (selectedAsync.isLoading && !selectedAsync.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }
    final selectedId = selectedAsync.value;
    final level = levels.where((l) => l.id == selectedId).firstOrNull ??
        levels.first;

    final at = _browse ?? DateTime.now();
    // Browsing (#184): occupancy over the whole [at, windowEnd) frame;
    // null in live mode, where the instant semantics apply.
    final windowEnd = _browseEnd;
    final planAsync = ref.watch(floorPlanProvider(level.id));
    final reservations =
        ref.watch(reservationsForDayProvider(dayKeyOf(at))).value ??
            const <Reservation>[];
    final myMemberId = ref.watch(myMemberProvider).value?.id;
    final names = ref.watch(memberNamesProvider).value ?? const {};

    // Closed day (#186): banner + muted seats + gated taps instead of
    // green "bookable" seats the server would reject. Watched (not the
    // read-based [_isWorkspaceOpenAt]) so the plan reacts to availability
    // edits; unknown while loading counts as open.
    final openWeekdays = ref.watch(openWeekdaysProvider).value;
    final closures = ref.watch(closureDaysProvider).value;
    final dayOpen = openWeekdays == null || closures == null ||
        isWorkspaceOpenOn(at.toLocal(), openWeekdays, closures);

    // Half-day granularity (#201): watched so the header swaps the time
    // chips for the Morning/Afternoon/Day chips once the rule resolves;
    // loading/unknown renders the flexible header (no flash of the wrong
    // affordance — flexible is also the rule's default).
    final granularity = ref.watch(bookingGranularityProvider).value ??
        BookingGranularity.flexible;

    return Column(
      children: [
        _scrollerRow(at, granularity),
        if (!dayOpen) _closedDayBanner(l10n),
        // One tap per level (#159): compact scrollable chips instead of a
        // dropdown; the choice persists as this member's default here.
        if (levels.length > 1)
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final Level l in levels)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(l.name),
                      selected: l.id == level.id,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) {
                        // Deliberate level choice: drop the jump highlight
                        // (#182), then persist as before (#159).
                        setState(() => _highlightedSeatId = null);
                        ref
                            .read(selectedLevelIdProvider.notifier)
                            .select(l.id);
                      },
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: switch (planAsync) {
            AsyncData(value: final plan) => _listView
                ? _seatList(plan, reservations, names, at, dayOpen: dayOpen)
                : _LivePlanCanvas(
                    plan: plan,
                    seatStates: {
                      // Closed day (#186): every seat renders in the
                      // muted blocked state — nothing looks bookable.
                      for (final seat in plan.seats)
                        seat.id: !dayOpen
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
                                  ),
                    },
                    seatLabels: {
                      for (final seat in plan.seats)
                        seat.id:
                            _labelFor(plan, seat, reservations, names, at),
                    },
                    highlightedSeatId: _highlightedSeatId,
                    onSeatTap: (seat) =>
                        _onSeatTap(plan, seat, reservations, at),
                  ),
            AsyncError() => Center(
                child: Text(
                  l10n?.workspaceGenericError ??
                      'Something went wrong. Please try again.',
                ),
              ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ],
    );
  }

  /// The time scroller (spec §6, #184): list/plan toggle · date · from→to
  /// time chips (Material clock dial) · Now. Under half-day granularity
  /// (#201) the two time chips give way to the Morning/Afternoon/Day
  /// choice chips — the only selectable windows there.
  Widget _scrollerRow(DateTime at, BookingGranularity granularity) {
    final l10n = AppLocalizations.of(context);
    final halfDay = granularity == BookingGranularity.halfDay;
    final local = at.toLocal();
    final live = _browse == null;
    final endLocal = (_browseEnd ?? _defaultEndFor(local)).toLocal();
    final timeFormat = DateFormat.Hm();
    // Live mode de-emphasizes the chips: they only preview the window a
    // tap would browse.
    final chipStyle = live
        ? TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
          )
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(_listView ? Icons.map_outlined : Icons.list),
            tooltip: _listView
                ? (l10n?.planMapViewTooltip ?? 'Plan view')
                : (l10n?.planListViewTooltip ?? 'List view'),
            onPressed: () => setState(() => _listView = !_listView),
          ),
          TextButton(
            key: const ValueKey('plan-date-button'),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: local,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked == null) return;
              if (!mounted) return;
              final DateTime from;
              final DateTime end;
              if (halfDay) {
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
                _highlightedSeatId = null;
                _browse = from;
                _browseEnd = end;
              });
            },
            child: Text(DateFormat.MMMd().format(local)),
          ),
          Expanded(
            child: halfDay
                ? _halfDayChips(l10n, local)
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Tooltip(
                        message: l10n?.planFromLabel ?? 'From',
                        child: TextButton(
                          key: const ValueKey('plan-from-chip'),
                          style: chipStyle,
                          onPressed: _pickFrom,
                          child: Text(timeFormat.format(local)),
                        ),
                      ),
                      Icon(
                        Icons.arrow_right_alt,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      Tooltip(
                        message: l10n?.planToLabel ?? 'To',
                        child: TextButton(
                          key: const ValueKey('plan-to-chip'),
                          style: chipStyle,
                          onPressed: _pickTo,
                          child: Text(timeFormat.format(endLocal)),
                        ),
                      ),
                    ],
                  ),
          ),
          TextButton(
            onPressed: live
                ? null
                : () => setState(() {
                      _highlightedSeatId = null;
                      _browse = null;
                      _browseEnd = null;
                    }),
            child: Text(l10n?.planNowButton ?? 'Now'),
          ),
        ],
      ),
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
  Widget _halfDayChips(AppLocalizations? l10n, DateTime local) {
    Widget chip(
      String key,
      String label,
      HalfDayWindow Function(DateTime day) windowOf,
    ) {
      final window = windowOf(local);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: ChoiceChip(
          key: ValueKey(key),
          label: Text(label),
          selected: _browse == window.start && _browseEnd == window.end,
          visualDensity: VisualDensity.compact,
          onSelected: (_) => setState(() {
            // Window change: drop the #182 jump highlight like every
            // other time-scroller interaction.
            _highlightedSeatId = null;
            _browse = window.start;
            _browseEnd = window.end;
          }),
        ),
      );
    }

    // scaleDown keeps the three chips on one row on narrow screens
    // without letting the header scroll horizontally.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          chip(
            'plan-am-chip',
            l10n?.planMorningChip ?? 'Morning',
            HalfDayWindows.morning,
          ),
          chip(
            'plan-pm-chip',
            l10n?.planAfternoonChip ?? 'Afternoon',
            HalfDayWindows.afternoon,
          ),
          chip(
            'plan-day-chip',
            l10n?.planFullDayChip ?? 'Day',
            HalfDayWindows.fullDay,
          ),
        ],
      ),
    );
  }

  /// Closed-day banner under the header row (#186): the workspace is not
  /// open on the browsed/live day (weekday not open or closure day), so
  /// nothing below is bookable.
  Widget _closedDayBanner(AppLocalizations? l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('plan-closed-banner'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          Icon(
            Icons.event_busy,
            size: 18,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n?.planClosedDay ?? 'Closed on this day',
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  /// From-chip tap (#184): clock-dial pick of the window start. Live mode
  /// enters browsing with the picked start and a default-length window;
  /// browse mode moves the start, keeping the duration where the day
  /// allows it.
  Future<void> _pickFrom() async {
    final current = (_browse ?? DateTime.now()).toLocal();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (picked == null) return;
    if (!mounted) return;
    final wasLive = _browse == null;
    final duration =
        wasLive ? _kDefaultStay : _browseEnd!.difference(_browse!);
    final from = _snapToSlot(DateTime(
      current.year,
      current.month,
      current.day,
      picked.hour,
      picked.minute,
    ));
    var end = from.add(duration);
    final last = _lastSlotOf(from);
    if (end.isAfter(last)) end = last;
    if (!end.isAfter(from)) end = from.add(_kTimeSnap);
    setState(() {
      _highlightedSeatId = null;
      _browse = from;
      _browseEnd = end;
    });
  }

  /// To-chip tap (#184): clock-dial pick of the window end. Live mode
  /// enters browsing with the start snapped to "now"; a pick at/before the
  /// start is rejected with a snackbar instead of silently rolling over to
  /// the next day (the booking sheet's own "Until" keeps its roll-over).
  Future<void> _pickTo() async {
    final now = DateTime.now();
    final from = _browse?.toLocal() ?? _snapToSlot(now);
    final currentEnd =
        (_browseEnd ?? _defaultEndFor(_browse ?? now)).toLocal();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(currentEnd),
    );
    if (picked == null) return;
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final end = _snapToSlot(DateTime(
      from.year,
      from.month,
      from.day,
      picked.hour,
      picked.minute,
    ));
    if (!end.isAfter(from)) {
      _snack(l10n?.planEndBeforeStart ?? 'End must be after start.');
      return;
    }
    setState(() {
      _highlightedSeatId = null;
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n?.planNoSeats ?? 'This level has no seats yet.',
            textAlign: TextAlign.center,
          ),
        ),
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
        return ListTile(
          leading: Icon(
            switch (state) {
              SeatState.free => Icons.event_seat_outlined,
              SeatState.blocked => Icons.block,
              _ => Icons.event_seat,
            },
            color: accent,
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

  String _labelFor(
    FloorPlan plan,
    Seat seat,
    List<Reservation> reservations,
    Map<String, String> names,
    DateTime now,
  ) {
    // Browsing (#184): label with whoever overlaps the window.
    final windowEnd = _browseEnd;
    final r = windowEnd == null
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
    if (r == null) return '';
    return _firstName(names[r.memberId] ?? '');
  }
}

class _LivePlanCanvas extends StatelessWidget {
  const _LivePlanCanvas({
    required this.plan,
    required this.seatStates,
    required this.seatLabels,
    required this.onSeatTap,
    this.highlightedSeatId,
  });

  final FloorPlan plan;
  final Map<String, SeatState> seatStates;
  final Map<String, String> seatLabels;
  final ValueChanged<Seat> onSeatTap;

  /// Seat ringed by the painter after a calendar jump (#182).
  final String? highlightedSeatId;

  @override
  Widget build(BuildContext context) {
    const size = Size(120 * _kCellSize, 120 * _kCellSize);
    return InteractiveViewer(
      constrained: false,
      minScale: 0.4,
      maxScale: 3,
      boundaryMargin: const EdgeInsets.all(200),
      child: GestureDetector(
        onTapUp: (details) {
          final x = (details.localPosition.dx / _kCellSize).floor();
          final y = (details.localPosition.dy / _kCellSize).floor();
          final seat = plan.seatAtCell(x, y);
          if (seat != null) onSeatTap(seat);
        },
        child: CustomPaint(
          key: const ValueKey('live-plan-canvas'),
          size: size,
          painter: FloorPlanPainter(
            plan: plan,
            cellSize: _kCellSize,
            colorScheme: Theme.of(context).colorScheme,
            brightness: Theme.of(context).brightness,
            seatStates: seatStates,
            seatLabels: seatLabels,
            highlightedSeatId: highlightedSeatId,
          ),
        ),
      ),
    );
  }
}

/// What the booking sheet returns: end time, an optional recurrence and
/// who the booking is for (null/self = the caller).
class _BookingChoice {
  const _BookingChoice(
    this.end,
    this.pattern,
    this.until,
    this.forMemberId, {
    this.block = false,
  });

  final DateTime end;
  final SeriesPattern? pattern;
  final DateTime? until;
  final String? forMemberId;

  /// True: block the seat for maintenance instead of booking it (#161).
  /// Every other field is ignored then.
  final bool block;
}

class _CheckInSheet extends StatefulWidget {
  const _CheckInSheet({
    required this.seatId,
    required this.seatName,
    required this.start,
    required this.initialEnd,
    required this.cap,
    required this.capped,
    this.walkUp = true,
    this.fixedEnd = false,
    this.members = const [],
    this.myMemberId,
    this.allowSeries = true,
    this.allowBlocking = false,
  });

  final String seatId;
  final String seatName;
  final DateTime start;
  final DateTime initialEnd;
  final DateTime? cap;
  final bool capped;

  /// True: live walk-up (check in now). False: future punctual reservation.
  final bool walkUp;

  /// Half-day granularity (#201): the end is the canonical window's (or
  /// the current half-day boundary for walk-ups) and not adjustable — the
  /// "Until" tile is hidden.
  final bool fixedEnd;

  /// Active members an admin can book for (#106); empty for non-admins
  /// or when the bookForOthers feature is off (#146).
  final List<({String id, String name})> members;
  final String? myMemberId;

  /// Series booking feature gate (#146): false hides the repeat picker.
  final bool allowSeries;

  /// Seat-blocking affordance (#161): true adds "Make not reservable" for
  /// owners and delegated admins.
  final bool allowBlocking;

  @override
  State<_CheckInSheet> createState() => _CheckInSheetState();
}

class _CheckInSheetState extends State<_CheckInSheet> {
  late DateTime _end = widget.initialEnd;
  SeriesPattern? _pattern;
  late DateTime _until = widget.start.add(const Duration(days: 28));
  late String? _forMemberId = widget.myMemberId;

  bool get _forOther =>
      _forMemberId != null && _forMemberId != widget.myMemberId;

  String _patternLabel(AppLocalizations? l10n, SeriesPattern? pattern) {
    return switch (pattern) {
      null => l10n?.repeatNone ?? 'Does not repeat',
      SeriesPattern.daily => l10n?.repeatDaily ?? 'Every day',
      SeriesPattern.weekdays => l10n?.repeatWeekdays ?? 'Every weekday',
      SeriesPattern.weekly => l10n?.repeatWeekly ?? 'Weekly',
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final timeFormat = DateFormat.Hm();
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.seatName.isEmpty
                  ? (l10n?.planCheckInTitle ?? 'Check in')
                  : widget.seatName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              widget.walkUp
                  ? '${l10n?.planStartNow ?? 'Starts now'} · '
                      '${timeFormat.format(widget.start.toLocal())}'
                  : (l10n?.planStartsAt(
                        timeFormat.format(widget.start.toLocal()),
                      ) ??
                      'Starts at '
                          '${timeFormat.format(widget.start.toLocal())}'),
            ),
            // The seat's active accessories (#169): self-loading, renders
            // nothing when the seat has none. Both booking flows (walk-up
            // and browsed-time) share this sheet, so both get the row.
            SeatAccessoryRow(seatId: widget.seatId),
            if (widget.members.length > 1)
              DropdownButtonFormField<String>(
                initialValue: _forMemberId,
                decoration: InputDecoration(
                  labelText: l10n?.planBookForLabel ?? 'Book for',
                ),
                items: [
                  for (final m in widget.members)
                    DropdownMenuItem(value: m.id, child: Text(m.name)),
                ],
                onChanged: (id) => setState(() => _forMemberId = id),
              ),
            // Half-day granularity (#201): the end is fixed to the
            // canonical window boundary — no "Until" affordance.
            if (!widget.fixedEnd)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n?.planUntilLabel ?? 'Until'),
                trailing: Text(timeFormat.format(_end.toLocal())),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(_end.toLocal()),
                  );
                  if (picked == null) return;
                  final local = widget.start.toLocal();
                  var candidate = DateTime(
                    local.year,
                    local.month,
                    local.day,
                    picked.hour,
                    picked.minute,
                  );
                  if (!candidate.isAfter(local)) {
                    candidate = candidate.add(const Duration(days: 1));
                  }
                  var end = candidate;
                  final cap = widget.cap?.toLocal();
                  if (cap != null && end.isAfter(cap)) end = cap;
                  setState(() => _end = end);
                },
              ),
            if (!widget.walkUp && !_forOther && widget.allowSeries) ...[
              DropdownButtonFormField<SeriesPattern?>(
                initialValue: _pattern,
                decoration: InputDecoration(
                  labelText: l10n?.planRepeatLabel ?? 'Repeat',
                ),
                items: [
                  for (final p in [null, ...SeriesPattern.values])
                    DropdownMenuItem(
                      value: p,
                      child: Text(_patternLabel(l10n, p)),
                    ),
                ],
                onChanged: (p) => setState(() => _pattern = p),
              ),
              if (_pattern != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n?.planUntilDateLabel ?? 'Repeat until'),
                  trailing:
                      Text(DateFormat.yMMMd().format(_until.toLocal())),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _until.toLocal(),
                      firstDate: widget.start.toLocal(),
                      lastDate: widget.start
                          .toLocal()
                          .add(const Duration(days: 180)),
                    );
                    if (picked != null) setState(() => _until = picked);
                  },
                ),
            ],
            if (widget.capped && widget.cap != null)
              Text(
                l10n?.planCappedByNext(
                      timeFormat.format(widget.cap!.toLocal()),
                    ) ??
                    'The seat is reserved from '
                        '${timeFormat.format(widget.cap!.toLocal())}.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                _BookingChoice(
                  _end,
                  _forOther ? null : _pattern,
                  _forOther || _pattern == null ? null : _until,
                  _forMemberId,
                ),
              ),
              child: Text(
                _forOther
                    ? (l10n?.planSendForConfirmation ??
                        'Send for confirmation')
                    : widget.walkUp
                        ? (l10n?.planCheckInButton ?? 'Check in')
                        : (l10n?.planReserveButton ?? 'Reserve'),
              ),
            ),
            if (widget.allowBlocking) ...[
              const SizedBox(height: 8),
              // Owner/delegated-admin maintenance block (#161): open-ended,
              // lifted again from the blocked-seat sheet.
              TextButton.icon(
                icon: const Icon(Icons.block),
                label: Text(
                  l10n?.planMakeNotReservable ?? 'Make not reservable',
                ),
                onPressed: () => Navigator.of(context).pop(
                  _BookingChoice(_end, null, null, null, block: true),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
