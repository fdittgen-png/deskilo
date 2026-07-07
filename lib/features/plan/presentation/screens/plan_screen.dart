// SPDX-License-Identifier: MIT
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../reservations/domain/reservation.dart';
import '../../../reservations/domain/seat_state_logic.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/floor_plan.dart';
import '../../domain/level.dart';
import '../../domain/seat.dart';
import '../../providers/floor_plan_providers.dart';
import '../widgets/floor_plan_painter.dart';

part 'plan_screen.g.dart';

/// The level shown on the Plan tab (defaults to the first level).
@Riverpod(keepAlive: true)
class SelectedLevelId extends _$SelectedLevelId {
  @override
  String? build() => null;

  void select(String id) => state = id;
}

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
        _snack(l10n?.planSeatBlocked ??
            'This seat is blocked for maintenance.');
      case SeatState.free:
        await _checkInSheet(plan, seat, reservations, now);
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

  Future<void> _checkInSheet(
    FloorPlan plan,
    Seat seat,
    List<Reservation> reservations,
    DateTime now,
  ) async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;

    final next =
        nextReservationOnSeat(seat: seat, reservations: reservations, at: now);
    var end = now.add(_kDefaultStay);
    var capped = false;
    if (next != null && next.startsAt.isBefore(end)) {
      end = next.startsAt;
      capped = true;
    }

    final confirmedEnd = await showModalBottomSheet<DateTime>(
      context: context,
      builder: (context) => _CheckInSheet(
        seatName: seat.name,
        start: now,
        initialEnd: end,
        cap: next?.startsAt,
        capped: capped,
      ),
    );
    if (confirmedEnd == null) return;

    try {
      await ref.read(reservationRepositoryProvider).create(
            workspaceId: workspace.id,
            seatId: seat.id,
            startsAt: now,
            endsAt: confirmedEnd,
            checkIn: true,
          );
    } catch (e, st) {
      debugPrint('walk-up check-in failed: $e\n$st');
      if (!mounted) return;
      _snack(l10n?.planCheckInFailed ??
          'Could not check in — the seat may have just been taken.');
      return;
    }
    ref.invalidate(reservationsForDayProvider);
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
    ref.invalidate(reservationsForDayProvider);
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

    final selectedId = ref.watch(selectedLevelIdProvider);
    final level = levels.where((l) => l.id == selectedId).firstOrNull ??
        levels.first;

    final now = DateTime.now();
    final planAsync = ref.watch(floorPlanProvider(level.id));
    final reservations =
        ref.watch(reservationsForDayProvider(dayKeyOf(now))).value ??
            const <Reservation>[];
    final myMemberId = ref.watch(myMemberProvider).value?.id;
    final names = ref.watch(memberNamesProvider).value ?? const {};

    return Column(
      children: [
        if (levels.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(l10n?.planLevelLabel ?? 'Level'),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<String>(
                    value: level.id,
                    isExpanded: true,
                    items: [
                      for (final Level l in levels)
                        DropdownMenuItem(value: l.id, child: Text(l.name)),
                    ],
                    onChanged: (id) {
                      if (id != null) {
                        ref.read(selectedLevelIdProvider.notifier).select(id);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: switch (planAsync) {
            AsyncData(value: final plan) => _LivePlanCanvas(
                plan: plan,
                seatStates: {
                  for (final seat in plan.seats)
                    seat.id: seatStateAt(
                      plan: plan,
                      seat: seat,
                      reservations: reservations,
                      myMemberId: myMemberId,
                      at: now,
                    ),
                },
                seatLabels: {
                  for (final seat in plan.seats)
                    seat.id: _labelFor(plan, seat, reservations, names, now),
                },
                onSeatTap: (seat) =>
                    _onSeatTap(plan, seat, reservations, now),
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

class _CheckInSheet extends StatefulWidget {
  const _CheckInSheet({
    required this.seatName,
    required this.start,
    required this.initialEnd,
    required this.cap,
    required this.capped,
  });

  final String seatName;
  final DateTime start;
  final DateTime initialEnd;
  final DateTime? cap;
  final bool capped;

  @override
  State<_CheckInSheet> createState() => _CheckInSheetState();
}

class _CheckInSheetState extends State<_CheckInSheet> {
  late DateTime _end = widget.initialEnd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final timeFormat = DateFormat.Hm();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
              '${l10n?.planStartNow ?? 'Starts now'} · '
              '${timeFormat.format(widget.start.toLocal())}',
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
              onPressed: () => Navigator.of(context).pop(_end),
              child: Text(l10n?.planCheckInButton ?? 'Check in'),
            ),
          ],
        ),
      ),
    );
  }
}
