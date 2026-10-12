// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'level_canvas_screen.dart';

// #2386 — part 1 of _LevelCanvasScreenState, split out of level_canvas_screen.dart so no
// file holds the whole class.
extension _LevelCanvasScreenStatePart1 on _LevelCanvasScreenState {

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

  void _clearSelection() => _update(() {
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
    _update(() {
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
    _update(() {
      _draft = draft;
      _draftValid = validateElement(draft, kind, id) == null;
    });
  }

  Future<void> _onSelectPanEnd(FloorPlan plan) async {
    final draft = _draft;
    final kind = _selectedKind;
    final id = _selectedId;
    _update(() {
      _dragStart = null;
      _dragEdges = null;
    });
    if (draft == null || kind == null || id == null) return;
    final problem = validateElement(draft, kind, id);
    if (problem != null) {
      _update(() {
        _draft = null;
        _draftValid = true;
      });
      showPlacementProblem(context, problem);
      return;
    }
    await _persistDiff(plan, draft);
    _update(() {
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
    final l10n = context.l10n;
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final repo = ref.read(floorPlanRepositoryProvider);

    final problem = _validate(plan, rect);
    if (problem != null) {
      showPlacementProblem(context, problem);
      return;
    }

    if (_tool == EditorTool.office) {
      final name = await showTextPrompt(
        context,
        title: l10n.editorNewOffice,
        label: l10n.editorOfficeNameLabel,
        initial: '${l10n.editorOfficeNameDefault} '
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
        name: '${l10n.editorDeskNameDefault} '
            '${plan.desksOf(office.id).length + 1}',
        rect: rect,
      );
    }
    ref.invalidate(floorPlanProvider(widget.levelId));
  }

  Future<void> _placeSeat(FloorPlan plan, ({int x, int y}) cell) async {
    final l10n = context.l10n;
    final workspace = ref.read(currentWorkspaceProvider).value;
    final desk = plan.deskAtCell(cell.x, cell.y);
    if (workspace == null) return;
    if (desk == null) {
      AppSnack.error(
        context,
        l10n.editorSeatNoDesk,
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
          name: '${l10n.editorSeatNameDefault} '
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
    _update(() {
      _selectedKind = kind;
      _selectedId = id;
      _draft = null;
      _draftValid = true;
    });
  }

  Future<void> _showOfficeSheet(Office office) async {
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
    final bytes = await file.readAsBytes();
    final contentType = file.mimeType ??
        (file.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');
    // #2012 C — one id for this image, kept across a "Try again".
    final imageId = newRequestId();
    if (!context.mounted) return;
    await runPlanMediaWrite(
      context,
      busy: _mediaBusy,
      trace: 'place image failed',
      write: () => ref.read(floorPlanRepositoryProvider).createPlanImage(
            workspaceId: workspace.id,
            levelId: widget.levelId,
            rect: GridRect(x: x, y: y, w: w, h: h),
            bytes: bytes,
            contentType: contentType,
            imageId: imageId,
          ),
      onDone: () {
        ref.invalidate(floorPlanProvider(widget.levelId));
        // Back to the resting state so the fresh image can be moved or
        // resized at once.
        if (mounted) _update(() => _tool = null);
      },
    );
  }
}
