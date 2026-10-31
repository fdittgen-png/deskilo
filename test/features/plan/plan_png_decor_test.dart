// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3074 — the printed plan carries the drawn room. The PNG is painted by the
// painter the screen uses, so every kind of symbol that is on the screen is
// on the page, and a level that holds nothing but a wall still prints.
import 'package:deskilo/features/plan/domain/floor_plan.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/office.dart';
import 'package:deskilo/features/plan/presentation/plan_png.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _colors = ColorScheme.light();

const _office = Office(
  id: 'o1',
  workspaceId: 'ws-1',
  levelId: 'level-1',
  name: 'Room',
  color: 0,
  bookableAsWhole: false,
  rect: GridRect(x: 10, y: 10, w: 20, h: 20),
);

PlanImage _symbol(PlanDecorKind kind, {int turns = 0}) => PlanImage(
  id: 'd-${kind.name}',
  levelId: 'level-1',
  rect: const GridRect(x: 12, y: 12, w: 6, h: 4),
  kind: kind,
  quarterTurns: turns,
);

FloorPlan _plan(List<PlanImage> images, {bool withOffice = true}) => FloorPlan(
  levelId: 'level-1',
  offices: withOffice ? const [_office] : const [],
  desks: const [],
  seats: const [],
  images: images,
);

Future<List<int>> _png(FloorPlan plan) async =>
    (await buildPlanPng(plan, colors: _colors, cellSize: 4))!;

void main() {
  testWidgets('each drawn kind changes the printed plan', (tester) async {
    await tester.runAsync(() async {
      final bare = await _png(_plan(const []));
      for (final kind in PlanDecorKind.values) {
        expect(
          await _png(_plan([_symbol(kind)])),
          isNot(bare),
          reason: '${kind.name} is on the screen but not on the page',
        );
      }
    });
  });

  testWidgets('a quarter turn changes the printed symbol', (tester) async {
    await tester.runAsync(() async {
      expect(
        await _png(_plan([_symbol(PlanDecorKind.door)])),
        isNot(await _png(_plan([_symbol(PlanDecorKind.door, turns: 1)]))),
      );
    });
  });

  testWidgets('a level that holds only a wall still prints', (tester) async {
    await tester.runAsync(() async {
      final png = await buildPlanPng(
        _plan([_symbol(PlanDecorKind.wall)], withOffice: false),
        colors: _colors,
        cellSize: 4,
      );
      expect(png, isNotNull);
      expect(png!.length, greaterThan(100));
    });
  });
}
