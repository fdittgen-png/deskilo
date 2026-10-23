// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2862 — the published schema of workspace XML is the contract the app
// writes to: the two generated documents under web/workspace-xml/ are
// current, the XML Schema is well formed, and a document that uses every
// optional part of the format validates against the hand-written
// reference — every element where the reference puts it, every attribute
// declared on its element, required ones present, values of their type.
// The same document also uses every attribute the reference declares,
// so the reference names nothing the writer never writes.
import 'dart:io';

import 'package:deskilo/features/plan/domain/accessory.dart';
import 'package:deskilo/features/plan/domain/desk.dart';
import 'package:deskilo/features/plan/domain/floor_plan.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/level.dart';
import 'package:deskilo/features/plan/domain/office.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/domain/workspace_xml.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import '../../tool/workspace_xml_reference.dart';

const _workspace = Workspace(
  id: 'ws-1',
  name: 'Pézenas',
  countryCode: 'FR',
  currencyCode: 'EUR',
  timezone: 'Europe/Paris',
  inviteCode: 'SECRET',
  featureFlags: {'calendarTab': true},
  paymentInstructions: {'iban': 'FR76 0000'},
  branding: {'seed_color': '#3366CC'},
);

Seat _seat(String id, String desk, int x, {ResourceKind? kind}) => Seat(
  id: id,
  workspaceId: 'ws-1',
  deskId: desk,
  name: 'S$x',
  x: x,
  y: 0,
  orientation: SeatOrientation.e,
  chair: 'Mesh',
  amenities: const ['screen'],
  resourceKind: kind ?? ResourceKind.seat,
  capacity: kind == ResourceKind.room ? 8 : null,
  slotMinutes: kind == ResourceKind.room ? 30 : null,
  parkingKind: kind == ResourceKind.parking ? ParkingKind.values.first : null,
  nfcUid: 'nfc-$x',
  blockedFrom: DateTime.utc(2026, 11, 3),
  blockedTo: DateTime.utc(2026, 11, 2),
);

String _richDocument() => buildWorkspaceXml(
  workspace: _workspace,
  levels: [
    (
      level: const Level(
        id: 'l1',
        workspaceId: 'ws-1',
        name: 'RDC',
        sortOrder: 0,
        bookableAsWhole: true,
        priceCents: 9000,
        siteId: 'site-1',
      ),
      plan: FloorPlan(
        levelId: 'l1',
        offices: const [
          Office(
            id: 'o1',
            workspaceId: 'ws-1',
            levelId: 'l1',
            name: 'Parking',
            color: 4282664004,
            bookableAsWhole: false,
            rect: GridRect(x: 0, y: 0, w: 10, h: 4),
            areaKind: AreaKind.parking,
            priceCents: 500,
          ),
        ],
        desks: const [
          Desk(
            id: 'd1',
            workspaceId: 'ws-1',
            officeId: 'o1',
            name: 'Row A',
            bookableAsWhole: true,
            priceCents: 300,
            rect: GridRect(x: 0, y: 0, w: 4, h: 1),
          ),
        ],
        seats: [
          _seat('s1', 'd1', 0),
          _seat('s2', 'd1', 1, kind: ResourceKind.room),
          _seat('s3', 'd1', 2, kind: ResourceKind.parking),
        ],
      ),
    ),
  ],
  accessories: const [
    Accessory(
      id: 'a1',
      workspaceId: 'ws-1',
      name: 'Monitor',
      supplementCents: 200,
      active: true,
      sortOrder: 0,
      vatRateId: 'vat-20',
    ),
  ],
  seatAccessories: const {
    's1': {'a1'},
  },
  siteNames: const {'site-1': 'Centre'},
  vatRateLabels: const {'vat-20': '20 %'},
  configuration: const {
    'workspace': {
      'address': '4 rue Silène',
      'deposit': 12.5,
      'open': true,
      'vat': null,
      'bands': [
        {'from_pct': 0},
      ],
    },
  },
);

/// The reference path of [e]: a field inside a field is the one field.
String _pathOf(XmlElement e) {
  final names = <String>[];
  for (XmlNode? n = e; n is XmlElement; n = n.parent) {
    names.insert(0, n.name.local);
  }
  final path = names.join('/');
  return path.startsWith(configurationField) ? configurationField : path;
}

String? _typeProblem(XmlAttributeSpec a, String v) => switch (a.value) {
  XmlValue.integer when int.tryParse(v) == null => 'not an integer',
  XmlValue.count when (int.tryParse(v) ?? -1) < 0 => 'not a count',
  XmlValue.boolean when v != 'true' && v != 'false' => 'not a boolean',
  XmlValue.instant when DateTime.tryParse(v) == null => 'not an instant',
  XmlValue.word when !a.values.contains(v) => 'not one of ${a.values}',
  _ => null,
};

/// Every way [document] departs from the reference.
List<String> _problems(XmlDocument document, Set<String> used) {
  final specs = {for (final e in workspaceXmlElements) e.path: e};
  final problems = <String>[];
  for (final element in document.descendantElements) {
    final path = _pathOf(element);
    final spec = specs[path];
    if (spec == null) {
      problems.add('<$path> is not in the reference');
      continue;
    }
    final declared = {for (final a in spec.attributes) a.name: a};
    for (final attribute in element.attributes) {
      final name = attribute.name.local;
      final a = declared[name];
      if (a == null) {
        problems.add('<$path> @$name is not declared');
        continue;
      }
      used.add('$path@$name');
      final wrong = _typeProblem(a, attribute.value);
      if (wrong != null) {
        problems.add('<$path> @$name="${attribute.value}" $wrong');
      }
    }
    for (final a in spec.attributes) {
      if (a.required && element.getAttribute(a.name) == null) {
        problems.add('<$path> lacks required @${a.name}');
      }
    }
    final text = element.children.whereType<XmlText>().map((t) => t.value);
    if (!spec.text && text.any((t) => t.trim().isNotEmpty)) {
      problems.add('<$path> carries text');
    }
  }
  return problems;
}

void main() {
  test(
    'the published schema and its page are generated from the reference',
    () {
      expect(
        File('web/workspace-xml/schema.xsd').readAsStringSync(),
        workspaceXmlXsd(),
        reason: 'run: dart run tool/build_workspace_xml_schema.dart',
      );
      expect(
        File('web/workspace-xml/index.html').readAsStringSync(),
        workspaceXmlReferenceHtml(),
        reason: 'run: dart run tool/build_workspace_xml_schema.dart',
      );
    },
  );

  test('the XML Schema is well formed and declares every element', () {
    final xsd = XmlDocument.parse(workspaceXmlXsd());
    final types = {
      for (final t in xsd.findAllElements('xs:complexType'))
        t.getAttribute('name'),
    };
    expect(types, hasLength(workspaceXmlElements.length));
  });

  test('the reference describes the version the app writes', () {
    expect(workspaceXmlReferenceVersion, WorkspaceXmlSchema.version);
  });

  test('what the app writes validates against the reference, and uses '
      'every attribute it declares', () {
    final used = <String>{};
    final document = XmlDocument.parse(_richDocument());
    expect(_problems(document, used), isEmpty);
    expect(
      [
        for (final e in workspaceXmlElements)
          for (final a in e.attributes)
            if (!used.contains('${e.path}@${a.name}')) '${e.path}@${a.name}',
      ],
      isEmpty,
      reason:
          'a declared attribute the writer never wrote: either the '
          'fixture misses it or the reference names something that is not '
          'in the format',
    );
  });

  test('an undeclared attribute is a problem, not a pass', () {
    final document = XmlDocument.parse(
      _richDocument().replaceFirst('<seat ', '<seat colour="red" '),
    );
    expect(
      _problems(document, {}),
      contains(contains('@colour is not declared')),
    );
  });
}
