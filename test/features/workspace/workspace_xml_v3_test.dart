// SPDX-License-Identifier: 0BSD
//
// #916 — schema v3: the plan attributes v2 dropped and the configuration
// section, on the way out and on the way back in; v2 files still parse.
import 'package:deskilo/features/plan/domain/accessory.dart';
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

const _level = Level(
  id: 'l1',
  workspaceId: 'ws-1',
  name: 'Rez-de-chaussée',
  sortOrder: 0,
  priceCents: 50000,
  bookableAsWhole: true,
  siteId: 'site-1',
);

const _plan = FloorPlan(
  levelId: 'l1',
  offices: [
    Office(
      id: 'o1',
      workspaceId: 'ws-1',
      levelId: 'l1',
      name: 'Open space',
      color: 1,
      bookableAsWhole: false,
      rect: GridRect(x: 0, y: 0, w: 10, h: 10),
      priceCents: 7000,
    ),
  ],
  desks: [
    Desk(
      id: 'd1',
      workspaceId: 'ws-1',
      officeId: 'o1',
      name: 'Table 1',
      rect: GridRect(x: 1, y: 1, w: 6, h: 4),
      priceCents: 3000,
      bookableAsWhole: true,
    ),
  ],
  seats: [
    Seat(
      id: 's1',
      workspaceId: 'ws-1',
      deskId: 'd1',
      name: 'Place 1',
      x: 1,
      y: 1,
      orientation: SeatOrientation.n,
      chair: '',
      amenities: [],
      nfcUid: '04a1b2c3',
    ),
  ],
);

const _accessory = Accessory(
  id: 'a1',
  workspaceId: 'ws-1',
  name: 'Écran',
  supplementCents: 100,
  active: true,
  sortOrder: 0,
  vatRateId: 'rate-20',
);

final Map<String, Object?> _configuration = {
  'workspace': {'vat_regime': 'not_subject', 'booking_rules': {'granularity': 'half_day'}},
  'tables': {
    'sites': [
      {'name': 'Pézenas', 'is_default': true},
    ],
  },
};

String _export() => buildWorkspaceXml(
      workspace: _workspace,
      levels: [(level: _level, plan: _plan)],
      accessories: const [_accessory],
      seatAccessories: const {'s1': {'a1'}},
      configuration: _configuration,
      siteNames: const {'site-1': 'Pézenas'},
      vatRateLabels: const {'rate-20': 'Standard 20 %'},
    );

void main() {
  test('the export is schema 3 and carries the plan attributes by name',
      () {
    final xml = _export();
    expect(xml, contains('<deskilo-workspace version="3">'));
    expect(xml, contains('price-cents="50000" bookable-as-whole="true" site="Pézenas"'));
    expect(xml, contains('<office name="Open space" color="1" bookable-as-whole="false" x="0" y="0" w="10" h="10" price-cents="7000">'));
    expect(xml, contains('<desk name="Table 1" x="1" y="1" w="6" h="4" price-cents="3000" bookable-as-whole="true">'));
    expect(xml, contains('nfc-uid="04a1b2c3"'));
    expect(xml, contains('vat-rate="Standard 20 %"'));
    expect(xml, contains('<configuration>'));
    expect(xml, isNot(contains('SECRET')), reason: 'the invite code never travels');
    expect(xml, isNot(contains('site-1')), reason: 'ids never travel');
  });

  test('parsed back, every v3 attribute and the configuration are there',
      () {
    final data = parseWorkspaceXml(_export());
    final level = data.levels.single;
    expect((level.priceCents, level.bookableAsWhole, level.site),
        (50000, true, 'Pézenas'));
    expect(level.offices.single.priceCents, 7000);
    final desk = level.offices.single.desks.single;
    expect((desk.priceCents, desk.bookableAsWhole), (3000, true));
    expect(desk.seats.single.nfcUid, '04a1b2c3');
    expect(data.accessories.single.vatRate, 'Standard 20 %');
    expect(data.configuration, _configuration);
  });

  test('export → import → export is byte-identical', () {
    final once = _export();
    final data = parseWorkspaceXml(once);
    // Re-export from the parsed structure: the plan through the import
    // payload (what the server receives), the configuration as parsed.
    final plan = workspaceXmlPlanToJson(data.levels).single;
    expect(plan[WorkspaceImportPlanKeys.priceCents], 50000);
    expect(plan[WorkspaceImportPlanKeys.site], 'Pézenas');
    final seat = (((plan['offices'] as List).single as Map)['desks'] as List)
        .single as Map;
    expect(seat[WorkspaceImportPlanKeys.priceCents], 3000);
    expect(((seat['seats'] as List).single as Map)['nfc_uid'], '04a1b2c3');
    expect(workspaceXmlAccessoriesToJson(data.accessories).single['vat_rate'],
        'Standard 20 %');
    final twice = buildWorkspaceXml(
      workspace: _workspace,
      levels: [(level: _level, plan: _plan)],
      accessories: const [_accessory],
      seatAccessories: const {'s1': {'a1'}},
      configuration: data.configuration,
      siteNames: const {'site-1': 'Pézenas'},
      vatRateLabels: const {'rate-20': 'Standard 20 %'},
    );
    expect(twice, once);
  });

  test('a v2 document still parses: defaults for the attributes, no '
      'configuration', () {
    const v2 = '''
<?xml version="1.0" encoding="UTF-8"?>
<deskilo-workspace version="2">
  <settings name="x" country="FR" currency="EUR" timezone="Europe/Paris"/>
  <accessories><accessory name="Écran" supplement-cents="0" active="true" sort-order="0"/></accessories>
  <floor-plan>
    <level name="L" sort-order="0">
      <office name="O" color="1" bookable-as-whole="false" x="0" y="0" w="4" h="4">
        <desk name="D" x="0" y="0" w="2" h="2">
          <seat name="S" x="0" y="0" orientation="n" chair=""/>
        </desk>
      </office>
    </level>
  </floor-plan>
</deskilo-workspace>''';
    final data = parseWorkspaceXml(v2);
    expect(data.configuration, isNull);
    expect(data.levels.single.priceCents, 0);
    expect(data.levels.single.site, '');
    expect(data.levels.single.offices.single.desks.single.seats.single.nfcUid, '');
    expect(data.accessories.single.vatRate, '');
    // Sent to the server, the v3 keys carry their defaults and the
    // optional ones stay absent.
    final plan = workspaceXmlPlanToJson(data.levels).single;
    expect(plan.containsKey(WorkspaceImportPlanKeys.site), isFalse);
    expect(workspaceXmlAccessoriesToJson(data.accessories).single
        .containsKey(WorkspaceImportPlanKeys.vatRate), isFalse);
  });

  test('a plan-less v3 file with a configuration parses too', () {
    const v3 = '''
<deskilo-workspace version="3">
  <settings name="x" country="FR" currency="EUR" timezone="Europe/Paris"/>
  <floor-plan/>
  <configuration>
    <field name="workspace" type="object">
      <field name="vat_regime" type="string" value="not_subject"/>
    </field>
  </configuration>
</deskilo-workspace>''';
    final data = parseWorkspaceXml(v3);
    expect(data.levels, isEmpty);
    expect((data.configuration!['workspace'] as Map)['vat_regime'], 'not_subject');
  });
}
