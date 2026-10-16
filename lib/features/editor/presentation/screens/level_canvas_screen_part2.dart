// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'level_canvas_screen.dart';

// #2386 — part 2 of _LevelCanvasScreenState, split out of level_canvas_screen.dart so no
// file holds the whole class.
extension _LevelCanvasScreenStatePart2 on _LevelCanvasScreenState {

  /// Owner picks a photo/blueprint of the real space as this level's
  /// background (0036); it's uploaded and painted behind the grid.
  Future<void> _pickBackground(BuildContext context) async {
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    const group = XTypeGroup(
      label: 'images',
      extensions: ['png', 'jpg', 'jpeg', 'webp'],
      mimeTypes: ['image/png', 'image/jpeg', 'image/webp'],
    );
    final file = await ref.read(filePickerProvider)(group);
    if (file == null || !context.mounted) return;
    final bytes = await file.readAsBytes();
    final contentType = file.mimeType ??
        (file.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');
    if (!context.mounted) return;
    await runPlanMediaWrite(
      context,
      busy: _mediaBusy,
      trace: 'set background failed',
      write: () => ref.read(floorPlanRepositoryProvider).setLevelBackground(
            workspace.id,
            widget.levelId,
            bytes: bytes,
            contentType: contentType,
          ),
      onDone: _backgroundChanged,
    );
  }

  void _backgroundChanged() => ref
    ..invalidate(levelsProvider)
    ..invalidate(levelBackgroundProvider(widget.levelId));

  Future<void> _removeBackground(BuildContext context) async {
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    await runPlanMediaWrite(
      context,
      busy: _mediaBusy,
      trace: 'remove background failed',
      write: () => ref
          .read(floorPlanRepositoryProvider)
          .clearLevelBackground(workspace.id, widget.levelId),
      onDone: _backgroundChanged,
    );
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
    final l10n = context.l10n;
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
        l10n.editorDeskFull,
        replace: true,
      );
      return;
    }
    final repo = ref.read(floorPlanRepositoryProvider);
    final name = '${l10n.editorSeatNameDefault} ${siblings.length + 1}';
    if (seat.resourceKind == ResourceKind.seat) {
      await repo.createSeat(
        workspaceId: workspace.id,
        deskId: desk.id,
        name: name,
        x: free.x,
        y: free.y,
        orientation: seat.orientation,
      );
    } else {
      // #2631 — a copy keeps what the original is.
      await placeResource(
        ref,
        workspaceId: workspace.id,
        deskId: desk.id,
        name: name,
        anchor: free,
        resource: (
          kind: seat.resourceKind,
          parking: seat.parkingKind,
          capacity: seat.capacity,
        ),
      );
    }
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
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: AppSpacing.xlAll,
        child: SingleChildScrollView(
          primary: false,
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
                    l10n.editorEmptyFloorTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.editorEmptyFloorBody,
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    key: const ValueKey('editor-empty-floor-start'),
                    onPressed: () =>
                        _update(() => _tool = EditorTool.office),
                    icon: const Icon(Icons.add),
                    label: Text(
                      l10n.editorEmptyFloorAction,
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
    final l10n = context.l10n;
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
      child: Semantics(
        // #1235 — the drawing surface used to reach a screen reader as
        // an anonymous button the size of the floor: a tap action with
        // no name, and a coordinate nobody navigating by voice can aim
        // at. It is a canvas, so it says so, and the objects on it are
        // reached through the objects panel instead.
        label: l10n.editorCanvasSemantics,
        child: GestureDetector(
        excludeFromSemantics: true,
        // `down` so onPanStart reports the touch-down cell, not the position
        // where the drag cleared the touch slop.
        dragStartBehavior: DragStartBehavior.down,
        onTapUp: (details) => _handleTap(plan, details.localPosition),
        onPanStart: drawing
            ? (details) {
                final cell = _cellAt(details.localPosition);
                _update(() {
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
                _update(() {
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
                _update(() {
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
                onCancel: () => _update(() => _tool = null),
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
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.commonDelete),
        content: Text(deleteElementConfirmText(ref, l10n)),
        actions: [
          TextButton(
            key: const ValueKey('level-canvas-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            key: const ValueKey('level-canvas-delete'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await action();
    ref.invalidate(floorPlanProvider(widget.levelId));
  }
}
