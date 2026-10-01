// SPDX-License-Identifier: AGPL-3.0-or-later
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

/// Rebuilds the export inputs from a parsed document alone: new ids,
/// sites and VAT labels named by what the file says.
String _rebuild(WorkspaceXmlData data, {bool dropDeskPrice = false}) {
  const ws = 'ws-r';
  final settings = data.settings;
  final workspace = Workspace(
    id: ws,
    name: settings.name,
    countryCode: settings.countryCode,
    currencyCode: settings.currencyCode,
    timezone: settings.timezone,
    inviteCode: 'NEW', // never exported
    featureFlags: settings.featureFlags,
    paymentInstructions: settings.paymentInstructions,
  );
  final siteNames = <String, String>{};
  final vatLabels = <String, String>{};
  final accessoryIds = <String, String>{};
  for (final (i, a) in data.accessories.indexed) {
    if (a.vatRate.isNotEmpty) vatLabels['vat-$i'] = a.vatRate;
  }
  final accessories = [
    for (final (i, a) in data.accessories.indexed)
      Accessory(
        id: accessoryIds[a.name] = 'acc-$i',
        workspaceId: ws,
        name: a.name,
        supplementCents: a.supplementCents,
        active: a.active,
        sortOrder: a.sortOrder,
        vatRateId: a.vatRate.isEmpty ? '' : 'vat-$i',
      ),
  ];
  final seatAccessories = <String, Set<String>>{};
  final levels = <({Level level, FloorPlan plan})>[];
  for (final (li, l) in data.levels.indexed) {
    final levelId = 'lvl-$li';
    final offices = <Office>[];
    final desks = <Desk>[];
    final seats = <Seat>[];
    for (final (oi, o) in l.offices.indexed) {
      final officeId = '$levelId-o$oi';
      offices.add(
        Office(
          id: officeId,
          workspaceId: ws,
          levelId: levelId,
          name: o.name,
          color: o.color,
          bookableAsWhole: o.bookableAsWhole,
          rect: o.rect,
          priceCents: o.priceCents,
        ),
      );
      for (final (di, d) in o.desks.indexed) {
        final deskId = '$officeId-d$di';
        desks.add(
          Desk(
            id: deskId,
            workspaceId: ws,
            officeId: officeId,
            name: d.name,
            rect: d.rect,
            priceCents: dropDeskPrice ? 0 : d.priceCents,
            bookableAsWhole: d.bookableAsWhole,
          ),
        );
        for (final (si, s) in d.seats.indexed) {
          final seatId = '$deskId-s$si';
          seats.add(
            Seat(
              id: seatId,
              workspaceId: ws,
              deskId: deskId,
              name: s.name,
              x: s.x,
              y: s.y,
              orientation: s.orientation,
              chair: s.chair,
              amenities: s.amenities,
              blockedFrom: s.blockedFrom,
              blockedTo: s.blockedTo,
              nfcUid: s.nfcUid.isEmpty ? null : s.nfcUid,
            ),
          );
          if (s.accessoryNames.isNotEmpty) {
            seatAccessories[seatId] = {
              for (final n in s.accessoryNames) accessoryIds[n]!,
            };
          }
        }
      }
    }
    final siteId = l.site.isEmpty ? null : 'site-$li';
    if (siteId != null) siteNames[siteId] = l.site;
    levels.add((
      level: Level(
        id: levelId,
        workspaceId: ws,
        name: l.name,
        sortOrder: l.sortOrder,
        priceCents: l.priceCents,
        bookableAsWhole: l.bookableAsWhole,
        siteId: siteId,
      ),
      plan: FloorPlan(
        levelId: levelId,
        offices: offices,
        desks: desks,
        seats: seats,
      ),
    ));
  }
  return buildWorkspaceXml(
    workspace: workspace,
    levels: levels,
    accessories: accessories,
    seatAccessories: seatAccessories,
    configuration: data.configuration,
    siteNames: siteNames,
    vatRateLabels: vatLabels,
  );
}

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

  test('export → parse → rebuild → export is byte-identical', () {
    final once = _export();
    final data = parseWorkspaceXml(once);
    // The import payload the server receives carries the v3 keys.
    final plan = workspaceXmlPlanToJson(data.levels).single;
    expect(plan[WorkspaceImportPlanKeys.priceCents], 50000);
    expect(plan[WorkspaceImportPlanKeys.site], 'Pézenas');
    final seat =
        (((plan['offices'] as List).single as Map)['desks'] as List).single
            as Map;
    expect(seat[WorkspaceImportPlanKeys.priceCents], 3000);
    expect(((seat['seats'] as List).single as Map)['nfc_uid'], '04a1b2c3');
    expect(
      workspaceXmlAccessoriesToJson(data.accessories).single['vat_rate'],
      'Standard 20 %',
    );
    // #1862 — the second export is built ONLY from what was parsed, under
    // fresh ids, so a field the codec loses both ways cannot vouch for
    // itself; the originals above are never reused.
    expect(_rebuild(data), once);
  });

  test('the round trip notices a dropped attribute', () {
    final data = parseWorkspaceXml(_export());
    expect(_rebuild(data, dropDeskPrice: true), isNot(_export()));
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
