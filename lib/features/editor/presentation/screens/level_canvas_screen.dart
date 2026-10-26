// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/canvas_controls.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../plan/domain/floor_plan.dart';
import '../../../plan/domain/floor_plan_editing.dart';
import '../../../plan/domain/grid_geometry.dart';
import '../../../plan/presentation/widgets/plan_canvas.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../application/level_canvas_edits.dart';
import '../../application/level_canvas_rules.dart';
import '../../domain/editor_tool.dart';
import '../delete_confirm_text.dart';
import '../level_canvas_flows.dart';
import '../widgets/editor_empty_floor.dart';
import '../widgets/editor_selection_bar.dart';
import '../widgets/editor_tool_hint.dart';
import '../widgets/editor_toolbar.dart';
import '../widgets/erase_confirm_dialog.dart';
import '../widgets/level_background_menu.dart';
import '../widgets/level_canvas_view.dart';
import '../widgets/placement_problem.dart';

/// Canvas dimensions in grid cells and the logical cell size at scale 1 —
/// aliases of the shared [PlanCanvasMetrics] so the editor can never drift
/// from the live plan / Reserve hub geometry.
@visibleForTesting
abstract final class GridCanvas {
  static const int widthCells = PlanCanvasMetrics.cells;
  static const int heightCells = PlanCanvasMetrics.cells;
  static const double cellSize = PlanCanvasMetrics.cellSize;
}

const CanvasGrid _grid = CanvasGrid(
  cells: PlanCanvasMetrics.cells,
  cellSize: PlanCanvasMetrics.cellSize,
);

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
  CanvasCell? _dragStart;
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

  CanvasCell _cellAt(Offset position) =>
      _grid.cellAt(position.dx, position.dy);

  LevelCanvasEdits get _edits => LevelCanvasEdits(
      ref.read(floorPlanRepositoryProvider),
      levelId: widget.levelId);

  LevelCanvasFlows get _flows =>
      LevelCanvasFlows(ref, edits: _edits, busy: _mediaBusy);

  void _refresh() => ref.invalidate(floorPlanProvider(widget.levelId));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final planAsync = ref.watch(floorPlanProvider(widget.levelId));
    // Cache the freshest plan and render it through a reload — ref.invalidate
    // drops the provider's value on every edit, so its own value is null then.
    if (planAsync.value != null) _lastPlan = planAsync.value;
    final shownPlan = planAsync.value ?? _lastPlan;
    final level = ref
        .watch(levelsProvider)
        .value
        ?.where((l) => l.id == widget.levelId)
        .firstOrNull;

    final selected = shownPlan == null
        ? null
        : selectedElementOf(shownPlan, _selectedKind, _selectedId);

    return Scaffold(
      appBar: AppBar(
        title: Text(level?.name ?? ''),
        actions: [
          LevelBackgroundMenu(
            hasBackground: level?.hasBackground ?? false,
            onSet: () => unawaited(_flows.pickBackground(context)),
            onRemove: () => unawaited(_flows.removeBackground(context)),
          ),
        ],
      ),
      // #1216 — the bar answers whichever question the canvas is in the
      // middle of: what can I add, or what can I do to this thing. Never
      // both at once, because there is nothing to add TO a selection.
      bottomNavigationBar: selected != null
          ? EditorSelectionBar(
              kind: selected.kind,
              // An image has no name of its own, so the bar says what it is.
              name: selected.name ??
                  decorOrImageName(l10n, selectedDecorOf(shownPlan!, _selectedKind, _selectedId)),
              onEdit: selected.kind == ElementKind.image
                  ? null
                  : () => _flows.editElement(
                      context, shownPlan!, _selectedKind, _selectedId),
              onDuplicate: selected.kind == ElementKind.seat
                  ? () => _flows.duplicateSeat(
                      context, shownPlan!, _selectedId)
                  : null,
              onDelete: () => _deleteSelection(shownPlan),
              onDismiss: _clearSelection,
              onRotate: selectedDecorOf(shownPlan!, _selectedKind, _selectedId) == null
                  ? null
                  : () => _rotateSelection(shownPlan),
            )
          : EditorToolbar(
              armed: _tool,
              onArm: (tool) => unawaited(_arm(tool)),
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

  Widget _buildCanvas(FloorPlan plan) {
    final shownPlan = _draft ?? plan;
    return Stack(
      children: [
        LevelCanvasView(
          levelId: widget.levelId,
          plan: shownPlan,
          controller: _viewTransform,
          gestures: _gestures(plan),
          overlay: (
            marquee: _marquee,
            marqueeValid: _marqueeValid,
            selection: selectionRectOf(shownPlan, _selectedKind, _selectedId),
            selectionResizable: _selectedKind != ElementKind.seat,
            selectionValid: _draftValid,
            dropTargets: dropTargetsFor(shownPlan, _tool),
          ),
        ),
        // #1216 — an empty floor used to be a blank grid under a row of
        // tools, which says what you CAN do and never what to do first.
        if (plan.offices.isEmpty && plan.images.isEmpty && _tool == null)
          Positioned.fill(
            child: EditorEmptyFloor(
              onStart: () => setState(() => _tool = EditorTool.office),
            ),
          ),
        // The armed tool, said out loud, with the way out beside it.
        if (_tool case final tool?)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: EditorToolHint(
                tool: tool,
                onCancel: () => setState(() => _tool = null),
              ),
            ),
          ),
        // Zoom buttons + draggable scrollbars share the viewer's controller,
        // and the plan auto-fits to the screen on open / level switch.
        Positioned.fill(
          child: CanvasControls(
            controller: _viewTransform,
            contentSize: const Size(
              GridCanvas.widthCells * GridCanvas.cellSize,
              GridCanvas.heightCells * GridCanvas.cellSize,
            ),
            fitBounds:
                fitRectFromCells(shownPlan.usedBounds, GridCanvas.cellSize),
            fitKey: widget.levelId,
          ),
        ),
      ],
    );
  }

  /// A drawing tool owns the drag as a marquee; with a selection (#101)
  /// the drag moves or resizes it — deselect (tap empty space) to pan the
  /// viewport again.
  CanvasGestures _gestures(FloorPlan plan) {
    final drawing = _tool == EditorTool.office || _tool == EditorTool.desk;
    final selecting = _tool == null && _selectedId != null;
    void onTapUp(TapUpDetails d) =>
        unawaited(_handleTap(plan, d.localPosition));
    if (drawing) {
      return (
        owned: true,
        onTapUp: onTapUp,
        onPanStart: (d) => _marqueeFrom(plan, _cellAt(d.localPosition)),
        onPanUpdate: (d) => _marqueeTo(plan, _cellAt(d.localPosition)),
        onPanEnd: (_) => unawaited(_onMarqueeEnd(plan)),
      );
    }
    if (selecting) {
      return (
        owned: true,
        onTapUp: onTapUp,
        onPanStart: (d) => _onSelectPanStart(plan, d.localPosition),
        onPanUpdate: (d) => _onSelectPanUpdate(plan, d.localPosition),
        onPanEnd: (_) => unawaited(_onSelectPanEnd(plan)),
      );
    }
    return (
      owned: false,
      onTapUp: onTapUp,
      onPanStart: null,
      onPanUpdate: null,
      onPanEnd: null,
    );
  }

  /// Starts the marquee on [cell].
  void _marqueeFrom(FloorPlan plan, CanvasCell cell) {
    final rect = rectBetween(cell, cell);
    setState(() {
      _dragStart = cell;
      _marquee = rect;
      _marqueeValid = marqueeProblem(plan, _tool, rect) == null;
    });
  }

  /// Stretches the marquee to [cell].
  void _marqueeTo(FloorPlan plan, CanvasCell cell) {
    final start = _dragStart;
    if (start == null) return;
    final rect = rectBetween(start, cell);
    setState(() {
      _marquee = rect;
      _marqueeValid = marqueeProblem(plan, _tool, rect) == null;
    });
  }

  Future<void> _onMarqueeEnd(FloorPlan plan) async {
    final rect = _marquee;
    setState(() {
      _dragStart = null;
      _marquee = null;
    });
    if (rect != null) await _commitMarquee(plan, rect);
  }

  void _clearSelection() => setState(() {
        _selectedKind = null;
        _selectedId = null;
        _draft = null;
        _draftValid = true;
        _dragEdges = null;
      });

  void _onSelectPanStart(FloorPlan plan, Offset position) {
    final rect = selectionRectOf(plan, _selectedKind, _selectedId);
    if (rect == null) return;
    final edges = _selectedKind == ElementKind.seat
        ? const ResizeEdges()
        : _grid.edgesAt(rect, position.dx, position.dy);
    final cell = _cellAt(position);
    final inside = rect.containsCell(cell.x, cell.y);
    if (edges.isEmpty && !inside) return; // dead drag next to the element
    setState(() {
      _dragStart = cell;
      _dragEdges = edges;
      _draft = plan;
      _draftValid = true;
    });
  }

  void _onSelectPanUpdate(FloorPlan plan, Offset position) {
    final (start, edges, kind, id) =
        (_dragStart, _dragEdges, _selectedKind, _selectedId);
    if (start == null || edges == null || kind == null || id == null) return;
    final base = selectionRectOf(plan, kind, id);
    if (base == null) return;
    final cell = _cellAt(position);
    final draft = dragDraft(plan,
        element: (kind: kind, id: id),
        base: base,
        edges: edges,
        delta: (x: cell.x - start.x, y: cell.y - start.y));
    setState(() {
      _draft = draft;
      _draftValid = validateElement(draft, kind, id) == null;
    });
  }

  Future<void> _onSelectPanEnd(FloorPlan plan) async {
    final (draft, kind, id) = (_draft, _selectedKind, _selectedId);
    setState(() {
      _dragStart = null;
      _dragEdges = null;
    });
    if (draft == null || kind == null || id == null) return;
    void dropDraft() => setState(() {
          _draft = null;
          _draftValid = true;
        });
    final problem = validateElement(draft, kind, id);
    if (problem != null) {
      dropDraft();
      showPlacementProblem(context, problem);
      return;
    }
    await _edits.persistDiff(plan, draft);
    dropDraft();
    _refresh();
  }

  Future<void> _commitMarquee(FloorPlan plan, GridRect rect) async {
    if (ref.read(currentWorkspaceProvider).value == null) return;
    final problem = marqueeProblem(plan, _tool, rect);
    if (problem != null) {
      showPlacementProblem(context, problem);
      return;
    }
    if (_tool == EditorTool.office) {
      await _flows.createOffice(context, plan, rect);
    } else if (_tool == EditorTool.desk) {
      await _flows.createDesk(context, plan, rect);
    }
  }

  Future<void> _handleTap(FloorPlan plan, Offset position) async {
    final cell = _cellAt(position);
    if (_tool == EditorTool.seat) {
      await _flows.placeSeat(context, plan, cell);
      return;
    }
    final decor = _decorKind;
    if (_tool == EditorTool.decor && decor != null) {
      await _flows.placeDecor(context, cell, decor, onPlaced: () {
        if (mounted) setState(() => _tool = null);
      });
      return;
    }
    if (_tool == EditorTool.image) {
      await _flows.placeImage(context, cell,
          // Back to the resting state so the fresh image can be moved or
          // resized at once.
          onPlaced: () {
            if (mounted) setState(() => _tool = null);
          });
      return;
    }
    // No tool armed (#1216): a tap selects — handles appear and dragging
    // moves or resizes (#101) — a second tap on the same element opens
    // its properties, and a tap on empty space deselects. Everything you
    // can DO to the selection is on the bar it raises.
    final hit = hitAt(plan, cell);
    if (hit == null) {
      _clearSelection();
      return;
    }
    final (kind, id) = hit;
    if (kind == _selectedKind && id == _selectedId) {
      // Images have no properties sheet — a second tap is a no-op
      // (move/resize via drag handles, remove via the erase tool).
      await _flows.editElement(context, plan, kind, id);
      return;
    }
    setState(() {
      _selectedKind = kind;
      _selectedId = id;
      _draft = null;
      _draftValid = true;
    });
  }

  /// The shape the next tap draws (#3074), chosen from the palette.
  PlanDecorKind? _decorKind;

  /// Arms [tool]; the shapes tool first asks which shape to draw.
  Future<void> _arm(EditorTool? tool) async {
    _clearSelection();
    final kind = tool == EditorTool.decor ? await pickDecorKind(context) : null;
    if (!mounted || (tool == EditorTool.decor && kind == null)) return;
    setState(() {
      _decorKind = kind;
      _tool = tool;
    });
  }

  Future<void> _rotateSelection(FloorPlan plan) async {
    final image = selectedDecorOf(plan, _selectedKind, _selectedId);
    if (image == null) return;
    await _edits.rotateDecor(image);
    _refresh();
  }

  /// Delete what is selected. The element is outlined on the canvas in
  /// front of the reader while the dialog asks, which is what the erase
  /// MODE could never manage: there, the thing you were about to lose
  /// was whatever your finger happened to land on next.
  Future<void> _deleteSelection(FloorPlan plan) async {
    final action = _edits.deleteOf(plan, _selectedKind, _selectedId);
    if (action == null) return;
    final text = deleteElementConfirmText(ref, context.l10n);
    if (await confirmElementErase(context, text)) {
      await action();
      _refresh();
    }
    if (mounted) _clearSelection();
  }
}
