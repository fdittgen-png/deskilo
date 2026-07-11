// SPDX-License-Identifier: MIT
import 'package:deskilo/features/plan/domain/desk.dart';
import 'package:deskilo/features/plan/domain/floor_plan.dart';
import 'package:deskilo/features/plan/domain/floor_plan_rules.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/level.dart';
import 'package:deskilo/features/plan/domain/office.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/domain/workspace_import.dart';
import 'package:deskilo/features/workspace/domain/workspace_xml.dart';
import 'package:flutter_test/flutter_test.dart';

/// A drawn one-level plan with every seat property populated, exported
/// through the real codec so the mapping test pins the whole chain
/// XML → [parseWorkspaceXml] → [workspaceXmlPlanToJson] (#165).
String _buildFixtureXml() {
  const workspace = Workspace(
    id: 'ws-1',
    name: 'Test Space',
    countryCode: 'DE',
    currencyCode: 'EUR',
    timezone: 'Europe/Berlin',
    inviteCode: 'GOODCODE22',
  );
  const level = Level(
    id: 'level-1',
    workspaceId: 'ws-1',
    name: 'Ground floor',
    sortOrder: 0,
  );
  const office = Office(
    id: 'office-1',
    workspaceId: 'ws-1',
    levelId: 'level-1',
    name: 'Main room',
    color: 3,
    bookableAsWhole: true,
    rect: GridRect(x: 1, y: 2, w: 30, h: 20),
  );
  const desk = Desk(
    id: 'desk-1',
    workspaceId: 'ws-1',
    officeId: 'office-1',
    name: 'Window desk',
    rect: GridRect(x: 2, y: 3, w: 14, h: 10),
  );
  final seats = [
    const Seat(
      id: 'seat-1',
      workspaceId: 'ws-1',
      deskId: 'desk-1',
      name: 'A1',
      x: 2,
      y: 3,
      orientation: SeatOrientation.n,
      chair: 'ergonomic',
      amenities: ['monitor', 'dock'],
    ),
    Seat(
      id: 'seat-2',
      workspaceId: 'ws-1',
      deskId: 'desk-1',
      name: 'A2',
      x: 2,
      y: 7,
      orientation: SeatOrientation.s,
      chair: '',
      amenities: const [],
      blockedFrom: DateTime.utc(2026, 7, 1, 8),
      blockedTo: DateTime.utc(2026, 7, 15, 18),
    ),
  ];
  return buildWorkspaceXml(
    workspace: workspace,
    levels: [
      (
        level: level,
        plan: FloorPlan(
          levelId: level.id,
          offices: const [office],
          desks: const [desk],
          seats: seats,
        ),
      ),
    ],
  );
}

WorkspaceXmlData _parseFixture() => parseWorkspaceXml(_buildFixtureXml());

void main() {
  group('workspaceXmlPlanToJson', () {
    test('maps a codec round-trip to the import_floor_plan jsonb shape', () {
      final json = workspaceXmlPlanToJson(_parseFixture().levels);

      expect(json, [
        {
          'name': 'Ground floor',
          'sort_order': 0,
          'offices': [
            {
              'name': 'Main room',
              'color': 3,
              'bookable_as_whole': true,
              'x': 1,
              'y': 2,
              'w': 30,
              'h': 20,
              'desks': [
                {
                  'name': 'Window desk',
                  'x': 2,
                  'y': 3,
                  'w': 14,
                  'h': 10,
                  'seats': [
                    {
                      'name': 'A1',
                      'x': 2,
                      'y': 3,
                      'orientation': 'n',
                      'chair': 'ergonomic',
                      'amenities': ['monitor', 'dock'],
                      'blocked_from': null,
                      'blocked_to': null,
                    },
                    {
                      'name': 'A2',
                      'x': 2,
                      'y': 7,
                      'orientation': 's',
                      'chair': '',
                      'amenities': <String>[],
                      'blocked_from': '2026-07-01T08:00:00.000Z',
                      'blocked_to': '2026-07-15T18:00:00.000Z',
                    },
                  ],
                },
              ],
            },
          ],
        },
      ]);
    });

    test('the RPC reservation guard message is pinned to the migration', () {
      // Mirrors the raise in supabase/migrations/0023_import_floor_plan.sql;
      // the UI matches on it to show the specific explanation.
      expect(kWorkspaceHasReservationsError, 'workspace has reservations');
    });
  });

  group('workspaceXmlPlanCounts', () {
    test('counts levels, offices, desks and seats for the preview', () {
      final counts = workspaceXmlPlanCounts(_parseFixture());
      expect(counts, (levels: 1, offices: 1, desks: 1, seats: 2));
    });
  });

  group('validateWorkspaceXmlPlan', () {
    test('accepts a plan the editor could have drawn', () {
      expect(validateWorkspaceXmlPlan(_parseFixture()), isNull);
    });

    test('rejects overlapping offices on the same level', () {
      const data = WorkspaceXmlData(
        settings: WorkspaceXmlSettings(
          name: 'X',
          countryCode: 'DE',
          currencyCode: 'EUR',
          timezone: 'Europe/Berlin',
        ),
        levels: [
          WorkspaceXmlLevel(
            name: 'Ground floor',
            sortOrder: 0,
            offices: [
              WorkspaceXmlOffice(
                name: 'A',
                color: 0,
                bookableAsWhole: false,
                rect: GridRect(x: 0, y: 0, w: 10, h: 10),
              ),
              WorkspaceXmlOffice(
                name: 'B',
                color: 0,
                bookableAsWhole: false,
                rect: GridRect(x: 5, y: 5, w: 10, h: 10),
              ),
            ],
          ),
        ],
      );
      final result = validateWorkspaceXmlPlan(data);
      expect(result?.problem, PlacementProblem.overlapsSibling);
      expect(result?.detail, contains('office "B"'));
    });

    test('rejects a desk outside its office', () {
      const data = WorkspaceXmlData(
        settings: WorkspaceXmlSettings(
          name: 'X',
          countryCode: 'DE',
          currencyCode: 'EUR',
          timezone: 'Europe/Berlin',
        ),
        levels: [
          WorkspaceXmlLevel(
            name: 'Ground floor',
            sortOrder: 0,
            offices: [
              WorkspaceXmlOffice(
                name: 'A',
                color: 0,
                bookableAsWhole: false,
                rect: GridRect(x: 0, y: 0, w: 10, h: 10),
                desks: [
                  WorkspaceXmlDesk(
                    name: 'Runaway',
                    rect: GridRect(x: 8, y: 8, w: 6, h: 4),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      final result = validateWorkspaceXmlPlan(data);
      expect(result?.problem, PlacementProblem.outsideParent);
      expect(result?.detail, contains('desk "Runaway"'));
    });

    test('rejects overlapping seats on the same desk', () {
      const data = WorkspaceXmlData(
        settings: WorkspaceXmlSettings(
          name: 'X',
          countryCode: 'DE',
          currencyCode: 'EUR',
          timezone: 'Europe/Berlin',
        ),
        levels: [
          WorkspaceXmlLevel(
            name: 'Ground floor',
            sortOrder: 0,
            offices: [
              WorkspaceXmlOffice(
                name: 'A',
                color: 0,
                bookableAsWhole: false,
                rect: GridRect(x: 0, y: 0, w: 30, h: 20),
                desks: [
                  WorkspaceXmlDesk(
                    name: 'Desk',
                    rect: GridRect(x: 0, y: 0, w: 12, h: 4),
                    seats: [
                      WorkspaceXmlSeat(
                        name: 'A1',
                        x: 0,
                        y: 0,
                        orientation: SeatOrientation.n,
                      ),
                      WorkspaceXmlSeat(
                        name: 'A2',
                        x: 4,
                        y: 0,
                        orientation: SeatOrientation.n,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      final result = validateWorkspaceXmlPlan(data);
      expect(result?.problem, PlacementProblem.overlapsSibling);
      expect(result?.detail, contains('seat "A2"'));
    });
  });
}
