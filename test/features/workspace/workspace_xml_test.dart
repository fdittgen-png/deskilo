// SPDX-License-Identifier: MIT
import 'package:deskilo/features/plan/domain/desk.dart';
import 'package:deskilo/features/plan/domain/floor_plan.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/level.dart';
import 'package:deskilo/features/plan/domain/office.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/domain/workspace_xml.dart';
import 'package:flutter_test/flutter_test.dart';

/// A workspace covering every serialized field: overridden feature
/// flags, payment instructions, XML-hostile characters in names.
const _workspace = Workspace(
  id: 'ws-1',
  name: 'Café & "Lounge" <3',
  countryCode: 'DE',
  currencyCode: 'EUR',
  timezone: 'Europe/Berlin',
  inviteCode: 'SECRET1234',
  featureFlags: {'money': false, 'events': true},
  paymentInstructions: {
    'iban': 'DE89 3704 0044 0532 0130 00',
    'paypal_me': 'deskilo',
    'reference': '',
    // #192 — the codec is map-driven: new keys must flow through the
    // round trip with no schema change.
    'wero': '+49 170 0000000',
    'wise': '@deskilo',
  },
);

const _groundFloor =
    Level(id: 'level-1', workspaceId: 'ws-1', name: 'Ground floor', sortOrder: 0);
const _upstairs =
    Level(id: 'level-2', workspaceId: 'ws-1', name: 'Upstairs', sortOrder: 1);

const _office = Office(
  id: 'office-1',
  workspaceId: 'ws-1',
  levelId: 'level-1',
  name: 'Main room',
  color: 3,
  bookableAsWhole: true,
  rect: GridRect(x: 0, y: 0, w: 30, h: 20),
);

const _desk = Desk(
  id: 'desk-1',
  workspaceId: 'ws-1',
  officeId: 'office-1',
  name: 'Window desk',
  rect: GridRect(x: 2, y: 2, w: 12, h: 4),
);

final _blockedSeat = Seat(
  id: 'seat-1',
  workspaceId: 'ws-1',
  deskId: 'desk-1',
  name: 'A1',
  x: 2,
  y: 2,
  orientation: SeatOrientation.n,
  chair: 'herman-miller',
  amenities: const ['monitor', 'dock'],
  blockedFrom: DateTime.utc(2026, 8, 1, 6),
  blockedTo: DateTime.utc(2026, 8, 15, 18),
);

/// Open-ended block (from, no to) + a sideways orientation (spec §10).
final _openEndedSeat = Seat(
  id: 'seat-2',
  workspaceId: 'ws-1',
  deskId: 'desk-1',
  name: 'A2',
  x: 8,
  y: 2,
  orientation: SeatOrientation.w,
  chair: '',
  amenities: const [],
  blockedFrom: DateTime.utc(2026, 9, 1),
);

String _validXml() => buildWorkspaceXml(
      workspace: _workspace,
      levels: [
        (
          level: _groundFloor,
          plan: FloorPlan(
            levelId: 'level-1',
            offices: const [_office],
            desks: const [_desk],
            seats: [_blockedSeat, _openEndedSeat],
          ),
        ),
        (
          level: _upstairs,
          plan: const FloorPlan(
              levelId: 'level-2', offices: [], desks: [], seats: []),
        ),
      ],
    );

void main() {
  group('round trip', () {
    test('toXml → parse yields the equal id-free structure (#164)', () {
      final parsed = parseWorkspaceXml(_validXml());

      expect(
        parsed,
        WorkspaceXmlData(
          settings: const WorkspaceXmlSettings(
            name: 'Café & "Lounge" <3',
            countryCode: 'DE',
            currencyCode: 'EUR',
            timezone: 'Europe/Berlin',
            featureFlags: {'events': true, 'money': false},
            // The empty reference is dropped on export; the #192 keys
            // ride the map-driven <payment-instruction key value/>.
            paymentInstructions: {
              'iban': 'DE89 3704 0044 0532 0130 00',
              'paypal_me': 'deskilo',
              'wero': '+49 170 0000000',
              'wise': '@deskilo',
            },
          ),
          levels: [
            WorkspaceXmlLevel(
              name: 'Ground floor',
              sortOrder: 0,
              offices: [
                WorkspaceXmlOffice(
                  name: 'Main room',
                  color: 3,
                  bookableAsWhole: true,
                  rect: const GridRect(x: 0, y: 0, w: 30, h: 20),
                  desks: [
                    WorkspaceXmlDesk(
                      name: 'Window desk',
                      rect: const GridRect(x: 2, y: 2, w: 12, h: 4),
                      seats: [
                        WorkspaceXmlSeat(
                          name: 'A1',
                          x: 2,
                          y: 2,
                          orientation: SeatOrientation.n,
                          chair: 'herman-miller',
                          amenities: const ['monitor', 'dock'],
                          blockedFrom: DateTime.utc(2026, 8, 1, 6),
                          blockedTo: DateTime.utc(2026, 8, 15, 18),
                        ),
                        WorkspaceXmlSeat(
                          name: 'A2',
                          x: 8,
                          y: 2,
                          orientation: SeatOrientation.w,
                          blockedFrom: DateTime.utc(2026, 9, 1),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const WorkspaceXmlLevel(name: 'Upstairs', sortOrder: 1),
          ],
        ),
      );
    });

    test('the invite code and all ids are NOT in the document', () {
      final xml = _validXml();
      expect(xml, isNot(contains('SECRET1234')));
      expect(xml, isNot(contains('ws-1')));
      expect(xml, isNot(contains('level-1')));
      expect(xml, isNot(contains('office-1')));
      expect(xml, isNot(contains('desk-1')));
      expect(xml, isNot(contains('seat-1')));
    });

    test('levels serialize in sort order regardless of input order', () {
      final xml = buildWorkspaceXml(
        workspace: _workspace,
        levels: [
          (
            level: _upstairs,
            plan: const FloorPlan(
                levelId: 'level-2', offices: [], desks: [], seats: []),
          ),
          (
            level: _groundFloor,
            plan: const FloorPlan(
                levelId: 'level-1', offices: [], desks: [], seats: []),
          ),
        ],
      );
      final parsed = parseWorkspaceXml(xml);
      expect(parsed.levels.map((l) => l.name), ['Ground floor', 'Upstairs']);
    });
  });

  group('parser rejections', () {
    WorkspaceXmlError errorOf(String input) {
      try {
        parseWorkspaceXml(input);
      } on WorkspaceXmlException catch (e) {
        return e.error;
      }
      fail('expected WorkspaceXmlException for: $input');
    }

    test('junk that is not XML → malformed', () {
      expect(errorOf('this is not xml'), WorkspaceXmlError.malformed);
    });

    test('wrong root element → wrongRoot', () {
      expect(
        errorOf('<not-a-workspace version="1"/>'),
        WorkspaceXmlError.wrongRoot,
      );
    });

    test('unknown version 2 → unsupportedVersion', () {
      expect(
        errorOf('<deskilo-workspace version="2">'
            '<settings name="X" country="DE" currency="EUR" '
            'timezone="Europe/Berlin"/><floor-plan/></deskilo-workspace>'),
        WorkspaceXmlError.unsupportedVersion,
      );
    });

    test('missing version attribute → missingAttribute', () {
      expect(
        errorOf('<deskilo-workspace/>'),
        WorkspaceXmlError.missingAttribute,
      );
    });

    test('missing <settings> → missingElement', () {
      expect(
        errorOf('<deskilo-workspace version="1"><floor-plan/>'
            '</deskilo-workspace>'),
        WorkspaceXmlError.missingElement,
      );
    });

    test('missing required settings attribute → missingAttribute', () {
      expect(
        errorOf('<deskilo-workspace version="1">'
            '<settings name="X" country="DE" currency="EUR"/>'
            '<floor-plan/></deskilo-workspace>'),
        WorkspaceXmlError.missingAttribute,
      );
    });

    test('junk seat orientation → invalidValue', () {
      expect(
        errorOf(_planXml(
            '<seat name="A1" x="2" y="2" orientation="up" chair=""/>')),
        WorkspaceXmlError.invalidValue,
      );
    });

    test('negative coordinate → invalidValue', () {
      expect(
        errorOf(_planXml(
            '<seat name="A1" x="-1" y="2" orientation="n" chair=""/>')),
        WorkspaceXmlError.invalidValue,
      );
    });

    test('zero-size office rect → invalidValue', () {
      expect(
        errorOf('<deskilo-workspace version="1">'
            '<settings name="X" country="DE" currency="EUR" '
            'timezone="Europe/Berlin"/><floor-plan>'
            '<level name="G" sort-order="0">'
            '<office name="O" color="0" bookable-as-whole="false" '
            'x="0" y="0" w="0" h="10"/>'
            '</level></floor-plan></deskilo-workspace>'),
        WorkspaceXmlError.invalidValue,
      );
    });

    test('non-boolean feature flag → invalidValue', () {
      expect(
        errorOf('<deskilo-workspace version="1">'
            '<settings name="X" country="DE" currency="EUR" '
            'timezone="Europe/Berlin">'
            '<feature key="money" enabled="maybe"/></settings>'
            '<floor-plan/></deskilo-workspace>'),
        WorkspaceXmlError.invalidValue,
      );
    });

    test('unparseable blocked-from timestamp → invalidValue', () {
      expect(
        errorOf(_planXml('<seat name="A1" x="2" y="2" orientation="n" '
            'chair="" blocked-from="tomorrow"/>')),
        WorkspaceXmlError.invalidValue,
      );
    });
  });

  group('workspaceXmlFileName', () {
    test('slugifies the workspace name', () {
      expect(workspaceXmlFileName('Test Space'), 'deskilo-test-space.xml');
      expect(
        workspaceXmlFileName('Café & Lounge!'),
        'deskilo-caf-lounge.xml',
      );
    });

    test('falls back when nothing slug-safe remains', () {
      expect(workspaceXmlFileName('???'), 'deskilo-workspace.xml');
    });
  });
}

/// A structurally valid document with [seatXml] as the only seat.
String _planXml(String seatXml) => '<deskilo-workspace version="1">'
    '<settings name="X" country="DE" currency="EUR" '
    'timezone="Europe/Berlin"/>'
    '<floor-plan><level name="G" sort-order="0">'
    '<office name="O" color="0" bookable-as-whole="false" '
    'x="0" y="0" w="30" h="20">'
    '<desk name="D" x="2" y="2" w="12" h="4">$seatXml</desk>'
    '</office></level></floor-plan></deskilo-workspace>';
