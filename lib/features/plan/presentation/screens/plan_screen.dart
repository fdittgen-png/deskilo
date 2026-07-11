// SPDX-License-Identifier: MIT
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/seat_state_colors.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/providers/event_providers.dart';
import '../../../reservations/domain/reservation.dart';
import '../../../reservations/domain/reservation_repository.dart';
import '../../../reservations/domain/seat_state_logic.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../../workspace/domain/member.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/floor_plan.dart';
import '../../domain/level.dart';
import '../../domain/seat.dart';
import '../../domain/seat_block_policy.dart';
import '../../providers/default_level_controller.dart';
import '../../providers/floor_plan_providers.dart';
import '../widgets/floor_plan_painter.dart';

/// Cell size of the live plan (denser than the editor).
const double _kCellSize = 14;

/// Default walk-up duration when nothing caps it earlier (spec §4.2;
/// becomes a workspace setting with the Epic-#5 rules engine).
const Duration _kDefaultStay = Duration(hours: 4);

/// Live floor plan: seat states now, walk-up check-in, check-out (spec §4).
class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  Timer? _minuteTick;

  /// Time-scroller state (spec §6): null = live "now" mode; otherwise the
  /// browsed instant whose occupancy is rendered.
  DateTime? _browse;
  bool _listView = false;

  @override
  void initState() {
    super.initState();
    // Re-evaluate seat states as time passes.
    _minuteTick = Timer.periodic(
      const Duration(minutes: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _minuteTick?.cancel();
    super.dispose();
  }

  String _firstName(String name) =>
      name.split(' ').firstOrNull ?? name;

  Future<void> _onSeatTap(
    FloorPlan plan,
    Seat seat,
    List<Reservation> reservations,
    DateTime now,
  ) async {
    final l10n = AppLocalizations.of(context);
    final myMemberId = ref.read(myMemberProvider).value?.id;
    final state = seatStateAt(
      plan: plan,
      seat: seat,
      reservations: reservations,
      myMemberId: myMemberId,
      at: now,
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
        final mine = reservationOnSeatAt(
          plan: plan,
          seat: seat,
          reservations: reservations,
          at: now,
        );
        if (mine != null) await _mySeatSheet(seat, mine);
      case SeatState.reserved:
      case SeatState.occupied:
        final other = reservationOnSeatAt(
          plan: plan,
          seat: seat,
          reservations: reservations,
          at: now,
        );
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
  /// reservation starting at the browsed instant (spec §5.1).
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
    var end = start.add(_kDefaultStay);
    var capped = false;
    if (next != null && next.startsAt.isBefore(end)) {
      end = next.startsAt;
      capped = true;
    }

    final choice = await showModalBottomSheet<_BookingChoice>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CheckInSheet(
        seatName: seat.name,
        start: start,
        initialEnd: end,
        cap: next?.startsAt,
        capped: capped,
        walkUp: walkUp,
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
      _snack(l10n?.planCheckInFailed ??
          'Could not check in — the seat may have just been taken.');
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
    switch (action) {
      case 'checkout':
        await repo.checkOut(mine.id);
      case 'checkin':
        await repo.checkIn(mine.id);
      case 'cancel':
        await repo.cancel(mine.id);
    }
    invalidateBookingData(ref);
  }

  @override
  Widget build(BuildContext context) {
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
    final planAsync = ref.watch(floorPlanProvider(level.id));
    final reservations =
        ref.watch(reservationsForDayProvider(dayKeyOf(at))).value ??
            const <Reservation>[];
    final myMemberId = ref.watch(myMemberProvider).value?.id;
    final names = ref.watch(memberNamesProvider).value ?? const {};

    return Column(
      children: [
        _scrollerRow(at),
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
                      onSelected: (_) => ref
                          .read(selectedLevelIdProvider.notifier)
                          .select(l.id),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: switch (planAsync) {
            AsyncData(value: final plan) => _listView
                ? _seatList(plan, reservations, names, at)
                : _LivePlanCanvas(
                    plan: plan,
                    seatStates: {
                      for (final seat in plan.seats)
                        seat.id: seatStateAt(
                          plan: plan,
                          seat: seat,
                          reservations: reservations,
                          myMemberId: myMemberId,
                          at: at,
                        ),
                    },
                    seatLabels: {
                      for (final seat in plan.seats)
                        seat.id:
                            _labelFor(plan, seat, reservations, names, at),
                    },
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

  /// The time scroller (spec §6): list/plan toggle · date · time-of-day
  /// slider · Now.
  Widget _scrollerRow(DateTime at) {
    final l10n = AppLocalizations.of(context);
    final local = at.toLocal();
    final minutes = local.hour * 60 + local.minute;
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
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: local,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked == null) return;
              setState(() {
                _browse = DateTime(
                  picked.year,
                  picked.month,
                  picked.day,
                  local.hour,
                  local.minute,
                );
              });
            },
            child: Text(DateFormat.MMMd().format(local)),
          ),
          Expanded(
            child: Slider(
              value: minutes.toDouble(),
              max: 24 * 60 - 15,
              divisions: 24 * 4 - 1,
              label: DateFormat.Hm().format(local),
              onChanged: (value) {
                final m = (value ~/ 15) * 15;
                setState(() {
                  _browse = DateTime(
                    local.year,
                    local.month,
                    local.day,
                    m ~/ 60,
                    m % 60,
                  );
                });
              },
            ),
          ),
          TextButton(
            onPressed:
                _browse == null ? null : () => setState(() => _browse = null),
            child: Text(l10n?.planNowButton ?? 'Now'),
          ),
        ],
      ),
    );
  }

  /// Chronological reservations of the browsed day (spec §6 list view).
  /// #104: the list view mirrors the plan — every seat of the level with
  /// its state at the browsed instant, tappable exactly like the canvas.
  Widget _seatList(
    FloorPlan plan,
    List<Reservation> reservations,
    Map<String, String> names,
    DateTime at,
  ) {
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
        final state = seatStateAt(
          plan: plan,
          seat: seat,
          reservations: reservations,
          myMemberId: myMemberId,
          at: at,
        );
        final covering = reservationOnSeatAt(
          plan: plan,
          seat: seat,
          reservations: reservations,
          at: at,
        );
        final until = covering == null
            ? null
            : timeFormat.format(covering.endsAt.toLocal());
        final who = covering == null
            ? ''
            : (names[covering.memberId] ?? '');
        final stateText = switch (state) {
          SeatState.free => l10n?.planStateFree ?? 'Free',
          SeatState.blocked =>
            l10n?.planSeatBlocked ?? 'This seat is blocked for maintenance.',
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
    final r = reservationOnSeatAt(
      plan: plan,
      seat: seat,
      reservations: reservations,
      at: now,
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
  });

  final FloorPlan plan;
  final Map<String, SeatState> seatStates;
  final Map<String, String> seatLabels;
  final ValueChanged<Seat> onSeatTap;

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
    required this.seatName,
    required this.start,
    required this.initialEnd,
    required this.cap,
    required this.capped,
    this.walkUp = true,
    this.members = const [],
    this.myMemberId,
    this.allowSeries = true,
    this.allowBlocking = false,
  });

  final String seatName;
  final DateTime start;
  final DateTime initialEnd;
  final DateTime? cap;
  final bool capped;

  /// True: live walk-up (check in now). False: future punctual reservation.
  final bool walkUp;

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
