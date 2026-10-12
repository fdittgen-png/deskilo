// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/files/file_picker.dart';
import '../../../../core/ids/request_id.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/canvas_controls.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../plan/domain/desk.dart';
import '../../../plan/domain/floor_plan.dart';
import '../../../plan/domain/floor_plan_editing.dart';
import '../../../plan/domain/floor_plan_rules.dart';
import '../../../plan/domain/grid_geometry.dart';
import '../../../plan/domain/office.dart';
import '../../../plan/domain/seat.dart';
import '../../../plan/presentation/widgets/floor_plan_painter.dart';
import '../../../plan/presentation/widgets/plan_canvas.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../delete_confirm_text.dart';
import '../plan_media_write.dart';
import '../widgets/editor_selection_bar.dart';
import '../widgets/editor_tool_hint.dart';
import '../widgets/editor_toolbar.dart';
import '../widgets/placement_problem.dart';
import '../widgets/seat_properties_sheet.dart';
import '../widgets/space_properties_sheet.dart';
import '../widgets/text_prompt_dialog.dart';
import 'editor_tool.dart';

part 'level_canvas_screen_part1.dart';
part 'level_canvas_screen_part2.dart';

/// Canvas dimensions in grid cells and the logical cell size at scale 1 —
/// aliases of the shared [PlanCanvasMetrics] so the editor can never drift
/// from the live plan / Reserve hub geometry.
@visibleForTesting
abstract final class GridCanvas {
  static const int widthCells = PlanCanvasMetrics.cells;
  static const int heightCells = PlanCanvasMetrics.cells;
  static const double cellSize = PlanCanvasMetrics.cellSize;
}

/// Draw offices and desks on a level's grid (spec §10). Pan/zoom with the
/// select tool; drawing tools take over the drag gesture.
class LevelCanvasScreen extends ConsumerStatefulWidget {
  const LevelCanvasScreen({required this.levelId, super.key});

  final String levelId;

  @override
  ConsumerState<LevelCanvasScreen> createState() => _LevelCanvasScreenState();
}

class _LevelCanvasScreenState extends ConsumerState<LevelCanvasScreen> {
  /// The armed tool, or null — the resting state, where a tap selects
  /// and a drag pans (#1216). Select stopped being a tool the day the
  /// six-segment row no longer fitted and Select was one of the two
  /// that fell off the end.
  EditorTool? _tool;

  /// #2012 C — a plan-media write is in flight (progress; no second one).
  final _mediaBusy = ValueNotifier(false);
  ({int x, int y})? _dragStart;
  GridRect? _marquee;
  bool _marqueeValid = true;

  // Move/resize state (#101): tap selects, drag inside moves, drag on an
  // edge/corner resizes; the draft plan previews the change live.
  ElementKind? _selectedKind;
  String? _selectedId;
  FloorPlan? _draft;
  bool _draftValid = true;
  ResizeEdges? _dragEdges;

  // Owned by the State so the pan/zoom survives every plan refetch. Each edit
  // (delete/place/move) invalidates floorPlanProvider, which drops its value
  // (AsyncLoading, hasValue=false) while it re-fetches; without a persistent
  // controller the InteractiveViewer would remount with an identity transform
  // and the view would jump back to the origin, so the next tap landed on the
  // wrong cell (only the first delete appeared to work).
  final TransformationController _viewTransform = TransformationController();

  /// The last successfully fetched plan — rendered through a reload so the
  /// canvas never tears down to a spinner mid-edit (see [_viewTransform]).
  FloorPlan? _lastPlan;

  @override
  void dispose() {
    _viewTransform.dispose();
    _mediaBusy.dispose();
    super.dispose();
  }

  ({int x, int y}) _cellAt(Offset position) {
    final x = (position.dx / GridCanvas.cellSize)
        .floor()
        .clamp(0, GridCanvas.widthCells - 1);
    final y = (position.dy / GridCanvas.cellSize)
        .floor()
        .clamp(0, GridCanvas.heightCells - 1);
    return (x: x, y: y);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final planAsync = ref.watch(floorPlanProvider(widget.levelId));
    // Cache the freshest plan and render it through a reload — ref.invalidate
    // drops the provider's value on every edit, so its own value is null then.
    if (planAsync.value != null) _lastPlan = planAsync.value;
    final shownPlan = planAsync.value ?? _lastPlan;
    final levelName = ref
            .watch(levelsProvider)
            .value
            ?.where((l) => l.id == widget.levelId)
            .firstOrNull
            ?.name ??
        '';

    final selected =
        shownPlan == null ? null : _selectedElement(shownPlan);

    return Scaffold(
      appBar: AppBar(
        title: Text(levelName),

        actions: [
          Builder(
            builder: (context) {
              final level = ref
                  .watch(levelsProvider)
                  .value
                  ?.where((l) => l.id == widget.levelId)
                  .firstOrNull;
              final hasBg = level?.hasBackground ?? false;
              return PopupMenuButton<String>(
                key: const ValueKey('level-canvas-editor-background-image'),
                icon: const Icon(Icons.image_outlined),
                tooltip: l10n.editorBackgroundImage,
                onSelected: (v) {
                  if (v == 'set') {
                    unawaited(_pickBackground(context));
                  } else {
                    unawaited(_removeBackground(context));
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'set',
                    child: Text(
                      hasBg
                          ? (l10n.editorBackgroundReplace)
                          : (l10n.editorBackgroundSet),
                    ),
                  ),
                  if (hasBg)
                    PopupMenuItem(
                      value: 'remove',
                      child: Text(
                        l10n.editorBackgroundRemove,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      // #1216 — the bar answers whichever question the canvas is in the
      // middle of: what can I add, or what can I do to this thing. Never
      // both at once, because there is nothing to add TO a selection.
      bottomNavigationBar: selected != null
          ? EditorSelectionBar(
              kind: selected.kind,
              name: selected.name,
              onEdit: selected.kind == ElementKind.image
                  ? null
                  : () => _editSelection(shownPlan!),
              onDuplicate: selected.kind == ElementKind.seat
                  ? () => _duplicateSeat(shownPlan!)
                  : null,
              onDelete: () => _deleteSelection(shownPlan!),
              onDismiss: _clearSelection,
            )
          : EditorToolbar(
              armed: _tool,
              onArm: (tool) {
                _clearSelection();
                setState(() => _tool = tool);
              },
            ),
      // Keep the canvas mounted whenever we have ANY plan to show — the last
      // fetched one during a reload. Matching only AsyncData here swapped in a
      // spinner and tore down the InteractiveViewer on every delete, resetting
      // its pan/zoom so the next tap missed. LoadingView shows only before the
      // first plan; the error screen only when nothing else is available.
      body: shownPlan != null
          // #2012 C — the progress bar overlays the canvas: no height of
          // its own, so 2× text keeps the layout it had.
          ? Stack(children: [
              Positioned.fill(child: _buildCanvas(shownPlan)),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ValueListenableBuilder<bool>(
                  valueListenable: _mediaBusy,
                  builder: (_, busy, _) => busy
                      ? LinearProgressIndicator(
                          key: const ValueKey('plan-media-progress'),
                          semanticsLabel:
                              l10n.editorMediaSaving)
                      : const SizedBox.shrink(),
                ),
              ),
            ])
          : switch (planAsync) {
              AsyncError() => Center(
                  child: Text(
                    l10n.workspaceGenericError,
                  ),
                ),
              _ => const LoadingView(),
            },
    );
  }

  /// The selected element's kind and its own name, for the bar that
  /// acts on it (#1216). Null when nothing is selected — which is also
  /// what says "show the tools instead".
  ({ElementKind kind, String name})? _selectedElement(FloorPlan plan) {
    final id = _selectedId;
    final l10n = context.l10n;
    return switch (_selectedKind) {
      ElementKind.office => plan.offices
          .where((o) => o.id == id)
          .map((o) => (kind: ElementKind.office, name: o.name))
          .firstOrNull,
      ElementKind.desk => plan.desks
          .where((d) => d.id == id)
          .map((d) => (kind: ElementKind.desk, name: d.name))
          .firstOrNull,
      ElementKind.seat => plan.seats
          .where((s) => s.id == id)
          .map((s) => (kind: ElementKind.seat, name: s.name))
          .firstOrNull,
      // An image has no name of its own, so the bar says what it is.
      ElementKind.image => plan.images.any((i) => i.id == id)
          ? (
              kind: ElementKind.image,
              name: l10n.editorToolImage,
            )
          : null,
      null => null,
    };
  }

  /// Lets the section extensions rebuild (setState is protected).
  void _update(VoidCallback fn) => setState(fn);

}
