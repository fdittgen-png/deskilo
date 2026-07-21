// SPDX-License-Identifier: 0BSD
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/theme/seat_state_colors.dart';
import '../../../../core/ui/canvas_controls.dart';
import '../../domain/floor_plan.dart';
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
    required this.seatLabels,
    required this.onSeatTap,
    this.highlightedSeatId,
    this.onlineSeatIds = const {},
    this.deskOpacity = 1,
    this.background,
    this.images = const {},
  });

  /// Key of the [CustomPaint] — the tests' canvas handle
  /// (`live-plan-canvas` / `reserve-plan-canvas`).
  final Key paintKey;

  final FloorPlan plan;
  final Map<String, SeatState> seatStates;
  final Map<String, String> seatLabels;
  final ValueChanged<Seat> onSeatTap;

  /// Seat ringed by the painter after a calendar jump (#182).
  final String? highlightedSeatId;

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

class _PlanCanvasState extends State<PlanCanvas> {
  final _viewTransform = TransformationController();

  @override
  void dispose() {
    _viewTransform.dispose();
    super.dispose();
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
          boundaryMargin:
              const EdgeInsets.all(CanvasControls.defaultBoundaryMargin),
          child: GestureDetector(
            onTapUp: (details) {
              const cell = PlanCanvasMetrics.cellSize;
              final x = (details.localPosition.dx / cell).floor();
              final y = (details.localPosition.dy / cell).floor();
              final seat = widget.plan.seatAtCell(x, y);
              if (seat != null) widget.onSeatTap(seat);
            },
            child: CustomPaint(
              key: widget.paintKey,
              size: PlanCanvasMetrics.size,
              painter: FloorPlanPainter(
                plan: widget.plan,
                cellSize: PlanCanvasMetrics.cellSize,
                colorScheme: Theme.of(context).colorScheme,
                brightness: Theme.of(context).brightness,
                seatStates: widget.seatStates,
                seatLabels: widget.seatLabels,
                highlightedSeatId: widget.highlightedSeatId,
                onlineSeatIds: widget.onlineSeatIds,
                deskOpacity: widget.deskOpacity,
                background: widget.background,
                images: widget.images,
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
