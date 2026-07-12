// SPDX-License-Identifier: MIT
import 'dart:io';

import 'package:deskilo/features/plan/domain/accessory.dart';
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
  // v2 (#180): the catalog (incl. an inactive entry) + seat-1's two
  // assignments ride the same export.
  const accessories = [
    Accessory(
      id: 'accessory-1',
      workspaceId: 'ws-1',
      name: 'Monitor',
      supplementCents: 100,
      active: true,
      sortOrder: 0,
    ),
    Accessory(
      id: 'accessory-2',
      workspaceId: 'ws-1',
      name: 'Docking station',
      supplementCents: 50,
      active: false,
      sortOrder: 1,
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
    accessories: accessories,
    seatAccessories: const {
      'seat-1': {'accessory-1', 'accessory-2'},
    },
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
                      'accessories': ['Monitor', 'Docking station'],
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
                      'accessories': <String>[],
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
      // Mirrors the raise in supabase/migrations/0023_import_floor_plan.sql
      // and 0027_import_floor_plan_v2.sql; the UI matches on it to show
      // the specific explanation.
      expect(kWorkspaceHasReservationsError, 'workspace has reservations');
    });
  });

  group('workspaceXmlAccessoriesToJson (#180)', () {
    test('maps the parsed catalog to the p_accessories jsonb shape', () {
      final json = workspaceXmlAccessoriesToJson(_parseFixture().accessories);

      expect(json, [
        {
          'name': 'Monitor',
          'supplement_cents': 100,
          'active': true,
          'sort_order': 0,
        },
        {
          'name': 'Docking station',
          'supplement_cents': 50,
          'active': false,
          'sort_order': 1,
        },
      ]);
    });

    test('a parsed v1 file maps to an empty array — the v2 RPC then '
        'behaves exactly like the v1 import', () {
      expect(workspaceXmlAccessoriesToJson(const []), isEmpty);
    });
  });

  group('migration 0027 (import_floor_plan_v2)', () {
    final sql = File('supabase/migrations/0027_import_floor_plan_v2.sql')
        .readAsStringSync();

    test('declares the 3-arg v2 function and its grants; 0023 stays', () {
      expect(
        sql,
        contains('create or replace function public.import_floor_plan_v2('),
      );
      expect(
        sql,
        contains('grant execute on function '
            'public.import_floor_plan_v2(uuid, jsonb, jsonb) '
            'to authenticated;'),
      );
      expect(
        sql,
        contains('revoke execute on function '
            'public.import_floor_plan_v2(uuid, jsonb, jsonb) '
            'from public, anon;'),
      );
      // The v1 function is NOT touched — older clients keep working.
      final v1 = File('supabase/migrations/0023_import_floor_plan.sql')
          .readAsStringSync();
      expect(
        v1,
        contains('create or replace function public.import_floor_plan('),
      );
    });

    test('keeps the 0023 guards: owner-only + reservation refusal', () {
      expect(sql, contains("raise exception 'workspace has reservations'"));
      expect(
        sql,
        contains("raise exception 'only the owner may import a floor plan'"),
      );
    });

    test('upserts the catalog by (workspace_id, name) without deleting', () {
      expect(
        sql,
        contains('on conflict (workspace_id, name) do update'),
      );
      expect(sql, isNot(contains('delete from public.accessories')));
    });

    test('raises the pinned error for an unknown seat accessory name', () {
      expect(
        sql,
        contains("raise exception 'malformed plan: unknown accessory'"),
      );
    });
  });

  group('workspaceXmlPlanCounts', () {
    test('counts levels, offices, desks, seats and accessories for the '
        'preview', () {
      final counts = workspaceXmlPlanCounts(_parseFixture());
      expect(
        counts,
        (levels: 1, offices: 1, desks: 1, seats: 2, accessories: 2),
      );
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
