// SPDX-License-Identifier: 0BSD
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/seat_state_colors.dart';
import '../../../../core/ui/canvas_controls.dart';
import '../../domain/desk.dart';
import '../../domain/floor_plan.dart';
import '../../domain/office.dart';
import '../../domain/seat.dart';
import 'floor_plan_painter.dart';

/// Geometry of the read-only plan canvases — ONE source of truth for the
/// numbers plan_screen, reserve_screen and the editor used to re-declare
/// ("matches the live plan's"). The zoom limits and pan margin live on
/// [CanvasControls] (its defaults) so the buttons and the viewer can never
/// drift apart.
abstract final class PlanCanvasMetrics {
  /// Cell size of the live plan in px (denser than print).
  static const double cellSize = 14;

  /// Grid cells per canvas side.
  static const int cells = 120;

  /// The unscaled canvas size.
  static const Size size = Size(cells * cellSize, cells * cellSize);
}

/// The shared read-only floor-plan canvas: [FloorPlanPainter] inside an
/// [InteractiveViewer] with cell-resolved seat taps and the [CanvasControls]
/// overlay (zoom buttons, scrollbars, auto-fit to the plan's used bounds).
///
/// Used by the Plan tab and the Reserve hub — formerly two mirrored private
/// classes (`_LivePlanCanvas` / `_ReservePlanCanvas`). The only per-surface
/// differences are [paintKey] (pinned by tests) and whether a
/// [highlightedSeatId] ring is shown (calendar jump, Plan tab only).
class PlanCanvas extends StatefulWidget {
  const PlanCanvas({
    super.key,
    required this.paintKey,
    required this.plan,
    required this.seatStates,
    this.seatDayPhases = const {},
    required this.seatLabels,
    required this.onSeatTap,
    this.onSpaceDoubleTap,
    this.highlightedSeatId,
    this.highlightedDeskId,
    this.highlightedOfficeId,
    this.highlightLevel = false,
    this.onlineSeatIds = const {},
    this.deskOpacity = 1,
    this.spaceOverlays = const {},
    this.background,
    this.images = const {},
  });

  /// Key of the [CustomPaint] — the tests' canvas handle
  /// (`live-plan-canvas` / `reserve-plan-canvas`).
  final Key paintKey;

  final FloorPlan plan;
  final Map<String, SeatState> seatStates;

  /// The browsed day's per-seat phase rings (#575).
  final Map<String, SeatDayPhase> seatDayPhases;
  final Map<String, String> seatLabels;

  /// Whole-space overlays (#462) — see [FloorPlanPainter.spaceOverlays].
  final Map<String, ({SeatState state, String label})> spaceOverlays;
  final ValueChanged<Seat> onSeatTap;

  /// Double tap = whole-space intent (field request): the resolved desk
  /// and office under the tapped cell — both null means the open floor
  /// (the level). Null disables the double-tap recognizer entirely, so
  /// surfaces without whole-space booking keep instant single taps
  /// (a registered double-tap recognizer delays them by design).
  final void Function(Desk? desk, Office? office)? onSpaceDoubleTap;

  /// Seat ringed by the painter after a calendar jump (#182).
  final String? highlightedSeatId;

  /// #576 — space highlight passthrough (table / office / whole floor).
  final String? highlightedDeskId;
  final String? highlightedOfficeId;
  final bool highlightLevel;

  /// Seats whose occupant is online (presence dot).
  final Set<String> onlineSeatIds;

  /// Desk fill opacity 0..1 (0040).
  final double deskOpacity;

  /// Level background image (0036), painted behind the grid.
  final ui.Image? background;

  /// Illustration images (0037): id → decoded bitmap.
  final Map<String, ui.Image> images;

  @override
  State<PlanCanvas> createState() => _PlanCanvasState();
}

class _PlanCanvasState extends State<PlanCanvas>
    with SingleTickerProviderStateMixin {
  final _viewTransform = TransformationController();

  /// #611 — drives the seat state-colour lerp. Rests at 1 (the final
  /// colours); a detected state diff restarts it from 0, so it only
  /// ever ticks briefly after an actual change.
  late final AnimationController _stateFade = AnimationController(
    vsync: this,
    value: 1,
    duration: MotionTokens.standard,
  );

  /// The pre-change states of ONLY the seats whose state just changed —
  /// the painter lerps these toward the current map.
  Map<String, SeatState>? _previousSeatStates;

  @override
  void didUpdateWidget(PlanCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.seatStates, widget.seatStates)) return;
    // Diff bound to seats present in BOTH maps: a level switch swaps the
    // whole id set and must not animate anything.
    final changed = <String, SeatState>{
      for (final entry in oldWidget.seatStates.entries)
        if (widget.seatStates.containsKey(entry.key) &&
            widget.seatStates[entry.key] != entry.value)
          entry.key: entry.value,
    };
    if (changed.isEmpty) return;
    final duration = motionDuration(context, MotionTokens.standard);
    if (duration == Duration.zero) {
      _previousSeatStates = null;
      _stateFade.value = 1;
      return;
    }
    _previousSeatStates = changed;
    _stateFade.duration = duration;
    _stateFade.forward(from: 0);
  }

  @override
  void dispose() {
    _stateFade.dispose();
    _viewTransform.dispose();
    super.dispose();
  }

  /// "A1 · occupied — Ana": name, localized state, occupant when shown.
  /// Composed here because the painter has no l10n (#402).
  Map<String, String> _semanticLabels(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String stateName(SeatState? state) => switch (state) {
          SeatState.reserved => l10n?.a11ySeatReserved ?? 'reserved',
          SeatState.occupied => l10n?.a11ySeatOccupied ?? 'occupied',
          SeatState.mine => l10n?.a11ySeatMine ?? 'your seat',
          SeatState.blocked => l10n?.a11ySeatBlocked ?? 'not available',
          SeatState.free || null => l10n?.a11ySeatFree ?? 'free',
        };
    return {
      for (final seat in widget.plan.seats)
        seat.id: [
          seat.name,
          stateName(widget.seatStates[seat.id]),
          if ((widget.seatLabels[seat.id] ?? '').isNotEmpty)
            widget.seatLabels[seat.id]!,
        ].join(' · '),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        InteractiveViewer(
          transformationController: _viewTransform,
          constrained: false,
          minScale: CanvasControls.defaultMinScale,
          maxScale: CanvasControls.defaultMaxScale,
          // UNBOUNDED pan (field report): the auto-fit centres a SMALL
          // level by translating beyond any finite margin — the first
          // finger-pan then made InteractiveViewer clamp the transform,
          // snapping the plan to the left edge and locking horizontal
          // movement. Fit, reset and the scrollbars keep the user
          // oriented; the viewer must never fight the fit.
          boundaryMargin: const EdgeInsets.all(double.infinity),
          child: GestureDetector(
            onTapUp: (details) {
              const cell = PlanCanvasMetrics.cellSize;
              final x = (details.localPosition.dx / cell).floor();
              final y = (details.localPosition.dy / cell).floor();
              final seat = widget.plan.seatAtCell(x, y);
              if (seat != null) widget.onSeatTap(seat);
            },
            onDoubleTapDown: widget.onSpaceDoubleTap == null
                ? null
                : (details) {
                    const cell = PlanCanvasMetrics.cellSize;
                    final x = (details.localPosition.dx / cell).floor();
                    final y = (details.localPosition.dy / cell).floor();
                    widget.onSpaceDoubleTap!(
                      widget.plan.deskAtCell(x, y),
                      widget.plan.officeAtCell(x, y),
                    );
                  },
            // The down handler carries the position; this registers the
            // recognizer.
            onDoubleTap: widget.onSpaceDoubleTap == null ? null : () {},
            // #611 — the AnimatedBuilder only re-renders while the
            // brief state-colour lerp runs; at rest it costs nothing.
            child: AnimatedBuilder(
              animation: _stateFade,
              builder: (context, _) => CustomPaint(
              key: widget.paintKey,
              size: PlanCanvasMetrics.size,
              painter: FloorPlanPainter(
                plan: widget.plan,
                cellSize: PlanCanvasMetrics.cellSize,
                colorScheme: Theme.of(context).colorScheme,
                brightness: Theme.of(context).brightness,
                seatStates: widget.seatStates,
                previousSeatStates: _previousSeatStates,
                seatStateLerp:
                    MotionTokens.ease.transform(_stateFade.value),
                seatDayPhases: widget.seatDayPhases,
                seatLabels: widget.seatLabels,
                spaceOverlays: widget.spaceOverlays,
                semanticLabels: _semanticLabels(context),
                semanticsDirection: Directionality.of(context),
                onSeatSemanticTap: widget.onSeatTap,
                highlightedSeatId: widget.highlightedSeatId,
                highlightedDeskId: widget.highlightedDeskId,
                highlightedOfficeId: widget.highlightedOfficeId,
                highlightLevel: widget.highlightLevel,
                onlineSeatIds: widget.onlineSeatIds,
                deskOpacity: widget.deskOpacity,
                background: widget.background,
                images: widget.images,
              ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: CanvasControls(
            controller: _viewTransform,
            contentSize: PlanCanvasMetrics.size,
            fitBounds: fitRectFromCells(
              widget.plan.usedBounds,
              PlanCanvasMetrics.cellSize,
            ),
            fitKey: widget.plan.levelId,
          ),
        ),
      ],
    );
  }
}
