// SPDX-License-Identifier: 0BSD
import 'package:file_selector/file_selector.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../../../../core/files/file_picker.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/canvas_controls.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../plan/domain/desk.dart';
import '../../../plan/domain/floor_plan.dart';
import '../../../plan/domain/floor_plan_editing.dart';
import '../../../plan/domain/floor_plan_rules.dart';
import '../../../plan/domain/grid_geometry.dart';
import '../../../plan/domain/office.dart';
import '../../../plan/domain/seat.dart';
import '../delete_confirm_text.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../../plan/presentation/widgets/floor_plan_painter.dart';
import '../../../plan/presentation/widgets/plan_canvas.dart';
import '../widgets/editor_selection_bar.dart';
import '../widgets/editor_tool_hint.dart';
import '../widgets/editor_toolbar.dart';
import '../widgets/placement_problem.dart';
import '../widgets/seat_properties_sheet.dart';
import '../widgets/space_properties_sheet.dart';
import 'editor_tool.dart';

/// Canvas dimensions in grid cells and the logical cell size at scale 1 —
/// aliases of the shared [PlanCanvasMetrics] so the editor can never drift
/// from the live plan / Reserve hub geometry.
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
    super.dispose();
  }

  GridRect? _selectionRect(FloorPlan plan) {
    final id = _selectedId;
    return switch (_selectedKind) {
      ElementKind.office =>
        plan.offices.where((o) => o.id == id).firstOrNull?.rect,
      ElementKind.desk =>
        plan.desks.where((d) => d.id == id).firstOrNull?.rect,
      ElementKind.seat =>
        plan.seats.where((s) => s.id == id).firstOrNull?.footprint,
      ElementKind.image =>
        plan.images.where((i) => i.id == id).firstOrNull?.rect,
      null => null,
    };
  }

  void _clearSelection() => setState(() {
        _selectedKind = null;
        _selectedId = null;
        _draft = null;
        _draftValid = true;
        _dragEdges = null;
      });

  /// Edge hit-test in canvas pixels (tolerance ~half a cell each side).
  ResizeEdges _edgesAt(GridRect rect, Offset position) {
    const tol = GridCanvas.cellSize * 0.55;
    final px = Rect.fromLTWH(
      rect.x * GridCanvas.cellSize,
      rect.y * GridCanvas.cellSize,
      rect.w * GridCanvas.cellSize,
      rect.h * GridCanvas.cellSize,
    );
    final near = px.inflate(tol).contains(position);
    if (!near) return const ResizeEdges();
    return ResizeEdges(
      left: (position.dx - px.left).abs() <= tol,
      right: (position.dx - px.right).abs() <= tol,
      top: (position.dy - px.top).abs() <= tol,
      bottom: (position.dy - px.bottom).abs() <= tol,
    );
  }

  void _onSelectPanStart(FloorPlan plan, Offset position) {
    final rect = _selectionRect(plan);
    if (rect == null) return;
    final edges = _selectedKind == ElementKind.seat
        ? const ResizeEdges()
        : _edgesAt(rect, position);
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
    final start = _dragStart;
    final edges = _dragEdges;
    final kind = _selectedKind;
    final id = _selectedId;
    if (start == null || edges == null || kind == null || id == null) return;
    final base = _selectionRect(plan);
    if (base == null) return;
    final cell = _cellAt(position);
    final dx = cell.x - start.x;
    final dy = cell.y - start.y;

    final FloorPlan draft;
    if (kind == ElementKind.seat) {
      final moved = dragRect(base, const ResizeEdges(), dx, dy);
      draft = applySeatPosition(plan, id, moved.x, moved.y);
    } else {
      final next = dragRect(base, edges, dx, dy);
      draft = switch (kind) {
        ElementKind.office => applyOfficeRect(plan, id, next),
        ElementKind.image => applyImageRect(plan, id, next),
        _ => applyDeskRect(plan, id, next),
      };
    }
    setState(() {
      _draft = draft;
      _draftValid = validateElement(draft, kind, id) == null;
    });
  }

  Future<void> _onSelectPanEnd(FloorPlan plan) async {
    final draft = _draft;
    final kind = _selectedKind;
    final id = _selectedId;
    setState(() {
      _dragStart = null;
      _dragEdges = null;
    });
    if (draft == null || kind == null || id == null) return;
    final problem = validateElement(draft, kind, id);
    if (problem != null) {
      setState(() {
        _draft = null;
        _draftValid = true;
      });
      showPlacementProblem(context, problem);
      return;
    }
    await _persistDiff(plan, draft);
    setState(() {
      _draft = null;
      _draftValid = true;
    });
    ref.invalidate(floorPlanProvider(widget.levelId));
  }

  /// Persists every element whose geometry changed between [base] and
  /// [draft] (a moved office drags its desks and seats along).
  Future<void> _persistDiff(FloorPlan base, FloorPlan draft) async {
    final repo = ref.read(floorPlanRepositoryProvider);
    final baseOffices = {for (final o in base.offices) o.id: o};
    for (final office in draft.offices) {
      if (baseOffices[office.id] != office) await repo.updateOffice(office);
    }
    final baseDesks = {for (final d in base.desks) d.id: d};
    for (final desk in draft.desks) {
      if (baseDesks[desk.id] != desk) await repo.updateDesk(desk);
    }
    final baseSeats = {for (final s in base.seats) s.id: s};
    for (final seat in draft.seats) {
      if (baseSeats[seat.id] != seat) await repo.updateSeat(seat);
    }
    final baseImages = {for (final i in base.images) i.id: i};
    for (final image in draft.images) {
      if (baseImages[image.id] != image) {
        await repo.updatePlanImageRect(image.id, image.rect);
      }
    }
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

  GridRect _rectBetween(({int x, int y}) a, ({int x, int y}) b) {
    final x = a.x < b.x ? a.x : b.x;
    final y = a.y < b.y ? a.y : b.y;
    return GridRect(
      x: x,
      y: y,
      w: (a.x - b.x).abs() + 1,
      h: (a.y - b.y).abs() + 1,
    );
  }

  PlacementProblem? _validate(FloorPlan plan, GridRect rect) {
    return switch (_tool) {
      EditorTool.office => validateOfficePlacement(rect, plan.offices),
      EditorTool.desk => () {
          final office = plan.officeAtCell(rect.x, rect.y);
          if (office == null) return PlacementProblem.outsideParent;
          return validateDeskPlacement(rect, office, plan.desks);
        }(),
      _ => null,
    };
  }


  Future<void> _commitMarquee(FloorPlan plan, GridRect rect) async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final repo = ref.read(floorPlanRepositoryProvider);

    final problem = _validate(plan, rect);
    if (problem != null) {
      showPlacementProblem(context, problem);
      return;
    }

    if (_tool == EditorTool.office) {
      final name = await _promptText(
        title: l10n?.editorNewOffice ?? 'New office',
        label: l10n?.editorOfficeNameLabel ?? 'Office name',
        initial: '${l10n?.editorOfficeNameDefault ?? 'Office'} '
            '${plan.offices.length + 1}',
      );
      if (name == null || name.isEmpty) return;
      await repo.createOffice(
        workspaceId: workspace.id,
        levelId: widget.levelId,
        name: name,
        color: plan.offices.length,
        bookableAsWhole: false,
        rect: rect,
      );
    } else if (_tool == EditorTool.desk) {
      final office = plan.officeAtCell(rect.x, rect.y)!;
      await repo.createDesk(
        workspaceId: workspace.id,
        officeId: office.id,
        name: '${l10n?.editorDeskNameDefault ?? 'Desk'} '
            '${plan.desksOf(office.id).length + 1}',
        rect: rect,
      );
    }
    ref.invalidate(floorPlanProvider(widget.levelId));
  }

  Future<void> _placeSeat(FloorPlan plan, ({int x, int y}) cell) async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    final desk = plan.deskAtCell(cell.x, cell.y);
    if (workspace == null) return;
    if (desk == null) {
      AppSnack.error(
        context,
        l10n?.editorSeatNoDesk ?? 'Seats can only be placed on a desk.',
        replace: true,
      );
      return;
    }
    const orientation = SeatOrientation.n;
    final anchor = clampSeatAnchor(desk, cell.x, cell.y, orientation);
    if (anchor == null) {
      showPlacementProblem(context, PlacementProblem.outsideParent);
      return;
    }
    final candidate = Seat(
      id: '',
      workspaceId: workspace.id,
      deskId: desk.id,
      name: '',
      x: anchor.x,
      y: anchor.y,
      orientation: orientation,
      chair: '',
      amenities: const [],
    );
    final problem =
        validateSeatPlacement(candidate, desk, plan.seatsOf(desk.id));
    if (problem != null) {
      showPlacementProblem(context, problem);
      return;
    }
    await ref.read(floorPlanRepositoryProvider).createSeat(
          workspaceId: workspace.id,
          deskId: desk.id,
          name: '${l10n?.editorSeatNameDefault ?? 'Seat'} '
              '${plan.seatsOf(desk.id).length + 1}',
          x: anchor.x,
          y: anchor.y,
          orientation: orientation,
        );
    ref.invalidate(floorPlanProvider(widget.levelId));
  }

  Future<void> _handleTap(FloorPlan plan, Offset position) async {
    final cell = _cellAt(position);
    final seat = plan.seatAtCell(cell.x, cell.y);
    final desk = plan.deskAtCell(cell.x, cell.y);
    final office = plan.officeAtCell(cell.x, cell.y);

    if (_tool == EditorTool.seat) {
      await _placeSeat(plan, cell);
      return;
    }

    if (_tool == EditorTool.image) {
      await _placeImage(context, cell);
      return;
    }

    final image = plan.imageAtCell(cell.x, cell.y);

    // No tool armed (#1216): a tap selects — handles appear and dragging
    // moves or resizes (#101) — a second tap on the same element opens
    // its properties, and a tap on empty space deselects. Everything you
    // can DO to the selection is on the bar it raises.
    final (ElementKind, String)? hit = seat != null
        ? (ElementKind.seat, seat.id)
        : desk != null
            ? (ElementKind.desk, desk.id)
            : office != null
                ? (ElementKind.office, office.id)
                : image != null
                    ? (ElementKind.image, image.id)
                    : null;

    if (hit == null) {
      _clearSelection();
      return;
    }
    final (kind, id) = hit;
    if (kind == _selectedKind && id == _selectedId) {
      switch (kind) {
        case ElementKind.seat:
          await showSeatPropertiesSheet(context, ref,
              levelId: widget.levelId, plan: plan, seat: seat!);
        case ElementKind.desk:
          await _showDeskSheet(desk!);
        case ElementKind.office:
          await _showOfficeSheet(office!);
        case ElementKind.image:
          // Images have no properties sheet — a second tap is a no-op
          // (move/resize via drag handles, remove via the erase tool).
          break;
      }
      return;
    }
    setState(() {
      _selectedKind = kind;
      _selectedId = id;
      _draft = null;
      _draftValid = true;
    });
  }

  Future<void> _showOfficeSheet(Office office) async {
    final l10n = AppLocalizations.of(context);
    final props = await showSpacePropertiesSheet(
      context,
      title: l10n?.editorOfficeProperties ?? 'Office',
      nameLabel: l10n?.editorOfficeNameLabel ?? 'Office name',
      name: office.name,
      bookable: office.bookableAsWhole,
      priceCents: office.priceCents,
      keyPrefix: 'office',
    );
    if (props == null) return;
    await ref.read(floorPlanRepositoryProvider).updateOffice(
          office.copyWith(
            name: props.name,
            bookableAsWhole: props.bookable,
            priceCents: props.priceCents,
          ),
        );
    ref.invalidate(floorPlanProvider(widget.levelId));
  }

  Future<void> _showDeskSheet(Desk desk) async {
    final l10n = AppLocalizations.of(context);
    final props = await showSpacePropertiesSheet(
      context,
      title: l10n?.editorDeskProperties ?? 'Desk',
      nameLabel: l10n?.editorDeskNameLabel ?? 'Desk name',
      name: desk.name,
      bookable: desk.bookableAsWhole,
      priceCents: desk.priceCents,
      keyPrefix: 'desk',
    );
    if (props == null) return;
    await ref.read(floorPlanRepositoryProvider).updateDesk(
          desk.copyWith(
            name: props.name,
            bookableAsWhole: props.bookable,
            priceCents: props.priceCents,
          ),
        );
    ref.invalidate(floorPlanProvider(widget.levelId));
  }

  /// Adds a resizable illustration image (0037) at [cell]: pick an
  /// image, upload it, and drop it at a default 16×12 rect anchored near
  /// the tap. It draws BELOW the offices/tables/seats, so you can then
  /// place real tables and seats on top of the photo.
  Future<void> _placeImage(BuildContext context, ({int x, int y}) cell) async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    const group = XTypeGroup(
      label: 'images',
      extensions: ['png', 'jpg', 'jpeg', 'webp'],
      mimeTypes: ['image/png', 'image/jpeg', 'image/webp'],
    );
    final file = await ref.read(filePickerProvider)(group);
    if (file == null || !context.mounted) return;
    const w = 16, h = 12;
    final x = cell.x.clamp(0, GridCanvas.widthCells - w);
    final y = cell.y.clamp(0, GridCanvas.heightCells - h);
    try {
      final bytes = await file.readAsBytes();
      final contentType = file.mimeType ??
          (file.name.toLowerCase().endsWith('.png')
              ? 'image/png'
              : 'image/jpeg');
      await ref.read(floorPlanRepositoryProvider).createPlanImage(
            workspaceId: workspace.id,
            levelId: widget.levelId,
            rect: GridRect(x: x, y: y, w: w, h: h),
            bytes: bytes,
            contentType: contentType,
          );
    } catch (e, st) {
      debugPrint('place image failed: $e\n$st');
      TraceLogger.instance.error(
          'editor', 'place image failed', error: e, stackTrace: st);
      if (!context.mounted) return;
      AppSnack.error(
        context,
        l10n?.workspaceGenericError ??
            'Something went wrong. Please try again.',
      );
      return;
    }
    ref.invalidate(floorPlanProvider(widget.levelId));
    // Back to the resting state so the fresh image can be moved or
    // resized at once.
    if (context.mounted) setState(() => _tool = null);
  }

  /// Owner picks a photo/blueprint of the real space as this level's
  /// background (0036); it's uploaded and painted behind the grid.
  Future<void> _pickBackground(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    const group = XTypeGroup(
      label: 'images',
      extensions: ['png', 'jpg', 'jpeg', 'webp'],
      mimeTypes: ['image/png', 'image/jpeg', 'image/webp'],
    );
    final file = await ref.read(filePickerProvider)(group);
    if (file == null || !context.mounted) return;
    try {
      final bytes = await file.readAsBytes();
      final contentType = file.mimeType ??
          (file.name.toLowerCase().endsWith('.png')
              ? 'image/png'
              : 'image/jpeg');
      await ref.read(floorPlanRepositoryProvider).setLevelBackground(
            workspace.id,
            widget.levelId,
            bytes: bytes,
            contentType: contentType,
          );
    } catch (e, st) {
      debugPrint('set background failed: $e\n$st');
      TraceLogger.instance.error(
          'editor', 'set background failed', error: e, stackTrace: st);
      if (!context.mounted) return;
      AppSnack.error(
        context,
        l10n?.workspaceGenericError ??
            'Something went wrong. Please try again.',
      );
      return;
    }
    ref
      ..invalidate(levelsProvider)
      ..invalidate(levelBackgroundProvider(widget.levelId));
  }

  Future<void> _removeBackground(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    try {
      await ref
          .read(floorPlanRepositoryProvider)
          .clearLevelBackground(workspace.id, widget.levelId);
    } catch (e, st) {
      debugPrint('remove background failed: $e\n$st');
      TraceLogger.instance.error(
          'editor', 'remove background failed', error: e, stackTrace: st);
      if (!context.mounted) return;
      AppSnack.error(
        context,
        l10n?.workspaceGenericError ??
            'Something went wrong. Please try again.',
      );
      return;
    }
    ref
      ..invalidate(levelsProvider)
      ..invalidate(levelBackgroundProvider(widget.levelId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
                icon: const Icon(Icons.image_outlined),
                tooltip: l10n?.editorBackgroundImage ?? 'Background image',
                onSelected: (v) {
                  if (v == 'set') {
                    _pickBackground(context);
                  } else {
                    _removeBackground(context);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'set',
                    child: Text(
                      hasBg
                          ? (l10n?.editorBackgroundReplace ??
                              'Replace background image')
                          : (l10n?.editorBackgroundSet ??
                              'Set background image'),
                    ),
                  ),
                  if (hasBg)
                    PopupMenuItem(
                      value: 'remove',
                      child: Text(
                        l10n?.editorBackgroundRemove ??
                            'Remove background image',
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
          ? _buildCanvas(shownPlan)
          : switch (planAsync) {
              AsyncError() => Center(
                  child: Text(
                    l10n?.workspaceGenericError ??
                        'Something went wrong. Please try again.',
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
    final l10n = AppLocalizations.of(context);
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
              name: l10n?.editorToolImage ?? 'Image',
            )
          : null,
      null => null,
    };
  }

  Future<void> _editSelection(FloorPlan plan) async {
    final id = _selectedId;
    switch (_selectedKind) {
      case ElementKind.seat:
        final seat = plan.seats.where((s) => s.id == id).firstOrNull;
        if (seat != null) {
          await showSeatPropertiesSheet(context, ref,
              levelId: widget.levelId, plan: plan, seat: seat);
        }
      case ElementKind.desk:
        final desk = plan.desks.where((d) => d.id == id).firstOrNull;
        if (desk != null) await _showDeskSheet(desk);
      case ElementKind.office:
        final office = plan.offices.where((o) => o.id == id).firstOrNull;
        if (office != null) await _showOfficeSheet(office);
      case ElementKind.image:
      case null:
        break;
    }
  }

  /// #1216 — the repetitive act this editor exists for. A six-seat table
  /// is six identical placements, and doing them by hand means six taps
  /// on a desk plus six trips through the naming default. Duplicating
  /// puts the copy on the first free cell of the same desk, so the
  /// second seat costs one tap and the sixth costs one tap.
  Future<void> _duplicateSeat(FloorPlan plan) async {
    final l10n = AppLocalizations.of(context);
    final seat = plan.seats.where((s) => s.id == _selectedId).firstOrNull;
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (seat == null || workspace == null) return;
    final desk = plan.desks.where((d) => d.id == seat.deskId).firstOrNull;
    if (desk == null) return;

    final siblings = plan.seatsOf(desk.id);
    ({int x, int y})? free;
    for (var y = desk.rect.y; y < desk.rect.y + desk.rect.h && free == null;
        y++) {
      for (var x = desk.rect.x; x < desk.rect.x + desk.rect.w; x++) {
        final anchor = clampSeatAnchor(desk, x, y, seat.orientation);
        if (anchor == null) continue;
        final candidate = Seat(
          id: '',
          workspaceId: workspace.id,
          deskId: desk.id,
          name: '',
          x: anchor.x,
          y: anchor.y,
          orientation: seat.orientation,
          chair: seat.chair,
          amenities: const [],
        );
        if (validateSeatPlacement(candidate, desk, siblings) == null) {
          free = anchor;
          break;
        }
      }
    }
    if (free == null) {
      AppSnack.info(
        context,
        l10n?.editorDeskFull ?? 'No room left on this desk.',
        replace: true,
      );
      return;
    }
    await ref.read(floorPlanRepositoryProvider).createSeat(
          workspaceId: workspace.id,
          deskId: desk.id,
          name: '${l10n?.editorSeatNameDefault ?? 'Seat'} '
              '${siblings.length + 1}',
          x: free.x,
          y: free.y,
          orientation: seat.orientation,
        );
    ref.invalidate(floorPlanProvider(widget.levelId));
  }

  /// Delete what is selected. The element is outlined on the canvas in
  /// front of the reader while the dialog asks, which is what the erase
  /// MODE could never manage: there, the thing you were about to lose
  /// was whatever your finger happened to land on next.
  Future<void> _deleteSelection(FloorPlan plan) async {
    final id = _selectedId;
    final repo = ref.read(floorPlanRepositoryProvider);
    final action = switch (_selectedKind) {
      ElementKind.seat when plan.seats.any((s) => s.id == id) =>
        () => repo.deleteSeat(id!),
      ElementKind.desk when plan.desks.any((d) => d.id == id) =>
        () => repo.deleteDesk(id!),
      ElementKind.office when plan.offices.any((o) => o.id == id) =>
        () => repo.deleteOffice(id!),
      ElementKind.image when plan.images.any((i) => i.id == id) =>
        () => repo.deletePlanImage(id!),
      _ => null,
    };
    if (action == null) return;
    await _confirmErase(action);
    if (mounted) _clearSelection();
  }

  /// Where the armed tool may legally place its next element (#1216).
  ///
  /// The rules already existed and were only ever spoken after a failed
  /// drag: *"Must be fully inside an office."* Since the editor can
  /// answer before the gesture, it does — see
  /// [FloorPlanPainter.dropTargets], where an empty set is a meaningful
  /// answer and null means no tool is armed.
  Set<String>? _dropTargets(FloorPlan plan) => switch (_tool) {
        EditorTool.desk => {for (final o in plan.offices) o.id},
        EditorTool.seat => {for (final d in plan.desks) d.id},
        // An office may go anywhere on the floor, and an image too, so
        // dimming would be a lie about a rule that does not exist.
        EditorTool.office || EditorTool.image || null => null,
      };

  /// The first thing to do on a floor nobody has drawn yet.
  Widget _emptyFloor() {
    final l10n = AppLocalizations.of(context);
    return IgnorePointer(
      ignoring: false,
      child: Center(
        child: Padding(
          padding: AppSpacing.xlAll,
          child: Card(
            key: const ValueKey('editor-empty-floor'),
            child: Padding(
              padding: AppSpacing.lgAll,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.meeting_room_outlined,
                    size: 40,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n?.editorEmptyFloorTitle ?? 'This floor is empty',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n?.editorEmptyFloorBody ??
                        'Everything sits inside a room: draw one, put '
                            'desks in it, then seats on the desks.',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    key: const ValueKey('editor-empty-floor-start'),
                    onPressed: () =>
                        setState(() => _tool = EditorTool.office),
                    icon: const Icon(Icons.add),
                    label: Text(
                      l10n?.editorEmptyFloorAction ?? 'Draw the first room',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCanvas(FloorPlan plan) {
    const size = Size(
      GridCanvas.widthCells * GridCanvas.cellSize,
      GridCanvas.heightCells * GridCanvas.cellSize,
    );
    final drawing = _tool == EditorTool.office || _tool == EditorTool.desk;
    // #101: while an element is selected, the drag gesture belongs to
    // move/resize — deselect (tap empty space) to pan the viewport again.
    final selecting = _tool == null && _selectedId != null;
    final shownPlan = _draft ?? plan;

    return Stack(
      children: [
        InteractiveViewer(
      transformationController: _viewTransform,
      constrained: false,
      minScale: CanvasControls.defaultMinScale,
      maxScale: CanvasControls.defaultMaxScale,
      panEnabled: !drawing && !selecting,
      scaleEnabled: !drawing && !selecting,
      // UNBOUNDED pan — the same fit-vs-clamp fight as the live plan
      // (see plan_canvas.dart): a centred small level must stay legal.
      boundaryMargin: const EdgeInsets.all(double.infinity),
      child: GestureDetector(
        // `down` so onPanStart reports the touch-down cell, not the position
        // where the drag cleared the touch slop.
        dragStartBehavior: DragStartBehavior.down,
        onTapUp: (details) => _handleTap(plan, details.localPosition),
        onPanStart: drawing
            ? (details) {
                final cell = _cellAt(details.localPosition);
                setState(() {
                  _dragStart = cell;
                  _marquee = _rectBetween(cell, cell);
                  _marqueeValid = _validate(plan, _marquee!) == null;
                });
              }
            : selecting
                ? (details) => _onSelectPanStart(plan, details.localPosition)
                : null,
        onPanUpdate: drawing
            ? (details) {
                final start = _dragStart;
                if (start == null) return;
                final rect =
                    _rectBetween(start, _cellAt(details.localPosition));
                setState(() {
                  _marquee = rect;
                  _marqueeValid = _validate(plan, rect) == null;
                });
              }
            : selecting
                ? (details) => _onSelectPanUpdate(plan, details.localPosition)
                : null,
        onPanEnd: drawing
            ? (details) async {
                final rect = _marquee;
                setState(() {
                  _dragStart = null;
                  _marquee = null;
                });
                if (rect != null) await _commitMarquee(plan, rect);
              }
            : selecting
                ? (details) => _onSelectPanEnd(plan)
                : null,
        child: CustomPaint(
          key: const ValueKey('level-canvas'),
          size: size,
          painter: FloorPlanPainter(
            background: ref.watch(levelBackgroundProvider(widget.levelId)).value,
            images: {
              for (final image in shownPlan.images)
                if (ref.watch(planImageProvider(image.id)).value != null)
                  image.id: ref.watch(planImageProvider(image.id)).value!,
            },
            plan: shownPlan,
            cellSize: GridCanvas.cellSize,
            colorScheme: Theme.of(context).colorScheme,
            deskOpacity: (ref.watch(currentWorkspaceProvider).value?.deskOpacity ??
                    100) /
                100,
            marquee: _marquee,
            marqueeValid: _marqueeValid,
            selection: _selectionRect(shownPlan),
            selectionResizable: _selectedKind != ElementKind.seat,
            selectionValid: _draftValid,
            dropTargets: _dropTargets(shownPlan),
          ),
        ),
      ),
        ),
        // #1216 — an empty floor used to be a blank grid under a row of
        // tools, which says what you CAN do and never what to do first.
        if (plan.offices.isEmpty && plan.images.isEmpty && _tool == null)
          Positioned.fill(child: _emptyFloor()),
        // The armed tool, said out loud, with the way out beside it.
        if (_tool != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: EditorToolHint(
                tool: _tool!,
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

  Future<void> _confirmErase(Future<void> Function() action) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.commonDelete ?? 'Delete'),
        content: Text(deleteElementConfirmText(ref, l10n)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n?.commonCancel ?? 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n?.commonDelete ?? 'Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await action();
    ref.invalidate(floorPlanProvider(widget.levelId));
  }

  Future<String?> _promptText({
    required String title,
    required String label,
    String initial = '',
  }) {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n?.commonCancel ?? 'Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(controller.text.trim()),
            child: Text(l10n?.commonSave ?? 'Save'),
          ),
        ],
      ),
    );
  }
}
