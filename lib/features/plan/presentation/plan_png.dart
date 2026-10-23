// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A level's plan as a PNG, drawn off-screen by the same painter the app
// shows the plan with, so a printed plan cannot differ from the screen's.
// The picture is cut to the part of the grid the plan uses.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../domain/floor_plan.dart';
import 'widgets/floor_plan_painter.dart';

/// [plan] drawn in [colors] on white, or null when it holds nothing to
/// draw. The longer side is at most [maxSide] pixels.
Future<Uint8List?> buildPlanPng(
  FloorPlan plan, {
  required ColorScheme colors,
  double cellSize = 16,
  int maxSide = 2400,
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
  FloorPlanPainter(plan: plan, cellSize: cell, colorScheme: colors).paint(
    canvas,
    Size((bounds.x + bounds.w) * cell, (bounds.y + bounds.h) * cell),
  );
  final image = await recorder.endRecording().toImage(width, height);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes?.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}
