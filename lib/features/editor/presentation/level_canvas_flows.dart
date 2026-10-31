// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2494 — the level canvas's questions before a write: the new office's
// name and kind, the new seat's resource, the office or desk properties,
// the picture or background file. Each flow asks, then hands the answer
// to [LevelCanvasEdits] and refreshes the plan; the screen keeps the
// gestures and the selection.
import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/files/file_picker.dart';
import '../../../core/ids/request_id.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/ui/app_snack.dart';
import '../../plan/domain/desk.dart';
import '../../plan/domain/floor_plan.dart';
import '../../plan/domain/floor_plan_editing.dart';
import '../../plan/domain/floor_plan_rules.dart';
import '../../plan/domain/grid_geometry.dart';
import '../../plan/domain/office.dart';
import '../../plan/domain/seat.dart';
import '../../plan/presentation/widgets/plan_canvas.dart';
import '../../plan/providers/floor_plan_providers.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../application/level_canvas_edits.dart';
import '../application/level_canvas_rules.dart';
import 'plan_media_write.dart';
import 'widgets/placement_problem.dart';
import 'widgets/seat_properties_sheet.dart';
import 'widgets/space_properties_sheet.dart';
import 'widgets/text_prompt_dialog.dart';

/// The image types a plan picture or background may be.
const XTypeGroup _imageTypes = XTypeGroup(
  label: 'images',
  extensions: ['png', 'jpg', 'jpeg', 'webp'],
  mimeTypes: ['image/png', 'image/jpeg', 'image/webp'],
);

class LevelCanvasFlows {
  const LevelCanvasFlows(this._ref, {required this.edits, required this.busy});

  final WidgetRef _ref;
  final LevelCanvasEdits edits;

  /// #2012 C — a plan-media write is in flight (progress; no second one).
  final ValueNotifier<bool> busy;

  String get _levelId => edits.levelId;

  String? get _workspaceId => _ref.read(currentWorkspaceProvider).value?.id;

  void _refresh() => _ref.invalidate(floorPlanProvider(_levelId));

  /// Names a new office (or parking area) drawn as [rect] and creates it.
  Future<void> createOffice(
    BuildContext context,
    FloorPlan plan,
    GridRect rect,
  ) async {
    final workspaceId = _workspaceId;
    if (workspaceId == null) return;
    final l10n = context.l10n;
    final name = await showTextPrompt(
      context,
      title: l10n.editorNewOffice,
      label: l10n.editorOfficeNameLabel,
      initial:
          '${l10n.editorOfficeNameDefault} '
          '${plan.offices.length + 1}',
    );
    if (name == null || name.isEmpty) return;
    if (!context.mounted) return;
    final areaKind = await chooseAreaKind(context, resourceFlagsOf(_ref));
    if (areaKind == null) return;
    if (areaKind == AreaKind.parking) {
      await placeParkingArea(
        _ref,
        workspaceId: workspaceId,
        levelId: _levelId,
        name: name,
        color: plan.offices.length,
        rect: rect,
      );
    } else {
      await edits.createOffice(
        workspaceId,
        name: name,
        color: plan.offices.length,
        rect: rect,
      );
    }
    _refresh();
  }

  /// A desk drawn as [rect] inside the office under its corner.
  Future<void> createDesk(
    BuildContext context,
    FloorPlan plan,
    GridRect rect,
  ) async {
    final workspaceId = _workspaceId;
    if (workspaceId == null) return;
    final office = plan.officeAtCell(rect.x, rect.y)!;
    await edits.createDesk(
      workspaceId,
      officeId: office.id,
      name:
          '${context.l10n.editorDeskNameDefault} '
          '${plan.desksOf(office.id).length + 1}',
      rect: rect,
    );
    _refresh();
  }

  /// Places a seat (or a meeting room or parking slot) on the desk under
  /// [cell].
  Future<void> placeSeat(
    BuildContext context,
    FloorPlan plan,
    CanvasCell cell,
  ) async {
    final workspaceId = _workspaceId;
    final desk = plan.deskAtCell(cell.x, cell.y);
    if (workspaceId == null) return;
    if (desk == null) {
      AppSnack.error(context, context.l10n.editorSeatNoDesk, replace: true);
      return;
    }
    const orientation = SeatOrientation.n;
    final anchor = clampSeatAnchor(desk, cell.x, cell.y, orientation);
    if (anchor == null) {
      showPlacementProblem(context, PlacementProblem.outsideParent);
      return;
    }
    final candidate = seatCandidate(
      desk,
      anchor,
      workspaceId: workspaceId,
      orientation: orientation,
    );
    final problem = validateSeatPlacement(
      candidate,
      desk,
      plan.seatsOf(desk.id),
    );
    if (problem != null) {
      showPlacementProblem(context, problem);
      return;
    }
    final placed = await chooseNewResource(
      context,
      resourceFlagsOf(_ref),
      plan: plan,
      desk: desk,
    );
    if (placed == null) return;
    await _createSeat(
      (workspaceId: workspaceId, desk: desk, anchor: anchor),
      orientation: orientation,
      name: '${placed.namePrefix} ${plan.seatsOf(desk.id).length + 1}',
      resource: placed.resource,
    );
  }

  /// #1216 — the repetitive act this editor exists for. A six-seat table
  /// is six identical placements, and doing them by hand means six taps
  /// on a desk plus six trips through the naming default. Duplicating
  /// puts the copy on the first free cell of the same desk, so the
  /// second seat costs one tap and the sixth costs one tap.
  Future<void> duplicateSeat(
    BuildContext context,
    FloorPlan plan,
    String? seatId,
  ) async {
    final l10n = context.l10n;
    final seat = plan.seats.where((s) => s.id == seatId).firstOrNull;
    final workspaceId = _workspaceId;
    if (seat == null || workspaceId == null) return;
    final desk = plan.desks.where((d) => d.id == seat.deskId).firstOrNull;
    if (desk == null) return;
    final free = firstFreeSeatAnchor(plan, desk, seat);
    if (free == null) {
      AppSnack.info(context, l10n.editorDeskFull, replace: true);
      return;
    }
    await _createSeat(
      (workspaceId: workspaceId, desk: desk, anchor: free),
      orientation: seat.orientation,
      name: '${l10n.editorSeatNameDefault} ${plan.seatsOf(desk.id).length + 1}',
      // #2631 — a copy keeps what the original is.
      resource: seat.resourceKind == ResourceKind.seat
          ? null
          : (
              kind: seat.resourceKind,
              parking: seat.parkingKind,
              capacity: seat.capacity,
            ),
    );
  }

  /// Creates a seat at the spot [at] names, or the meeting room or
  /// parking slot [resource] names, and refreshes the plan.
  Future<void> _createSeat(
    ({String workspaceId, Desk desk, CanvasCell anchor}) at, {
    required SeatOrientation orientation,
    required String name,
    required NewResource? resource,
  }) async {
    if (resource == null) {
      await edits.createSeat(
        at.workspaceId,
        deskId: at.desk.id,
        name: name,
        anchor: at.anchor,
        orientation: orientation,
      );
    } else {
      await placeResource(
        _ref,
        workspaceId: at.workspaceId,
        deskId: at.desk.id,
        name: name,
        anchor: at.anchor,
        resource: resource,
      );
    }
    _refresh();
  }

  /// Opens the properties of the element [kind]/[id] on [plan]. An image
  /// has none.
  Future<void> editElement(
    BuildContext context,
    FloorPlan plan,
    ElementKind? kind,
    String? id,
  ) async {
    switch (kind) {
      case ElementKind.seat:
        final seat = plan.seats.where((s) => s.id == id).firstOrNull;
        if (seat != null) {
          await showSeatPropertiesSheet(
            context,
            _ref,
            levelId: _levelId,
            plan: plan,
            seat: seat,
          );
        }
      case ElementKind.desk:
        final desk = plan.desks.where((d) => d.id == id).firstOrNull;
        if (desk != null) await _editDesk(context, desk);
      case ElementKind.office:
        final office = plan.offices.where((o) => o.id == id).firstOrNull;
        if (office != null) await _editOffice(context, office);
      case ElementKind.image:
      case null:
        break;
    }
  }

  Future<void> _editOffice(BuildContext context, Office office) async {
    final l10n = context.l10n;
    final props = await showSpacePropertiesSheet(
      context,
      title: l10n.editorOfficeProperties,
      nameLabel: l10n.editorOfficeNameLabel,
      name: office.name,
      bookable: office.bookableAsWhole,
      priceCents: office.priceCents,
      keyPrefix: 'office',
    );
    if (props == null) return;
    await edits.updateOffice(
      office.copyWith(
        name: props.name,
        bookableAsWhole: props.bookable,
        priceCents: props.priceCents,
      ),
    );
    _refresh();
  }

  Future<void> _editDesk(BuildContext context, Desk desk) async {
    final l10n = context.l10n;
    final props = await showSpacePropertiesSheet(
      context,
      title: l10n.editorDeskProperties,
      nameLabel: l10n.editorDeskNameLabel,
      name: desk.name,
      bookable: desk.bookableAsWhole,
      priceCents: desk.priceCents,
      keyPrefix: 'desk',
    );
    if (props == null) return;
    await edits.updateDesk(
      desk.copyWith(
        name: props.name,
        bookableAsWhole: props.bookable,
        priceCents: props.priceCents,
      ),
    );
    _refresh();
  }

  /// Reads a picked image file. Null when nothing was picked or the
  /// screen left meanwhile.
  Future<PickedImage?> _pickImage(BuildContext context) async {
    final file = await _ref.read(filePickerProvider)(_imageTypes);
    if (file == null || !context.mounted) return null;
    final bytes = await file.readAsBytes();
    final contentType =
        file.mimeType ??
        (file.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');
    return (bytes: bytes, contentType: contentType);
  }

  /// Adds a resizable illustration image (0037) at [cell]: pick an
  /// image, upload it, and drop it at a default 16×12 rect anchored near
  /// the tap. It draws BELOW the offices/tables/seats, so you can then
  /// place real tables and seats on top of the photo. [onPlaced] runs
  /// after the plan refresh.
  Future<void> placeImage(
    BuildContext context,
    CanvasCell cell, {
    required VoidCallback onPlaced,
  }) async {
    final workspaceId = _workspaceId;
    if (workspaceId == null) return;
    final picked = await _pickImage(context);
    if (picked == null) return;
    const w = 16, h = 12;
    final x = cell.x.clamp(0, PlanCanvasMetrics.cells - w);
    final y = cell.y.clamp(0, PlanCanvasMetrics.cells - h);
    // #2012 C — one id for this image, kept across a "Try again".
    final imageId = newRequestId();
    if (!context.mounted) return;
    await runPlanMediaWrite(
      context,
      busy: busy,
      trace: 'place image failed',
      write: () => edits.createImage(
        workspaceId,
        rect: GridRect(x: x, y: y, w: w, h: h),
        image: picked,
        imageId: imageId,
      ),
      onDone: () {
        _refresh();
        onPlaced();
      },
    );
  }

  /// Draws a [kind] symbol with its top-left cell at [cell]; [onPlaced] runs
  /// after the plan refresh.
  Future<void> placeDecor(
    BuildContext context,
    CanvasCell cell,
    PlanDecorKind kind, {
    GridRect? drawnRect,
    required VoidCallback onPlaced,
  }) async {
    final workspaceId = _workspaceId;
    if (workspaceId == null) return;
    final size = kind.defaultSize;
    final x = cell.x.clamp(0, PlanCanvasMetrics.cells - size.w);
    final y = cell.y.clamp(0, PlanCanvasMetrics.cells - size.h);
    final imageId = newRequestId();
    await runPlanMediaWrite(
      context,
      busy: busy,
      trace: 'place decor failed',
      write: () => edits.createDecor(
        workspaceId,
        kind: kind,
        rect: drawnRect ?? GridRect(x: x, y: y, w: size.w, h: size.h),
        imageId: imageId,
      ),
      onDone: () {
        _refresh();
        onPlaced();
        if (drawnRect != null && context.mounted) _offerWallUndo(context, imageId);
      },
    );
  }

  void _offerWallUndo(BuildContext context, String imageId) {
    AppSnack.success(
      context,
      context.l10n.editorWallSaved,
      replace: true,
      action: SnackBarAction(
        key: const ValueKey('editor-wall-undo'),
        label: context.l10n.editorWallUndo,
        onPressed: () => unawaited(runPlanMediaWrite(
          context,
          busy: busy,
          trace: 'undo wall failed',
          write: () => edits.undoDecor(imageId),
          onDone: _refresh,
        )),
      ),
    );
  }

  /// Owner picks a photo/blueprint of the real space as this level's
  /// background (0036); it's uploaded and painted behind the grid.
  Future<void> pickBackground(BuildContext context) async {
    final workspaceId = _workspaceId;
    if (workspaceId == null) return;
    final picked = await _pickImage(context);
    if (picked == null || !context.mounted) return;
    await runPlanMediaWrite(
      context,
      busy: busy,
      trace: 'set background failed',
      write: () => edits.setBackground(workspaceId, picked),
      onDone: _backgroundChanged,
    );
  }

  Future<void> removeBackground(BuildContext context) async {
    final workspaceId = _workspaceId;
    if (workspaceId == null) return;
    await runPlanMediaWrite(
      context,
      busy: busy,
      trace: 'remove background failed',
      write: () => edits.clearBackground(workspaceId),
      onDone: _backgroundChanged,
    );
  }

  void _backgroundChanged() => _ref
    ..invalidate(levelsProvider)
    ..invalidate(levelBackgroundProvider(_levelId));
}
