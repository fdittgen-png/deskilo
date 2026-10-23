// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The parsed XML structure compares by value, collections and the
// configuration tree included, and the import check runs the editor's
// placement rules on geometry alone (#2927).
import 'package:deskilo/features/plan/domain/floor_plan_rules.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:deskilo/features/workspace/domain/workspace_import.dart';
import 'package:deskilo/features/workspace/domain/workspace_xml.dart';
import 'package:flutter_test/flutter_test.dart';

const _settings = WorkspaceXmlSettings(
  name: 'X',
  countryCode: 'FR',
  currencyCode: 'EUR',
  timezone: 'Europe/Paris',
);

const _document = '''
<?xml version="1.0" encoding="UTF-8"?>
<deskilo-workspace version="4">
  <settings name="Atelier" country="FR" currency="EUR" timezone="Europe/Paris" brand-color="#336699">
    <feature key="events" enabled="false"/>
    <payment-instruction key="iban" value="FR76"/>
  </settings>
  <accessories>
    <accessory name="Screen" supplement-cents="200" active="true" sort-order="0"/>
  </accessories>
  <floor-plan>
    <level name="Ground" sort-order="0" price-cents="900" site="Main">
      <office name="Open space" color="4280391411" bookable-as-whole="false" x="0" y="0" w="30" h="20">
        <desk name="D1" x="0" y="0" w="12" h="4">
          <seat name="S1" x="0" y="0" orientation="n" chair="Aeron" resource-kind="room" capacity="4">
            <amenity name="window"/>
            <accessory name="Screen"/>
          </seat>
        </desk>
      </office>
    </level>
  </floor-plan>
</deskilo-workspace>
''';

WorkspaceXmlData _withConfiguration(Map<String, Object?>? configuration) =>
    WorkspaceXmlData(settings: _settings, configuration: configuration);

WorkspaceXmlData _oneLevel(List<WorkspaceXmlOffice> offices) =>
    WorkspaceXmlData(
      settings: _settings,
      levels: [WorkspaceXmlLevel(name: 'L', sortOrder: 0, offices: offices)],
    );

void main() {
  group('value equality', () {
    test('two parses of one document are equal with equal hash codes', () {
      final a = parseWorkspaceXml(_document);
      final b = parseWorkspaceXml(_document);
      expect(identical(a, b), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('a difference anywhere in the tree breaks equality', () {
      final parsed = parseWorkspaceXml(_document);
      final seat =
          parsed.levels.single.offices.single.desks.single.seats.single;
      expect(seat.capacity, 4);
      expect(seat.accessoryNames, ['Screen']);
      final retagged = parseWorkspaceXml(
        _document.replaceFirst('capacity="4"', 'capacity="5"'),
      );
      expect(retagged, isNot(parsed));
      final recoloured = parseWorkspaceXml(
        _document.replaceFirst('#336699', '#336698'),
      );
      expect(recoloured, isNot(parsed));
      expect(parsed.settings.brandColor, '#336699');
    });

    test('the configuration tree compares structurally: map keys in any '
        'order, lists in order, null apart from empty', () {
      final a = _withConfiguration({
        'tariffs': [
          {'name': 'Day', 'price': 1500},
          {'name': 'Week', 'price': 6000},
        ],
        'legal': {'siren': '123', 'vat': 'FR1'},
      });
      final reordered = _withConfiguration({
        'legal': {'vat': 'FR1', 'siren': '123'},
        'tariffs': [
          {'price': 1500, 'name': 'Day'},
          {'price': 6000, 'name': 'Week'},
        ],
      });
      final swapped = _withConfiguration({
        'tariffs': [
          {'name': 'Week', 'price': 6000},
          {'name': 'Day', 'price': 1500},
        ],
        'legal': {'siren': '123', 'vat': 'FR1'},
      });
      expect(reordered, a);
      expect(reordered.hashCode, a.hashCode);
      expect(swapped, isNot(a));
      expect(_withConfiguration(null), isNot(_withConfiguration({})));
      expect(_withConfiguration(null), _withConfiguration(null));
    });
  });

  group('validateWorkspaceXmlPlan on geometry alone', () {
    test('the first problem in document order is the one reported', () {
      final result = validateWorkspaceXmlPlan(
        _oneLevel(const [
          WorkspaceXmlOffice(
            name: 'A',
            color: 0,
            bookableAsWhole: false,
            rect: GridRect(x: 0, y: 0, w: 10, h: 10),
            desks: [
              WorkspaceXmlDesk(
                name: 'Out',
                rect: GridRect(x: 8, y: 0, w: 6, h: 4),
              ),
            ],
          ),
          WorkspaceXmlOffice(
            name: 'B',
            color: 0,
            bookableAsWhole: false,
            rect: GridRect(x: 5, y: 5, w: 10, h: 10),
          ),
        ]),
      );
      expect(result?.problem, PlacementProblem.outsideParent);
      expect(result?.detail, 'desk "Out" in office "A"');
    });

    test('the same rects on two levels never collide', () {
      const office = WorkspaceXmlOffice(
        name: 'A',
        color: 0,
        bookableAsWhole: false,
        rect: GridRect(x: 0, y: 0, w: 10, h: 10),
        desks: [
          WorkspaceXmlDesk(name: 'D', rect: GridRect(x: 0, y: 0, w: 6, h: 4)),
        ],
      );
      const data = WorkspaceXmlData(
        settings: _settings,
        levels: [
          WorkspaceXmlLevel(name: 'L0', sortOrder: 0, offices: [office]),
          WorkspaceXmlLevel(name: 'L1', sortOrder: 1, offices: [office]),
        ],
      );
      expect(validateWorkspaceXmlPlan(data), isNull);
    });

    test('a turned seat uses its 4×6 footprint: off a 6×4 desk', () {
      final result = validateWorkspaceXmlPlan(
        _oneLevel(const [
          WorkspaceXmlOffice(
            name: 'A',
            color: 0,
            bookableAsWhole: false,
            rect: GridRect(x: 0, y: 0, w: 20, h: 20),
            desks: [
              WorkspaceXmlDesk(
                name: 'D',
                rect: GridRect(x: 0, y: 0, w: 6, h: 4),
                seats: [
                  WorkspaceXmlSeat(
                    name: 'N',
                    x: 0,
                    y: 0,
                    orientation: SeatOrientation.n,
                  ),
                ],
              ),
              WorkspaceXmlDesk(
                name: 'E',
                rect: GridRect(x: 10, y: 0, w: 6, h: 4),
                seats: [
                  WorkspaceXmlSeat(
                    name: 'Turned',
                    x: 10,
                    y: 0,
                    orientation: SeatOrientation.e,
                  ),
                ],
              ),
            ],
          ),
        ]),
      );
      expect(result?.problem, PlacementProblem.outsideParent);
      expect(result?.detail, 'seat "Turned" on desk "E"');
    });

    test('seats of different desks are not siblings of each other', () {
      final result = validateWorkspaceXmlPlan(
        _oneLevel(const [
          WorkspaceXmlOffice(
            name: 'A',
            color: 0,
            bookableAsWhole: false,
            rect: GridRect(x: 0, y: 0, w: 20, h: 20),
            desks: [
              WorkspaceXmlDesk(
                name: 'D1',
                rect: GridRect(x: 0, y: 0, w: 6, h: 4),
                seats: [
                  WorkspaceXmlSeat(
                    name: 'S',
                    x: 0,
                    y: 0,
                    orientation: SeatOrientation.n,
                  ),
                ],
              ),
              WorkspaceXmlDesk(
                name: 'D2',
                rect: GridRect(x: 0, y: 4, w: 6, h: 4),
                seats: [
                  WorkspaceXmlSeat(
                    name: 'S',
                    x: 0,
                    y: 4,
                    orientation: SeatOrientation.s,
                  ),
                ],
              ),
            ],
          ),
        ]),
      );
      expect(result, isNull);
    });
  });
}
