// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2860 — schema v4: a meeting room, a parking bay and a parking area keep
// what they are through export, parse and the import payload. Before v4 they
// came back as plain desk seats in a workspace area.
import 'package:deskilo/features/plan/domain/desk.dart';
import 'package:deskilo/features/plan/domain/floor_plan.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/level.dart';
import 'package:deskilo/features/plan/domain/office.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
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

Seat _seat(
  String id,
  String desk,
  String name,
  int x, {
  ResourceKind kind = ResourceKind.seat,
  int? capacity,
  ParkingKind? parking,
  int? slot,
}) => Seat(
  id: id,
  workspaceId: 'ws-1',
  deskId: desk,
  name: name,
  x: x,
  y: 0,
  orientation: SeatOrientation.n,
  chair: '',
  amenities: const [],
  resourceKind: kind,
  capacity: capacity,
  parkingKind: parking,
  slotMinutes: slot,
);

final _plan = FloorPlan(
  levelId: 'l1',
  offices: const [
    Office(
      id: 'o-park',
      workspaceId: 'ws-1',
      levelId: 'l1',
      name: 'Parking',
      color: 1,
      bookableAsWhole: false,
      rect: GridRect(x: 0, y: 0, w: 10, h: 4),
      areaKind: AreaKind.parking,
    ),
    Office(
      id: 'o-work',
      workspaceId: 'ws-1',
      levelId: 'l1',
      name: 'Work',
      color: 2,
      bookableAsWhole: false,
      rect: GridRect(x: 0, y: 5, w: 10, h: 5),
    ),
  ],
  desks: const [
    Desk(
      id: 'd-park',
      workspaceId: 'ws-1',
      officeId: 'o-park',
      name: 'Row',
      rect: GridRect(x: 0, y: 0, w: 4, h: 2),
    ),
    Desk(
      id: 'd-work',
      workspaceId: 'ws-1',
      officeId: 'o-work',
      name: 'Table',
      rect: GridRect(x: 0, y: 5, w: 4, h: 2),
    ),
  ],
  seats: [
    _seat(
      'p1',
      'd-park',
      'P1',
      0,
      kind: ResourceKind.parking,
      parking: ParkingKind.ev,
      slot: 1440,
    ),
    _seat(
      'r1',
      'd-work',
      'Meeting room',
      0,
      kind: ResourceKind.room,
      capacity: 8,
      slot: 60,
    ),
    _seat('s1', 'd-work', 'S1', 3),
  ],
);

String _export() => buildWorkspaceXml(
  workspace: _workspace,
  levels: [(level: _level, plan: _plan)],
);

void main() {
  test('v4 writes the kinds, and only where a place is not a plain seat', () {
    final xml = _export();
    expect(xml, contains('<deskilo-workspace version="4">'));
    expect(xml, contains('area-kind="parking"'));
    expect(xml, contains('resource-kind="parking"'));
    expect(xml, contains('slot-minutes="1440" parking-kind="ev"'));
    expect(
      xml,
      contains('resource-kind="room" capacity="8" slot-minutes="60"'),
    );
    expect(
      RegExp('<seat name="S1"[^>]*>').firstMatch(xml)![0],
      isNot(contains('resource-kind')),
    );
  });

  test('parsed and sent to the server, each place keeps its kind', () {
    final data = parseWorkspaceXml(_export());
    final offices = data.levels.single.offices;
    expect([for (final o in offices) o.areaKind], ['parking', 'workspace']);
    final seats = [
      for (final o in offices)
        for (final d in o.desks) ...d.seats,
    ];
    expect(
      [
        for (final s in seats)
          (s.name, s.resourceKind, s.capacity, s.parkingKind, s.slotMinutes),
      ],
      [
        ('P1', ResourceKind.parking, null, ParkingKind.ev, 1440),
        ('Meeting room', ResourceKind.room, 8, null, 60),
        ('S1', ResourceKind.seat, null, null, null),
      ],
    );
    final payload = workspaceXmlPlanToJson(data.levels).single;
    final park = (payload['offices'] as List).first as Map;
    expect(park[WorkspaceImportPlanKeys.areaKind], 'parking');
    final bay =
        (((park['desks'] as List).single as Map)['seats'] as List).single
            as Map;
    expect(bay[WorkspaceImportPlanKeys.resourceKind], 'parking');
    expect(bay[WorkspaceImportPlanKeys.parkingKind], 'ev');
    expect(bay[WorkspaceImportPlanKeys.slotMinutes], 1440);
  });

  test('a v3 file still parses: every place a seat in a workspace area', () {
    final v3 = _export()
        .replaceFirst('version="4"', 'version="3"')
        .replaceAll(RegExp(r' (area|resource|parking)-kind="[a-z]+"'), '')
        .replaceAll(RegExp(r' (capacity|slot-minutes)="\d+"'), '');
    final data = parseWorkspaceXml(v3);
    for (final o in data.levels.single.offices) {
      expect(o.areaKind, 'workspace');
      for (final s in o.desks.expand((d) => d.seats)) {
        expect(s.resourceKind, ResourceKind.seat);
      }
    }
  });

  test('an unknown kind is refused with the words it may be', () {
    expect(
      () => parseWorkspaceXml(
        _export().replaceFirst('resource-kind="room"', 'resource-kind="sofa"'),
      ),
      throwsA(isA<WorkspaceXmlException>()),
    );
  });
}
