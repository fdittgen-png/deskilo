// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3626 (desk M7) — a stretch of free time on a place's row: a target that
// opens New booking at the minute it was clicked. The keyboard activates it at
// the stretch's start. It covers only the free stretch, never a booking.
import 'package:flutter/material.dart';

/// A free stretch of a row, [pixelsPerMinute] wide per minute.
class DeskFreeRegion extends StatefulWidget {
  const DeskFreeRegion({
    required this.regionKey,
    required this.label,
    required this.pixelsPerMinute,
    required this.onChosen,
    this.focusable = true,
    super.key,
  });

  final Key regionKey;
  final String label;
  final double pixelsPerMinute;

  /// The chosen point, in minutes from the start of the stretch.
  final ValueChanged<int> onChosen;

  /// Whether Tab stops here. The week's many empty cells are not stops: the
  /// keyboard opens New booking with N or the button.
  final bool focusable;

  @override
  State<DeskFreeRegion> createState() => _DeskFreeRegionState();
}

class _DeskFreeRegionState extends State<DeskFreeRegion> {
  /// Where the pointer last went down, in pixels from the region's start;
  /// null for a keyboard activation.
  double? _down;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: widget.label,
    excludeSemantics: true,
    child: InkWell(
      key: widget.regionKey,
      canRequestFocus: widget.focusable,
      onTapDown: (d) => _down = d.localPosition.dx,
      onTap: () {
        final dx = _down;
        _down = null;
        widget.onChosen(
          dx == null || widget.pixelsPerMinute <= 0
              ? 0
              : (dx / widget.pixelsPerMinute).floor(),
        );
      },
      onTapCancel: () => _down = null,
      child: const SizedBox.expand(),
    ),
  );
}
