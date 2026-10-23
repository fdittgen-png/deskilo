// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2898 — the printed plan carries the level's background photo under it,
// where the editor shows it: the PNG is the editor's canvas (photo and
// plan) cut to the part of the grid the plan uses. A photo that cannot be
// read, or does not come, prints the plan byte for byte as without one.
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:deskilo/core/trace/trace_logger.dart';
import 'package:deskilo/features/plan/domain/desk.dart';
import 'package:deskilo/features/plan/domain/floor_plan.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/office.dart';
import 'package:deskilo/features/plan/presentation/plan_png.dart';
import 'package:deskilo/features/plan/presentation/widgets/floor_plan_painter.dart';
import 'package:deskilo/features/plan/presentation/widgets/plan_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _colors = ColorScheme.light();
const _cell = 4.0;

Office _office(String id, GridRect rect) => Office(
  id: id,
  workspaceId: 'ws-1',
  levelId: 'level-1',
  name: id,
  color: 0,
  bookableAsWhole: false,
  rect: rect,
);

/// Two small rooms at opposite corners of cells 40..80 and a desk between
/// them: the plan's used bounds are 40..80 on both axes.
const _plan = FloorPlan(levelId: 'level-1', offices: [], desks: [], seats: []);
final _fullPlan = _plan.copyWith(
  offices: [
    _office('a', const GridRect(x: 40, y: 40, w: 4, h: 4)),
    _office('b', const GridRect(x: 76, y: 76, w: 4, h: 4)),
  ],
  desks: const [
    Desk(
      id: 'desk-1',
      workspaceId: 'ws-1',
      officeId: 'a',
      name: 'Desk',
      rect: GridRect(x: 58, y: 58, w: 4, h: 4),
    ),
  ],
);

/// A wide photo in one colour: contain-fit to the 120-cell canvas it is
/// 120 × 30 cells, rows 45..75 — inside the plan, but not its top rows.
Future<ui.Image> _photo() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 240, 60),
    Paint()..color = const Color(0xFFD03020),
  );
  return recorder.endRecording().toImage(240, 60);
}

Future<ByteData> _rgba(ui.Image image) async => (await image.toByteData())!;

Future<(ByteData, int)> _decode(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final image = (await codec.getNextFrame()).image;
  return (await _rgba(image), image.width);
}

/// RGBA at the centre of grid cell ([cx], [cy]) of a picture whose origin
/// is cell ([ox], [oy]).
List<int> _at(
  ByteData data,
  int width,
  int cx,
  int cy, {
  int ox = 40,
  int oy = 40,
}) {
  final x = ((cx - ox) * _cell + _cell / 2).floor();
  final y = ((cy - oy) * _cell + _cell / 2).floor();
  final o = (y * width + x) * 4;
  return [for (var i = 0; i < 4; i++) data.getUint8(o + i)];
}

void main() {
  late ui.Image photo;
  setUpAll(() async => photo = await _photo());

  test('the photo is under the plan where the editor shows it: the PNG is '
      "the editor's canvas cut to the plan", () async {
    final png = (await buildPlanPng(
      _fullPlan,
      colors: _colors,
      cellSize: _cell,
      background: photo,
    ))!;
    final (printed, width) = await _decode(png);
    expect(width, 160, reason: '40 cells of 4 px: the crop is unchanged');

    // The editor: the same painter over its whole 120-cell canvas, on white.
    const side = PlanCanvasMetrics.cells * _cell;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..drawRect(
        const Rect.fromLTWH(0, 0, side, side),
        Paint()..color = Colors.white,
      );
    FloorPlanPainter(
      plan: _fullPlan,
      cellSize: _cell,
      colorScheme: _colors,
      background: photo,
    ).paint(canvas, const Size.square(side));
    final editor = await _rgba(
      await recorder.endRecording().toImage(side.toInt(), side.toInt()),
    );

    // The PNG round-trip may move a channel by one step; nothing more.
    var worst = 0;
    for (var y = 0; y < 160; y++) {
      for (var x = 0; x < 160; x++) {
        final p = (y * 160 + x) * 4;
        final e = ((y + 160) * side.toInt() + x + 160) * 4;
        var d = 0;
        for (var c = 0; c < 4; c++) {
          d = math.max(
            d,
            (printed.getUint8(p + c) - editor.getUint8(e + c)).abs(),
          );
        }
        worst = math.max(worst, d);
      }
    }
    expect(
      worst,
      lessThanOrEqualTo(2),
      reason: 'the printed plan is the editor canvas, pixel for pixel',
    );
  });

  test(
    'the photo shows at the editor opacity, the plan is painted on top',
    () async {
      final plain = await _decode(
        (await buildPlanPng(_fullPlan, colors: _colors, cellSize: _cell))!,
      );
      final withPhoto = await _decode(
        (await buildPlanPng(
          _fullPlan,
          colors: _colors,
          cellSize: _cell,
          background: photo,
        ))!,
      );

      // Above the photo's rows: the white sheet, as without a photo.
      expect(_at(withPhoto.$1, 160, 60, 42), _at(plain.$1, 160, 60, 42));
      // In them, an empty cell: the photo at 55 % over white.
      final tinted = _at(withPhoto.$1, 160, 66, 50);
      expect(_at(plain.$1, 160, 66, 50), [255, 255, 255, 255]);
      expect(tinted[0], closeTo(0.55 * 0xD0 + 0.45 * 255, 3));
      expect(tinted[1], closeTo(0.55 * 0x30 + 0.45 * 255, 3));
      expect(tinted[2], closeTo(0.55 * 0x20 + 0.45 * 255, 3));
      // The desk over the photo is the desk as it prints today.
      expect(_at(withPhoto.$1, 160, 60, 60), _at(plain.$1, 160, 60, 60));
    },
  );

  group('a photo that cannot be printed leaves the plan as it is today', () {
    late Uint8List today;
    late TraceLogger previous;
    setUp(() async {
      today = (await buildPlanPng(_fullPlan, colors: _colors))!;
      previous = TraceLogger.instance;
      TraceLogger.instance = TraceLogger();
    });
    tearDown(() => TraceLogger.instance = previous);

    Future<Uint8List> printed(
      Future<ui.Image?> Function(String) background, {
      Set<String> photoLevels = const {'level-1'},
    }) async => (await reportPlanPngs(
      {'level-1': _fullPlan},
      colors: _colors,
      photoLevels: photoLevels,
      background: background,
      wait: const Duration(milliseconds: 50),
    ))['level-1']!;

    test('unreadable: byte for byte, and traced', () async {
      final png = await printed(
        (_) async => throw Exception('Invalid image data'),
      );
      expect(png, today);
      expect(
        TraceLogger.instance.entries.where(
          (e) => e.area == 'plan' && e.message.contains('level-1'),
        ),
        hasLength(1),
      );
    });

    test('never answers: byte for byte once the wait is over', () async {
      expect(await printed((_) => Completer<ui.Image?>().future), today);
    });

    test('none set: byte for byte', () async {
      expect(await printed((_) async => null), today);
    });

    test('a level without a photo is not asked for one', () async {
      var asked = 0;
      final png = await printed((_) async {
        asked++;
        return photo;
      }, photoLevels: const {});
      expect(asked, 0);
      expect(png, today);
    });

    test('the photo when it reads', () async {
      expect(await printed((_) async => photo), isNot(today));
    });
  });

  test(
    'a level with nothing to draw prints no picture, photo or not',
    () async {
      final pngs = await reportPlanPngs(
        {'level-1': _plan},
        colors: _colors,
        photoLevels: const {'level-1'},
        background: (_) async => photo,
      );
      expect(pngs, isEmpty);
    },
  );
}
