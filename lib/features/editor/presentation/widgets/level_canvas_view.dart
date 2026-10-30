// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/canvas_controls.dart';
import '../../../plan/domain/floor_plan.dart';
import '../../../plan/domain/grid_geometry.dart';
import '../../../plan/presentation/widgets/floor_plan_painter.dart';
import '../../../plan/presentation/widgets/plan_canvas.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../../workspace/providers/workspace_providers.dart';

/// What the canvas draws over the plan: the marquee being dragged, the
/// selection's outline, and where the armed tool may drop.
typedef CanvasOverlay = ({
  GridRect? marquee,
  bool marqueeValid,
  GridRect? selection,
  bool selectionResizable,
  bool selectionValid,
  Set<String>? dropTargets,
});

/// The gestures the canvas hands back to the screen. [owned] is true
/// while a tool draws or a selection moves: the drag is theirs, so the
/// viewport neither pans nor zooms.
typedef CanvasGestures = ({
  bool owned,
  GestureTapUpCallback onTapUp,
  GestureDragStartCallback? onPanStart,
  GestureDragUpdateCallback? onPanUpdate,
  GestureDragEndCallback? onPanEnd,
});

/// The level's drawing surface: the pan/zoom viewer, the gestures and
/// the painted plan with its background, images and overlay.
class LevelCanvasView extends ConsumerWidget {
  const LevelCanvasView({
    required this.levelId,
    required this.plan,
    required this.overlay,
    required this.controller,
    required this.gestures,
    super.key,
  });

  final String levelId;

  /// The plan as shown: the drag's draft while one is in progress.
  final FloorPlan plan;
  final CanvasOverlay overlay;

  /// Owned by the screen so the pan/zoom survives every plan refetch.
  final TransformationController controller;
  final CanvasGestures gestures;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    const size = Size(
      PlanCanvasMetrics.cells * PlanCanvasMetrics.cellSize,
      PlanCanvasMetrics.cells * PlanCanvasMetrics.cellSize,
    );
    return InteractiveViewer(
      transformationController: controller,
      constrained: false,
      minScale: CanvasControls.defaultMinScale,
      maxScale: CanvasControls.defaultMaxScale,
      panEnabled: !gestures.owned,
      scaleEnabled: !gestures.owned,
      // UNBOUNDED pan — the same fit-vs-clamp fight as the live plan
      // (see plan_canvas.dart): a centred small level must stay legal.
      boundaryMargin: const EdgeInsets.all(double.infinity),
      child: Semantics(
        // #1235 — the drawing surface used to reach a screen reader as
        // an anonymous button the size of the floor: a tap action with
        // no name, and a coordinate nobody navigating by voice can aim
        // at. It is a canvas, so it says so, and the objects on it are
        // reached through the objects panel instead.
        label: l10n.editorCanvasSemantics,
        child: GestureDetector(
          excludeFromSemantics: true,
          // `down` so onPanStart reports the touch-down cell, not the
          // position where the drag cleared the touch slop.
          dragStartBehavior: DragStartBehavior.down,
          onTapUp: gestures.onTapUp,
          onPanStart: gestures.onPanStart,
          onPanUpdate: gestures.onPanUpdate,
          onPanEnd: gestures.onPanEnd,
          child: CustomPaint(
            key: const ValueKey('level-canvas'),
            size: size,
            painter: FloorPlanPainter(
              background: ref.watch(levelBackgroundProvider(levelId)).value,
              images: {
                for (final image in plan.images)
                  if (image.kind == null &&
                      ref.watch(planImageProvider(image.id)).value != null)
                    image.id: ref.watch(planImageProvider(image.id)).value!,
              },
              plan: plan,
              cellSize: PlanCanvasMetrics.cellSize,
              colorScheme: Theme.of(context).colorScheme,
              deskOpacity:
                  (ref.watch(currentWorkspaceProvider).value?.deskOpacity ??
                      100) /
                  100,
              marquee: overlay.marquee,
              marqueeValid: overlay.marqueeValid,
              selection: overlay.selection,
              selectionResizable: overlay.selectionResizable,
              selectionValid: overlay.selectionValid,
              dropTargets: overlay.dropTargets,
            ),
          ),
        ),
      ),
    );
  }
}
