// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals, mapEquals, setEquals;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../reservations/domain/seat_state_logic.dart';
import '../../domain/floor_plan.dart';
import '../../domain/grid_geometry.dart';
import '../../domain/seat.dart';
import 'floor_plan_chrome_layers.dart';
import 'floor_plan_space_layers.dart';
import 'plan_paint_helpers.dart';

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

  @override
  void paint(Canvas canvas, Size size) {
    paintFloorPlanBackdrop(canvas, size, this);
    paintFloorPlanOffices(canvas, this);
    paintFloorPlanDesks(canvas, this);
    paintFloorPlanSeats(canvas, this);
    paintFloorPlanHighlights(canvas, size, this);
    paintFloorPlanEditorMarks(canvas, size, this);
  }

  @override
  bool shouldRepaint(FloorPlanPainter oldDelegate) =>
      _structureChanged(oldDelegate) ||
      _seatsChanged(oldDelegate) ||
      _highlightsChanged(oldDelegate);

  /// The plan, its backdrop and the editor's marks.
  bool _structureChanged(FloorPlanPainter old) =>
      old.plan != plan ||
      old.singleRoomByLevel != singleRoomByLevel ||
      old.background != background ||
      // Deep compares on the maps (perf audit): callers rebuild these maps
      // every frame/minute-tick, so identity `!=` was ALWAYS true and every
      // rebuild forced a full canvas repaint — including a TextPainter.layout
      // per seat label — even when nothing changed.
      !mapEquals(old.images, images) ||
      old.marquee != marquee ||
      !setEquals(old.dropTargets, dropTargets) ||
      old.marqueeValid != marqueeValid ||
      old.selection != selection ||
      old.selectionResizable != selectionResizable ||
      old.selectionValid != selectionValid ||
      old.deskOpacity != deskOpacity ||
      !listEquals(old.officePalette, officePalette) ||
      old.cellSize != cellSize;

  /// What the seats and the whole-space overlays show.
  bool _seatsChanged(FloorPlanPainter old) =>
      !mapEquals(old.seatPhotos, seatPhotos) ||
      !mapEquals(old.seatStates, seatStates) ||
      !mapEquals(old.previousSeatStates, previousSeatStates) ||
      old.seatStateLerp != seatStateLerp ||
      !mapEquals(old.seatDayPhases, seatDayPhases) ||
      !_sameSegments(old.seatDaySegments, seatDaySegments) ||
      !mapEquals(old.seatLabels, seatLabels) ||
      !mapEquals(old.spaceOverlays, spaceOverlays) ||
      !setEquals(old.onlineSeatIds, onlineSeatIds) ||
      old.labelScale != labelScale ||
      old.identifierStyle != identifierStyle;

  bool _highlightsChanged(FloorPlanPainter old) =>
      old.highlightedSeatId != highlightedSeatId ||
      old.highlightedDeskId != highlightedDeskId ||
      old.highlightedOfficeId != highlightedOfficeId ||
      old.highlightLevel != highlightLevel;

  // #2307 — a booking can change while the seat still reads "your seat".
  // Semantic actions must then use the new closure, independently of ink.
  @override
  bool shouldRebuildSemantics(FloorPlanPainter oldDelegate) =>
      oldDelegate.plan != plan ||
      oldDelegate.cellSize != cellSize ||
      oldDelegate.semanticsDirection != semanticsDirection ||
      !mapEquals(oldDelegate.semanticLabels, semanticLabels) ||
      oldDelegate.onSeatSemanticTap != onSeatSemanticTap;

  /// One semantics node per seat (#402). Without this, the app's core
  /// surface is a single unlabeled picture to TalkBack/VoiceOver — the
  /// hidden cost of choosing a canvas over widgets, paid here.
  @override
  SemanticsBuilderCallback? get semanticsBuilder {
    final labels = semanticLabels;
    if (labels == null) return null;
    return (Size size) => [
          for (final seat in plan.seats)
            CustomPainterSemantics(
              key: ValueKey('plan-seat-semantics-${seat.id}'),
              rect: gridRectToPx(seat.footprint, cellSize),
              properties: SemanticsProperties(
                label: labels[seat.id] ?? seat.name,
                textDirection: semanticsDirection,
                button: onSeatSemanticTap != null,
                // recorder-key-exempt: the seat's node is keyed above.
                onTap: onSeatSemanticTap == null
                    ? null
                    : () => onSeatSemanticTap!(seat),
              ),
            ),
        ];
  }
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
