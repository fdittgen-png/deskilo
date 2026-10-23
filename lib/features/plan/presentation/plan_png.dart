// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A level's plan as a PNG, drawn off-screen by the same painter the app
// shows the plan with, so a printed plan cannot differ from the screen's.
// The picture is cut to the part of the grid the plan uses.
//
// #2898 — a level's background photo prints under the plan where the
// editor shows it: contain-fit to the whole canvas, at the editor's
// opacity, the plan on top. A photo that cannot be read prints the plan
// exactly as without one. [levelReportPlans] reads every level with its
// plan and photo for a report, so each printed report draws them alike.
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/trace/trace_logger.dart';
import '../domain/floor_plan.dart';
import '../domain/level.dart';
import '../providers/floor_plan_providers.dart';
import 'widgets/floor_plan_painter.dart';
import 'widgets/plan_canvas.dart';

/// [plan] drawn in [colors] on white, or null when it holds nothing to
/// draw. The longer side is at most [maxSide] pixels. A [background] is
/// the level's photo, painted under the plan as the editor paints it.
/// Reports print through [reportPlanPngs].
@visibleForTesting
Future<Uint8List?> buildPlanPng(
  FloorPlan plan, {
  required ColorScheme colors,
  double cellSize = 16,
  int maxSide = 2400,
  ui.Image? background,
}) async {
  final bounds = plan.usedBounds;
  if (bounds == null || bounds.w <= 0 || bounds.h <= 0) return null;
  final scale = math.min(
    1,
    maxSide / (math.max(bounds.w, bounds.h) * cellSize),
  );
  final cell = cellSize * scale;
  final width = (bounds.w * cell).ceil();
  final height = (bounds.h * cell).ceil();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = Colors.white,
    )
    ..translate(-bounds.x * cell, -bounds.y * cell);
  FloorPlanPainter(
    plan: plan,
    cellSize: cell,
    colorScheme: colors,
    background: background,
  ).paint(
    canvas,
    // The photo is fitted to the editor's whole canvas, so it lands where
    // the editor shows it; without one the size is what it always was.
    background == null
        ? Size((bounds.x + bounds.w) * cell, (bounds.y + bounds.h) * cell)
        : Size.square(PlanCanvasMetrics.cells * cell),
  );
  final image = await recorder.endRecording().toImage(width, height);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes?.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

/// Each level's plan as a PNG for a printed report, keyed like
/// [plansByLevel]. A level in [photoLevels] gets its photo from
/// [background] under the plan; one that fails, or is not there within
/// [wait], is traced and the plan prints without it.
Future<Map<String, Uint8List>> reportPlanPngs(
  Map<String, FloorPlan> plansByLevel, {
  required ColorScheme colors,
  required Set<String> photoLevels,
  required Future<ui.Image?> Function(String levelId) background,
  Duration wait = const Duration(seconds: 15),
}) async {
  final pngs = <String, Uint8List>{};
  for (final MapEntry(key: levelId, value: plan) in plansByLevel.entries) {
    final photo = photoLevels.contains(levelId)
        ? await _photoOf(levelId, background, wait)
        : null;
    final png = await buildPlanPng(plan, colors: colors, background: photo);
    if (png != null) pngs[levelId] = png;
  }
  return pngs;
}

Future<ui.Image?> _photoOf(
  String levelId,
  Future<ui.Image?> Function(String levelId) background,
  Duration wait,
) async {
  try {
    return await background(levelId).timeout(wait);
  } on Object catch (e, st) {
    TraceLogger.instance.warn(
      'plan',
      'level $levelId: background photo unreadable, plan printed without it',
      error: e,
      stackTrace: st,
    );
    return null;
  }
}

/// #2898 — every level in order with its plan, and the picture of each
/// plan that has something to draw, keyed by level id: drawn through
/// [reportPlanPngs], the photo read the way the editor reads it.
Future<({List<({Level level, FloorPlan plan})> levels, Map<String, Uint8List> pngs})>
    levelReportPlans(WidgetRef ref, {required ColorScheme colors}) async {
  final levels = <({Level level, FloorPlan plan})>[
    for (final level in await ref.read(levelsProvider.future))
      (level: level, plan: await ref.read(floorPlanProvider(level.id).future)),
  ];
  final pngs = await reportPlanPngs(
    {for (final entry in levels) entry.level.id: entry.plan},
    colors: colors,
    photoLevels: {
      for (final entry in levels)
        if (entry.level.hasBackground) entry.level.id,
    },
    background: (id) => ref.read(levelBackgroundProvider(id).future),
  );
  return (levels: levels, pngs: pngs);
}
