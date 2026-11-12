// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3607 (desk K2) — a list with its record beside it. On a large window the
// open record stands in a pane beside the list (440 wide, resized between
// 360 and 640 by its edge, the width kept on the device); the list is the
// same widget whether the pane is open or not, so its scroll, filter and
// selection survive. Escape closes the pane and gives the keyboard back to
// what had it before the pane opened (the row). Below large the record is a
// page of its own, opened by the route (list_detail_route.dart).
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/context_l10n.dart';
import '../../shortcuts/app_shortcuts.dart';
import '../../storage/pane_width_store.dart';
import '../../trace/trace_logger.dart';

/// The pane's widths.
abstract final class ListDetailMetrics {
  /// The pane as it opens the first time.
  static const double pane = 440;

  /// The narrowest and widest a person can drag the pane.
  static const double paneMin = 360;
  static const double paneMax = 640;

  /// What the list keeps beside an open pane, whatever the pane's width.
  static const double listMin = 400;

  /// The grip between the list and the pane.
  static const double grip = 8;
}

/// The list, and while [selected] is set, its record beside it.
class ListDetailScaffold extends StatefulWidget {
  const ListDetailScaffold({
    required this.id,
    required this.list,
    required this.selected,
    required this.detail,
    required this.onClose,
    required this.paneStore,
    this.listMin = ListDetailMetrics.listMin,
    this.order,
    this.onMove,
    super.key,
  });

  /// Names the list, for the pane width kept on the device.
  final String id;
  final Widget list;

  /// The open record's id; null shows the list alone.
  final String? selected;
  final Widget Function(BuildContext context, String id) detail;

  /// Closes the pane: the route goes back to the list's own address.
  final VoidCallback onClose;

  /// Where the pane's width is kept (`paneWidthStoreProvider` in the app).
  final PaneWidthStore paneStore;

  /// The narrowest the list keeps beside the pane: its table without a
  /// word cut. Narrower, the pane stands over the list's end.
  final double listMin;

  /// The records in the order the list shows them, read when an arrow key
  /// is pressed; with [onMove], ↑ and ↓ move the open record along it.
  final List<String> Function()? order;

  /// Shows the record [id] instead of the open one (no new history entry).
  final ValueChanged<String>? onMove;

  @override
  State<ListDetailScaffold> createState() => _ListDetailScaffoldState();
}

class _ListDetailScaffoldState extends State<ListDetailScaffold> {
  final _width = ValueNotifier<double>(ListDetailMetrics.pane);

  /// What had the keyboard when the pane opened: it gets it back on close.
  FocusNode? _before;

  /// The scaffold's own place for the keyboard: a record opened by a click
  /// still hears Escape and the arrow keys.
  final _own = FocusNode(debugLabel: 'list detail', skipTraversal: true);

  @override
  void initState() {
    super.initState();
    if (widget.selected != null) {
      _before = FocusManager.instance.primaryFocus;
      _takeKeys();
    }
    unawaited(_readWidth());
  }

  /// The width kept on the device. The width is a convenience: when it
  /// cannot be read the pane opens at its default, and the log says so once.
  Future<void> _readWidth() async {
    try {
      final w = double.tryParse(await widget.paneStore.read(widget.id) ?? '');
      if (!mounted || w == null) return;
      _width.value = w.clamp(
        ListDetailMetrics.paneMin,
        ListDetailMetrics.paneMax,
      );
    } on Object catch (e, st) {
      TraceLogger.instance.warn(
        'ui',
        'the pane width of ${widget.id} was not read; the default stands',
        error: e,
        stackTrace: st,
      );
    }
  }

  @override
  void didUpdateWidget(ListDetailScaffold old) {
    super.didUpdateWidget(old);
    if (old.selected == null && widget.selected != null) {
      _before = FocusManager.instance.primaryFocus;
      _takeKeys();
    }
    if (old.selected != null && widget.selected == null) _giveBack();
  }

  /// The keyboard comes to the scaffold when it is nowhere inside it.
  void _takeKeys() => WidgetsBinding.instance.addPostFrameCallback((_) {
    final now = FocusManager.instance.primaryFocus;
    final inside = now != null && (now == _own || now.ancestors.contains(_own));
    if (mounted && !inside) _own.requestFocus();
  });

  /// Closing gives the keyboard back to what had it: the row it was on
  /// when Escape was pressed, else the row it was on when the pane opened.
  void _close() {
    final now = FocusManager.instance.primaryFocus;
    if (now != null && !_inPane(now)) _before = now;
    widget.onClose();
  }

  bool _inPane(FocusNode node) =>
      node.context?.findAncestorWidgetOfExactType<_Pane>() != null;

  void _giveBack() {
    final back = _before;
    _before = null;
    if (back == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (back.context != null && back.canRequestFocus) back.requestFocus();
    });
  }

  @override
  void dispose() {
    _own.dispose();
    _width.dispose();
    super.dispose();
  }

  void _drag(DragUpdateDetails d, double room) {
    final dx = Directionality.of(context) == TextDirection.rtl
        ? d.delta.dx
        : -d.delta.dx;
    _width.value = (_width.value + dx).clamp(
      ListDetailMetrics.paneMin,
      math.max(ListDetailMetrics.paneMin, room),
    );
  }

  /// ↑ ↓ while a record is open: the record before or after it in the list.
  void _move(int by) {
    final at = widget.selected;
    final order = widget.order?.call() ?? const <String>[];
    final move = widget.onMove;
    final i = at == null ? -1 : order.indexOf(at);
    if (move == null || i < 0) return;
    final next = i + by;
    if (next < 0 || next >= order.length) return;
    move(order[next]);
  }

  void _keep() => widget.paneStore
      .write(widget.id, _width.value.round().toString())
      .ignore();

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return LayoutBuilder(
      builder: (context, box) {
        // The widest the pane may be beside the list: the list keeps its
        // minimum. Where even the narrowest pane does not fit beside it, the
        // pane stands over the list's end instead.
        final room = math.min(
          ListDetailMetrics.paneMax,
          box.maxWidth - widget.listMin - ListDetailMetrics.grip,
        );
        final beside = room >= ListDetailMetrics.paneMin; // content-fit: the list and the narrowest pane side by side
        return CallbackShortcuts(
          // Escape closes the record wherever the keyboard is, in the list
          // (on the row it moves with) or in the pane. The wrapper is always
          // there, so the list's place in the tree never changes.
          bindings: {
            if (selected != null) ...{
              // #3610 — the registry's close key.
              ...shortcutBindings({AppShortcutId.close: _close}),
              const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                  _move(-1),
              const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                  _move(1),
            },
          },
          child: Focus(
            focusNode: _own,
            child: ValueListenableBuilder<double>(
              valueListenable: _width,
              builder: (context, kept, _) {
                final pane = beside
                    ? math.min(kept, room)
                    : math.min(kept, box.maxWidth);
                final taken = selected != null && beside
                    ? pane + ListDetailMetrics.grip
                    : 0.0;
                return Stack(
                  children: [
                    // Always the first child: the list keeps its state when
                    // the pane opens and closes.
                    PositionedDirectional(
                      start: 0,
                      top: 0,
                      bottom: 0,
                      end: taken,
                      child: KeyedSubtree(
                        key: const ValueKey('list-detail-list'),
                        child: widget.list,
                      ),
                    ),
                    if (selected != null)
                      PositionedDirectional(
                        end: 0,
                        top: 0,
                        bottom: 0,
                        width: beside ? pane + ListDetailMetrics.grip : pane,
                        child: Material(
                          elevation: beside ? 0 : _overElevation,
                          child: Row(
                            children: [
                              if (beside)
                                _Grip(
                                  onDrag: (d) => _drag(d, room),
                                  onEnd: _keep,
                                  label: context.l10n.listDetailResize,
                                ),
                              Expanded(
                                child: _Pane(
                                  child: FocusScope(
                                    key: const ValueKey('list-detail-pane'),
                                    child: KeyedSubtree(
                                      key: ValueKey(
                                        'list-detail-record-$selected',
                                      ),
                                      child: widget.detail(context, selected),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// The lift of a pane drawn over the list's end.
const double _overElevation = 8;

/// Marks the pane, to tell a focus inside it from one in the list.
class _Pane extends StatelessWidget {
  const _Pane({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// The pane's edge: a rule a mouse drags to resize the pane.
class _Grip extends StatelessWidget {
  const _Grip({required this.onDrag, required this.onEnd, required this.label});

  final GestureDragUpdateCallback onDrag;
  final VoidCallback onEnd;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        key: const ValueKey('list-detail-grip'),
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: onDrag,
        onHorizontalDragEnd: (_) => onEnd(),
        child: const SizedBox(
          width: ListDetailMetrics.grip,
          child: VerticalDivider(width: ListDetailMetrics.grip),
        ),
      ),
    ),
  );
}
