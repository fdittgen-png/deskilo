// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3074 — schema v5: the drawn room (walls, doors, windows, pillars, tables,
// couches, WCs, kitchens) keeps what it is through export, parse and the
// import payload. Photos placed on the plan are pictures, not symbols, and
// do not travel.
import 'package:deskilo/features/plan/domain/floor_plan.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/level.dart';
import 'package:deskilo/features/plan/domain/office.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/domain/workspace_import.dart';
import 'package:deskilo/features/workspace/domain/workspace_xml.dart';
import 'package:flutter_test/flutter_test.dart';

const _workspace = Workspace(
  id: 'ws-1',
  name: 'Pézenas',
  countryCode: 'FR',
  currencyCode: 'EUR',
  timezone: 'Europe/Paris',
  inviteCode: 'SECRET',
);

const _level = Level(id: 'l1', workspaceId: 'ws-1', name: 'RDC', sortOrder: 0);

PlanImage _symbol(
  String id,
  PlanDecorKind kind,
  GridRect rect, {
  int turns = 0,
}) => PlanImage(
  id: id,
  levelId: 'l1',
  rect: rect,
  kind: kind,
  quarterTurns: turns,
);

final _plan = FloorPlan(
  levelId: 'l1',
  offices: const [
    Office(
      id: 'o1',
      workspaceId: 'ws-1',
      levelId: 'l1',
      name: 'Work',
      color: 2,
      bookableAsWhole: false,
      rect: GridRect(x: 0, y: 0, w: 10, h: 5),
    ),
  ],
  desks: const [],
  seats: const [],
  images: [
    _symbol('i1', PlanDecorKind.wall, const GridRect(x: 0, y: 6, w: 12, h: 1)),
    _symbol(
      'i2',
      PlanDecorKind.door,
      const GridRect(x: 4, y: 6, w: 3, h: 3),
      turns: 2,
    ),
    const PlanImage(
      id: 'photo',
      levelId: 'l1',
      rect: GridRect(x: 1, y: 1, w: 5, h: 5),
      storagePath: 'ws-1/photo.jpg',
    ),
  ],
);

String _export() => buildWorkspaceXml(
  workspace: _workspace,
  levels: [(level: _level, plan: _plan)],
);

void main() {
  test('v5 writes each symbol, its turns only when turned, and no photo', () {
    final xml = _export();
    expect(xml, contains('<deskilo-workspace version="5">'));
    expect(xml, contains('<decor kind="wall" x="0" y="6" w="12" h="1"/>'));
    expect(
      xml,
      contains('<decor kind="door" x="4" y="6" w="3" h="3" turns="2"/>'),
    );
    expect(xml, isNot(contains('photo')));
    expect(RegExp('<decor ').allMatches(xml), hasLength(2));
  });

  test('exported, parsed and sent to the server, the symbols are the same', () {
    final data = parseWorkspaceXml(_export());
    expect(
      [
        for (final d in data.levels.single.decor)
          (d.kind, d.rect.x, d.rect.y, d.rect.w, d.rect.h, d.quarterTurns),
      ],
      [('wall', 0, 6, 12, 1, 0), ('door', 4, 6, 3, 3, 2)],
    );
    final payload = workspaceXmlPlanToJson(data.levels).single;
    expect(payload[WorkspaceImportPlanKeys.decor], [
      {'kind': 'wall', 'x': 0, 'y': 6, 'w': 12, 'h': 1, 'quarter_turns': 0},
      {'kind': 'door', 'x': 4, 'y': 6, 'w': 3, 'h': 3, 'quarter_turns': 2},
    ]);
  });

  test('a level without symbols sends no decor key', () {
    final bare = buildWorkspaceXml(
      workspace: _workspace,
      levels: [(level: _level, plan: _plan.copyWith(images: const []))],
    );
    final payload = workspaceXmlPlanToJson(parseWorkspaceXml(bare).levels)
        .single;
    expect(payload.containsKey(WorkspaceImportPlanKeys.decor), isFalse);
  });

  test('a v4 file still parses, with no symbols', () {
    final v4 = _export()
        .replaceFirst('version="5"', 'version="4"')
        .replaceAll(RegExp('<decor [^>]*/>'), '');
    expect(parseWorkspaceXml(v4).levels.single.decor, isEmpty);
  });

  test('an unknown kind and a turn beyond three are refused', () {
    expect(
      () =>
          parseWorkspaceXml(_export().replaceFirst('kind="wall"', 'kind="x"')),
      throwsA(isA<WorkspaceXmlException>()),
    );
    expect(
      () => parseWorkspaceXml(_export().replaceFirst('turns="2"', 'turns="4"')),
      throwsA(isA<WorkspaceXmlException>()),
    );
  });
}
