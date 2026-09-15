// SPDX-License-Identifier: 0BSD
//
// #1273 — a level whose only room is the office is named by the level on
// member surfaces, and a second room brings both names back.
//
// The association's two floors each held one room, both called "Bureau 1",
// so a member choosing a floor read "Bureau 1" twice. The rule is pinned
// both ways, because a rule that only ever collapses is one nobody can
// turn off: a second room restores the names, and the flag off restores
// today's labels.
import 'package:deskilo/features/plan/domain/floor_plan.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/office.dart';
import 'package:flutter_test/flutter_test.dart';

Office _office(String id, String name) => Office(
      id: id,
      workspaceId: 'ws-1',
      levelId: 'level-2',
      name: name,
      color: 0,
      bookableAsWhole: false,
      rect: const GridRect(x: 0, y: 0, w: 20, h: 20),
    );

FloorPlan _plan(List<Office> offices) =>
    FloorPlan(levelId: 'level-2', offices: offices, desks: const [], seats: const []);

void main() {
  final bureau = _office('office-1', 'Bureau 1');

  test('a level whose only room is the office is named by the level', () {
    final plan = _plan([bureau]);
    expect(plan.officeContextName(bureau, levelName: '2e étage', byLevel: true),
        '2e étage');
    expect(plan.labelsOffices(byLevel: true), isFalse,
        reason: 'the canvas draws no room name rather than a room called a floor');
  });

  test('a second room brings both names back, with no configuration change',
      () {
    final salle = _office('office-2', 'Salle de réunion');
    final plan = _plan([bureau, salle]);
    expect(plan.officeContextName(bureau, levelName: '2e étage', byLevel: true),
        'Bureau 1');
    expect(plan.officeContextName(salle, levelName: '2e étage', byLevel: true),
        'Salle de réunion');
    expect(plan.labelsOffices(byLevel: true), isTrue);
  });

  test('the flag off keeps the room names everywhere', () {
    final plan = _plan([bureau]);
    expect(plan.officeContextName(bureau, levelName: '2e étage', byLevel: false),
        'Bureau 1');
    expect(plan.labelsOffices(byLevel: false), isTrue);
  });

  test('an unknown or empty level name never replaces the room with nothing',
      () {
    final plan = _plan([bureau]);
    expect(plan.officeContextName(bureau, byLevel: true), 'Bureau 1');
    expect(plan.officeContextName(bureau, levelName: '', byLevel: true),
        'Bureau 1');
  });
}
