// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals, mapEquals, setEquals;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../core/theme/office_colors.dart';
import '../../../../core/theme/seat_state_colors.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../reservations/domain/seat_state_logic.dart';
import '../../domain/floor_plan.dart';
import '../../domain/grid_geometry.dart';
import '../../domain/seat.dart';
import 'drop_target_paint.dart';
import 'plan_paint_helpers.dart';
import 'seat_identifier_paint.dart';

part 'floor_plan_painter_part1.dart';
part 'floor_plan_painter_part2.dart';

/// Paints a level's grid, offices, desks and seats. Shared by the editor
/// canvas (#34/#35) and the live floor plan (Epic #4): passing [seatStates]
/// switches seats to live state colors + occupant labels.
class FloorPlanPainter extends CustomPainter {

  /// #1289 — the workspace's own office fills, empty for the product's.
  final List<Color> officePalette;

  FloorPlanPainter({
    required this.plan,
    required this.cellSize,
    required this.colorScheme,
    this.brightness = Brightness.light,
    this.background,
    this.images = const {},
    this.seatStates,
    this.labelScale = 1,
    this.identifierStyle,
    this.seatDaySegments = const {},
    this.previousSeatStates,
    this.seatStateLerp = 1,
    this.seatDayPhases = const {},
    this.seatLabels,
    this.seatPhotos = const {},
    this.highlightedSeatId,
    this.highlightedDeskId,
    this.highlightedOfficeId,
    this.highlightLevel = false,
    this.deskOpacity = 1,
    this.officePalette = const [],
    this.spaceOverlays,
    this.onlineSeatIds = const {},
    this.semanticLabels,
    this.semanticsDirection = TextDirection.ltr,
    this.onSeatSemanticTap,
    this.marquee,
    this.marqueeValid = true,
    this.selection,
    this.selectionResizable = false,
    this.selectionValid = true,
    this.dropTargets,
    this.singleRoomByLevel = false,
  });

  /// #1273 — a level's only room carries no name on the canvas (the
  /// singleRoomLevelNames feature). False in the editor, where the owner
  /// manipulates the real rooms and must see them.
  final bool singleRoomByLevel;

  final FloorPlan plan;
  final double cellSize;
  final double labelScale;
  final TextStyle? identifierStyle;
  final ColorScheme colorScheme;
  final Brightness brightness;

  /// Optional background image (0036): a photo/blueprint of the real
  /// space, painted behind the grid at reduced opacity so seats stay
  /// legible on top. Null = schematic only.
  final ui.Image? background;

  /// Illustration images (0037): image id → decoded bitmap, drawn at the
  /// element's grid rect above the background and below the schematic.
  final Map<String, ui.Image> images;

  /// Live mode: seat id → state. Null = editor mode (uniform styling).
  final Map<String, SeatState>? seatStates;

  /// #903 — the day's taken stretches per seat. A seat whose day is only
  /// PARTLY taken is filled only over those stretches, the horizontal
  /// axis being the open day: a morning booking fills the left half. A
  /// seat held all day fills whole, exactly as before.
  final Map<String, List<SeatDaySegment>> seatDaySegments;

  /// Motion pass (#611): the state a just-changed seat had BEFORE, only
  /// for seats currently animating — the seat's colour lerps from the
  /// old state's to the new one's by [seatStateLerp]. Null/absent seat
  /// = paint the current state directly.
  final Map<String, SeatState>? previousSeatStates;

  /// 0..1 progress of the state-colour lerp; 1 (the default) paints the
  /// final state exactly. Driven by the host widget's finite animation.
  final double seatStateLerp;

  /// The browsed day's per-seat phase (#575): the painter rings a seat
  /// whose day already held a booking (grey), holds one right now
  /// (green) or still holds one ahead (light green) — the at-a-glance
  /// answer to "did/does/will anything happen here today".
  final Map<String, SeatDayPhase> seatDayPhases;

  /// Live mode: seat id → occupant display name (empty = no label).
  final Map<String, String>? seatLabels;

  /// Occupant profile photos (#618): seat id → decoded bitmap, drawn
  /// clipped inside the marker circle instead of the initial.
  final Map<String, ui.Image> seatPhotos;

  /// Whole-space overlays (#462): office/desk id → reserved state +
  /// occupant first name. The rect tints in the state colour, the
  /// border takes the accent, and an office shows "name · occupant".
  final Map<String, ({SeatState state, String label})>? spaceOverlays;

  /// Seat to ring with a thick tertiary outline (#182): the calendar's
  /// "Show on plan" jump points at the reserved seat. Null = no highlight.
  final String? highlightedSeatId;

  /// #576 — the space "Show on plan" targeted: the tertiary ring the
  /// seat jump always had, now for tables, offices and the whole floor.
  final String? highlightedDeskId;
  final String? highlightedOfficeId;
  final bool highlightLevel;

  /// Desk fill opacity 0..1 (0040): 1 = solid (default); lower makes desks
  /// translucent so a background photo shows through. The desk border stays
  /// opaque so the table is still locatable over the image.
  final double deskOpacity;

  /// Seat ids whose occupant is currently online (presence heartbeat): the
  /// seat avatar gets a green online dot. Live mode only.
  final Set<String> onlineSeatIds;

  /// A11y (#402): seat id → the full localized label a screen reader
  /// announces ("A1 · free", "A1 · occupied — Ana"). Null = no semantics
  /// (the editor's schematic mode). Composed by the CALLER, which has the
  /// l10n context this painter deliberately does not.
  final Map<String, String>? semanticLabels;

  /// Reading direction of the semantic labels — a labeled node without
  /// one is a framework assertion. The caller passes the ambient
  /// Directionality so RTL locales read correctly if ever added.
  final TextDirection semanticsDirection;

  /// Tap action exposed through the semantics node — the same handler the
  /// canvas's gesture detector resolves by cell math, so TalkBack's
  /// double-tap opens the same sheet a touch does. Excluded from
  /// [shouldRepaint]: callbacks never change what is painted.
  final ValueChanged<Seat>? onSeatSemanticTap;

  /// In-progress drag rectangle (grid cells) while drawing a new element.
  final GridRect? marquee;

  /// #1216 — where the armed editor tool may legally place its next
  /// element: the offices a desk can go in, the desks a seat can go on.
  ///
  /// The rules were enforced all along and shown only after a failed
  /// drag, as "Must be fully inside an office." in a snackbar. The
  /// editor knows the answer before the gesture, so it says it before
  /// the gesture: the listed rectangles keep their colour and get an
  /// accent ring, and everything else is washed out.
  ///
  /// Null = no tool armed, nothing dimmed. EMPTY is meaningful and not
  /// the same thing: a tool is armed and there is nowhere legal to put
  /// it, so the whole floor dims and the answer is visible rather than
  /// waiting behind a drag.
  final Set<String>? dropTargets;
  final bool marqueeValid;

  /// Editor selection (#101): highlighted rect, resize handles when the
  /// element kind allows resizing, error tint while a drag breaks rules.
  final GridRect? selection;
  final bool selectionResizable;
  final bool selectionValid;

  bool get _labelsOffices => plan.labelsOffices(byLevel: singleRoomByLevel);

  // #2386 — the operations; each body is in a part file.
  @override void paint(Canvas canvas, Size size) => _paintImpl(canvas, size);
  @override bool shouldRepaint(FloorPlanPainter oldDelegate) => _shouldRepaintImpl(oldDelegate);
  @override bool shouldRebuildSemantics(FloorPlanPainter oldDelegate) => _shouldRebuildSemanticsImpl(oldDelegate);
  @override SemanticsBuilderCallback? get semanticsBuilder => _semanticsBuilderImpl;

}

/// Map equality for the day segments: `mapEquals` compares lists by
/// identity, which would repaint the whole plan on every build (#903).
bool _sameSegments(Map<String, List<SeatDaySegment>> a,
    Map<String, List<SeatDaySegment>> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    final other = b[entry.key];
    if (other == null || other.length != entry.value.length) return false;
    for (var i = 0; i < other.length; i++) {
      if (other[i] != entry.value[i]) return false;
    }
  }
  return true;
}
