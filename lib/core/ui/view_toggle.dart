// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

/// One selectable view of a [ViewToggle].
///
/// [icon] is mandatory — the toggle's shared visual language (#211) is
/// icon-first. Compact headers pass a [tooltip] and no [label]; toggles
/// with room (the Reserve hub) pass a visible [label] instead, which
/// already names the segment for assistive tech.
class ViewToggleOption<T> {
  const ViewToggleOption({
    required this.value,
    required this.icon,
    this.tooltip,
    this.label,
  }) : assert(
          tooltip != null || label != null,
          'An icon-only segment needs a tooltip to stay accessible.',
        );

  /// Value reported through [ViewToggle.onChanged]; unique per toggle.
  final T value;

  /// The segment's icon (shared icon set: map/list/timeline/week).
  final IconData icon;

  /// Localized tooltip for icon-only segments.
  final String? tooltip;

  /// Optional localized visible label next to the icon.
  final String? label;
}

/// The one view-switch idiom (#211, epic #205): a single-select
/// [SegmentedButton] with icons (plus tooltips or labels), used by the
/// Plan header (canvas/list), the Calendar header (list/timeline) and the
/// Reserve hub (Plan/Day/Week) instead of three home-grown toggles.
///
/// Sizing deliberately stays at the Material defaults: with the ambient
/// [MaterialTapTargetSize.padded] the button's hit area meets the 48dp
/// Material minimum — never pass a compact [VisualDensity] here, it would
/// shrink the tap target below that.
///
/// Callers pass their EXISTING localized strings as tooltips/labels —
/// this widget introduces no text of its own.
class ViewToggle<T> extends StatelessWidget {
  const ViewToggle({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  /// The selectable views, in display order (2–5 per Material guidance).
  final List<ViewToggleOption<T>> options;

  /// The currently active view; always exactly one.
  final T selected;

  /// Called with the newly chosen view. Re-selecting the active segment
  /// does not fire (single-select semantics).
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    // Material defaults on purpose: an icon-only segment already measures
    // ~48dp square (the padded tap target inflates the 40dp visual), so
    // the toggle stays barely wider than the IconButton pair it replaces.
    return SegmentedButton<T>(
      showSelectedIcon: false,
      segments: [
        for (final option in options)
          ButtonSegment<T>(
            value: option.value,
            icon: Icon(option.icon),
            label: option.label == null ? null : Text(option.label!),
            tooltip: option.tooltip,
          ),
      ],
      selected: {selected},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}
