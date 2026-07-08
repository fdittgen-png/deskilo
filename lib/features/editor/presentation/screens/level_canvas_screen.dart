// SPDX-License-Identifier: MIT
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../plan/domain/desk.dart';
import '../../../plan/domain/floor_plan.dart';
import '../../../plan/domain/floor_plan_editing.dart';
import '../../../plan/domain/floor_plan_rules.dart';
import '../../../plan/domain/grid_geometry.dart';
import '../../../plan/domain/office.dart';
import '../../../plan/domain/seat.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../../plan/presentation/widgets/floor_plan_painter.dart';

enum EditorTool { select, office, desk, seat, erase }

/// Canonical amenity keys stored on seats; display names come from ARB.
const List<String> kSeatAmenities = [
  'monitor',
  'standing_desk',
  'window',
  'dock',
  'ergonomic',
];

/// Canvas dimensions in grid cells and the logical cell size at scale 1.
abstract final class GridCanvas {
  static const int widthCells = 120;
  static const int heightCells = 120;
  static const double cellSize = 14;
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
  EditorTool _tool = EditorTool.select;
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

  GridRect? _selectionRect(FloorPlan plan) {
    final id = _selectedId;
    return switch (_selectedKind) {
      ElementKind.office =>
        plan.offices.where((o) => o.id == id).firstOrNull?.rect,
      ElementKind.desk =>
        plan.desks.where((d) => d.id == id).firstOrNull?.rect,
      ElementKind.seat =>
        plan.seats.where((s) => s.id == id).firstOrNull?.footprint,
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
      draft = kind == ElementKind.office
          ? applyOfficeRect(plan, id, next)
          : applyDeskRect(plan, id, next);
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
      _showProblem(problem);
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

  void _showProblem(PlacementProblem problem) {
    final l10n = AppLocalizations.of(context);
    final message = switch (problem) {
      PlacementProblem.overlapsSibling =>
        l10n?.editorPlacementOverlap ?? 'Overlaps an existing element.',
      PlacementProblem.outsideParent =>
        l10n?.editorPlacementOutside ?? 'Must be fully inside an office.',
    };
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _commitMarquee(FloorPlan plan, GridRect rect) async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final repo = ref.read(floorPlanRepositoryProvider);

    final problem = _validate(plan, rect);
    if (problem != null) {
      _showProblem(problem);
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
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              l10n?.editorSeatNoDesk ?? 'Seats can only be placed on a desk.',
            ),
          ),
        );
      return;
    }
    const orientation = SeatOrientation.n;
    final anchor = clampSeatAnchor(desk, cell.x, cell.y, orientation);
    if (anchor == null) {
      _showProblem(PlacementProblem.outsideParent);
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
      _showProblem(problem);
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

    if (_tool == EditorTool.erase) {
      if (seat != null) {
        await _confirmErase(
          () => ref.read(floorPlanRepositoryProvider).deleteSeat(seat.id),
        );
      } else if (desk != null) {
        await _confirmErase(
          () => ref.read(floorPlanRepositoryProvider).deleteDesk(desk.id),
        );
      } else if (office != null) {
        await _confirmErase(
          () => ref.read(floorPlanRepositoryProvider).deleteOffice(office.id),
        );
      }
      return;
    }

    // Select tool (#101): first tap selects (handles appear, dragging moves
    // or resizes); tapping the selected element again opens its properties;
    // tapping empty space deselects.
    final (ElementKind, String)? hit = seat != null
        ? (ElementKind.seat, seat.id)
        : desk != null
            ? (ElementKind.desk, desk.id)
            : office != null
                ? (ElementKind.office, office.id)
                : null;

    if (hit == null) {
      _clearSelection();
      return;
    }
    final (kind, id) = hit;
    if (kind == _selectedKind && id == _selectedId) {
      switch (kind) {
        case ElementKind.seat:
          await _showSeatSheet(plan, seat!);
        case ElementKind.desk:
          await _showDeskSheet(desk!);
        case ElementKind.office:
          await _showOfficeSheet(office!);
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

  String _amenityLabel(AppLocalizations? l10n, String key) {
    return switch (key) {
      'monitor' => l10n?.amenityMonitor ?? 'Monitor',
      'standing_desk' => l10n?.amenityStandingDesk ?? 'Standing desk',
      'window' => l10n?.amenityWindow ?? 'Window seat',
      'dock' => l10n?.amenityDock ?? 'Docking station',
      'ergonomic' => l10n?.amenityErgonomicChair ?? 'Ergonomic chair',
      _ => key,
    };
  }

  Future<void> _showSeatSheet(FloorPlan plan, Seat seat) async {
    final l10n = AppLocalizations.of(context);
    final name = TextEditingController(text: seat.name);
    final chair = TextEditingController(text: seat.chair);
    var orientation = seat.orientation;
    final amenities = {...seat.amenities};
    var blocked = seat.isBlockedAt(DateTime.now());

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: StatefulBuilder(
          builder: (context, setSheetState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n?.editorSeatProperties ?? 'Seat',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: name,
                  decoration: InputDecoration(
                    labelText: l10n?.editorSeatNameLabel ?? 'Seat name',
                  ),
                ),
                const SizedBox(height: 12),
                Text(l10n?.editorOrientationLabel ?? 'Sitting direction'),
                const SizedBox(height: 4),
                SegmentedButton<SeatOrientation>(
                  segments: const [
                    ButtonSegment(
                      value: SeatOrientation.n,
                      icon: Icon(Icons.arrow_upward),
                    ),
                    ButtonSegment(
                      value: SeatOrientation.e,
                      icon: Icon(Icons.arrow_forward),
                    ),
                    ButtonSegment(
                      value: SeatOrientation.s,
                      icon: Icon(Icons.arrow_downward),
                    ),
                    ButtonSegment(
                      value: SeatOrientation.w,
                      icon: Icon(Icons.arrow_back),
                    ),
                  ],
                  selected: {orientation},
                  onSelectionChanged: (selection) =>
                      setSheetState(() => orientation = selection.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: chair,
                  decoration: InputDecoration(
                    labelText: l10n?.editorChairLabel ?? 'Chair type',
                  ),
                ),
                const SizedBox(height: 12),
                Text(l10n?.editorAmenitiesLabel ?? 'Amenities'),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final key in kSeatAmenities)
                      FilterChip(
                        label: Text(_amenityLabel(l10n, key)),
                        selected: amenities.contains(key),
                        onSelected: (selected) => setSheetState(() {
                          selected
                              ? amenities.add(key)
                              : amenities.remove(key);
                        }),
                      ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    l10n?.editorBlockedLabel ?? 'Blocked (maintenance)',
                  ),
                  value: blocked,
                  onChanged: (v) => setSheetState(() => blocked = v),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(l10n?.commonSave ?? 'Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved != true) return;

    final updated = seat.copyWith(
      name: name.text.trim().isEmpty ? seat.name : name.text.trim(),
      chair: chair.text.trim(),
      orientation: orientation,
      amenities: amenities.toList()..sort(),
      blockedFrom: blocked ? (seat.blockedFrom ?? DateTime.now()) : null,
      blockedTo: blocked ? seat.blockedTo : null,
    );
    final problem = validateSeatInPlan(plan, updated);
    if (problem != null) {
      _showProblem(problem);
      return;
    }
    await ref.read(floorPlanRepositoryProvider).updateSeat(updated);
    ref.invalidate(floorPlanProvider(widget.levelId));
  }

  Future<void> _confirmErase(Future<void> Function() action) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.commonDelete ?? 'Delete'),
        content: Text(
          l10n?.editorDeleteElementConfirm ??
              'Delete this element? Anything placed on it is removed too.',
        ),
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

  Future<void> _showOfficeSheet(Office office) async {
    final l10n = AppLocalizations.of(context);
    var bookable = office.bookableAsWhole;
    final name = TextEditingController(text: office.name);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: StatefulBuilder(
          builder: (context, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n?.editorOfficeProperties ?? 'Office',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: name,
                decoration: InputDecoration(
                  labelText: l10n?.editorOfficeNameLabel ?? 'Office name',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  l10n?.editorBookableAsWhole ?? 'Bookable as a whole',
                ),
                value: bookable,
                onChanged: (v) => setSheetState(() => bookable = v),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n?.commonSave ?? 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
    if (saved != true) return;
    await ref.read(floorPlanRepositoryProvider).updateOffice(
          office.copyWith(
            name: name.text.trim().isEmpty ? office.name : name.text.trim(),
            bookableAsWhole: bookable,
          ),
        );
    ref.invalidate(floorPlanProvider(widget.levelId));
  }

  Future<void> _showDeskSheet(Desk desk) async {
    final l10n = AppLocalizations.of(context);
    final name = await _promptText(
      title: l10n?.editorDeskProperties ?? 'Desk',
      label: l10n?.editorDeskNameLabel ?? 'Desk name',
      initial: desk.name,
    );
    if (name == null || name.isEmpty) return;
    await ref
        .read(floorPlanRepositoryProvider)
        .updateDesk(desk.copyWith(name: name));
    ref.invalidate(floorPlanProvider(widget.levelId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final planAsync = ref.watch(floorPlanProvider(widget.levelId));
    final levelName = ref
            .watch(levelsProvider)
            .value
            ?.where((l) => l.id == widget.levelId)
            .firstOrNull
            ?.name ??
        '';

    return Scaffold(
      appBar: AppBar(title: Text(levelName)),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: SegmentedButton<EditorTool>(
            segments: [
              ButtonSegment(
                value: EditorTool.select,
                icon: const Icon(Icons.pan_tool_alt_outlined),
                label: Text(l10n?.editorToolSelect ?? 'Select'),
              ),
              ButtonSegment(
                value: EditorTool.office,
                icon: const Icon(Icons.meeting_room_outlined),
                label: Text(l10n?.editorToolOffice ?? 'Office'),
              ),
              ButtonSegment(
                value: EditorTool.desk,
                icon: const Icon(Icons.table_restaurant_outlined),
                label: Text(l10n?.editorToolDesk ?? 'Desk'),
              ),
              ButtonSegment(
                value: EditorTool.seat,
                icon: const Icon(Icons.chair_outlined),
                label: Text(l10n?.editorToolSeat ?? 'Seat'),
              ),
              ButtonSegment(
                value: EditorTool.erase,
                icon: const Icon(Icons.backspace_outlined),
                label: Text(l10n?.editorToolErase ?? 'Erase'),
              ),
            ],
            selected: {_tool},
            onSelectionChanged: (selection) {
              _clearSelection();
              setState(() => _tool = selection.first);
            },
          ),
        ),
      ),
      body: switch (planAsync) {
        AsyncData(value: final plan) => _buildCanvas(plan),
        AsyncError() => Center(
            child: Text(
              l10n?.workspaceGenericError ??
                  'Something went wrong. Please try again.',
            ),
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
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
    final selecting = _tool == EditorTool.select && _selectedId != null;
    final shownPlan = _draft ?? plan;

    return InteractiveViewer(
      constrained: false,
      minScale: 0.4,
      maxScale: 3,
      panEnabled: !drawing && !selecting,
      scaleEnabled: !drawing && !selecting,
      boundaryMargin: const EdgeInsets.all(200),
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
            plan: shownPlan,
            cellSize: GridCanvas.cellSize,
            colorScheme: Theme.of(context).colorScheme,
            marquee: _marquee,
            marqueeValid: _marqueeValid,
            selection: _selectionRect(shownPlan),
            selectionResizable: _selectedKind != ElementKind.seat,
            selectionValid: _draftValid,
          ),
        ),
      ),
    );
  }
}
