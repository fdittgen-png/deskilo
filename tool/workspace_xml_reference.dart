// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2862 — workspace XML v4, published. This is the CONTRACT, written by
// hand: every element the format knows, where it sits, its attributes,
// their types and the version that brought them. Two documents are
// generated from it (`tool/build_workspace_xml_schema.dart`): an XML
// Schema for validators and a reference page for people, both under
// `web/workspace-xml/`. A test validates what the app writes against it,
// so the writer cannot grow an attribute the published schema does not
// name. Enumerated values come from the domain enums the parser reads.
import 'package:deskilo/features/plan/domain/office.dart';
import 'package:deskilo/features/plan/domain/seat.dart';

/// What an attribute holds.
enum XmlValue {
  text('xs:string'),
  integer('xs:integer'),
  count('xs:nonNegativeInteger'),
  boolean('xs:boolean'),
  instant('xs:dateTime'),
  word('xs:string');

  const XmlValue(this.xsd);
  final String xsd;
}

class XmlAttributeSpec {
  const XmlAttributeSpec(
    this.name,
    this.value,
    this.doc, {
    this.required = false,
    this.since = 1,
    this.values = const [],
  });

  final String name;
  final XmlValue value;
  final String doc;
  final bool required;
  final int since;

  /// The words a [XmlValue.word] attribute takes.
  final List<String> values;
}

class XmlElementSpec {
  const XmlElementSpec(
    this.path,
    this.doc, {
    this.attributes = const [],
    this.since = 1,
    this.text = false,
  });

  /// Slash-separated from the root: `deskilo-workspace/settings/feature`.
  final String path;
  final String doc;
  final List<XmlAttributeSpec> attributes;
  final int since;

  /// Whether the element may carry text (a configuration number).
  final bool text;

  String get name => path.split('/').last;
  String? get parent =>
      path.contains('/') ? path.substring(0, path.lastIndexOf('/')) : null;
}

/// The version this reference describes.
const workspaceXmlReferenceVersion = 4;

const _root = 'deskilo-workspace';
const _plan = '$_root/floor-plan/level';
const _office = '$_plan/office';
const _desk = '$_office/desk';
const _seat = '$_desk/seat';

/// The `<field>` of `<configuration>`, which nests in itself.
const configurationField = '$_root/configuration/field';

const _rect = [
  XmlAttributeSpec(
    'x',
    XmlValue.count,
    'Left cell of the grid.',
    required: true,
  ),
  XmlAttributeSpec(
    'y',
    XmlValue.count,
    'Top cell of the grid.',
    required: true,
  ),
  XmlAttributeSpec('w', XmlValue.count, 'Width in cells.', required: true),
  XmlAttributeSpec('h', XmlValue.count, 'Height in cells.', required: true),
];

const _price = XmlAttributeSpec(
  'price-cents',
  XmlValue.integer,
  'Price in minor units of the currency; absent means free.',
  since: 3,
);

const _wholeBookable = XmlAttributeSpec(
  'bookable-as-whole',
  XmlValue.boolean,
  'Bookable as one place; absent means no.',
  since: 3,
);

/// Every element of v4, parents before children.
final workspaceXmlElements = <XmlElementSpec>[
  const XmlElementSpec(
    _root,
    'The document: one workspace configuration.',
    attributes: [
      XmlAttributeSpec(
        'version',
        XmlValue.count,
        'The format version; this app writes 4 and reads 1 to 4.',
        required: true,
      ),
    ],
  ),
  const XmlElementSpec(
    '$_root/settings',
    'The workspace itself.',
    attributes: [
      XmlAttributeSpec(
        'name',
        XmlValue.text,
        'Workspace name.',
        required: true,
      ),
      XmlAttributeSpec(
        'country',
        XmlValue.text,
        'ISO 3166-1 alpha-2 country code.',
        required: true,
      ),
      XmlAttributeSpec(
        'currency',
        XmlValue.text,
        'ISO 4217 currency code.',
        required: true,
      ),
      XmlAttributeSpec(
        'timezone',
        XmlValue.text,
        'IANA time zone, e.g. Europe/Paris.',
        required: true,
      ),
      XmlAttributeSpec(
        'brand-color',
        XmlValue.text,
        'Brand colour as #RRGGBB; absent means the product colours.',
        since: 3,
      ),
    ],
  ),
  const XmlElementSpec(
    '$_root/settings/feature',
    'One feature flag, by its stable key.',
    attributes: [
      XmlAttributeSpec('key', XmlValue.text, 'Feature key.', required: true),
      XmlAttributeSpec(
        'enabled',
        XmlValue.boolean,
        'Whether it is on.',
        required: true,
      ),
    ],
  ),
  const XmlElementSpec(
    '$_root/settings/payment-instruction',
    'One payment instruction printed on documents.',
    attributes: [
      XmlAttributeSpec(
        'key',
        XmlValue.text,
        'Instruction key.',
        required: true,
      ),
      XmlAttributeSpec('value', XmlValue.text, 'Its text.', required: true),
    ],
  ),
  const XmlElementSpec(
    '$_root/accessories',
    'The whole accessory catalogue, inactive entries included.',
    since: 2,
  ),
  const XmlElementSpec(
    '$_root/accessories/accessory',
    'One catalogue entry; seats refer to it by name.',
    since: 2,
    attributes: [
      XmlAttributeSpec(
        'name',
        XmlValue.text,
        'Unique name.',
        required: true,
        since: 2,
      ),
      XmlAttributeSpec(
        'supplement-cents',
        XmlValue.integer,
        'Supplement in minor units.',
        required: true,
        since: 2,
      ),
      XmlAttributeSpec(
        'active',
        XmlValue.boolean,
        'Offered to members.',
        required: true,
        since: 2,
      ),
      XmlAttributeSpec(
        'sort-order',
        XmlValue.integer,
        'Display order.',
        required: true,
        since: 2,
      ),
      XmlAttributeSpec(
        'vat-rate',
        XmlValue.text,
        'The VAT rate by its label.',
        since: 3,
      ),
    ],
  ),
  const XmlElementSpec('$_root/floor-plan', 'Every level, in its order.'),
  const XmlElementSpec(
    _plan,
    'A level (a floor).',
    attributes: [
      XmlAttributeSpec('name', XmlValue.text, 'Level name.', required: true),
      XmlAttributeSpec(
        'sort-order',
        XmlValue.integer,
        'Display order.',
        required: true,
      ),
      _price,
      _wholeBookable,
      XmlAttributeSpec(
        'site',
        XmlValue.text,
        'The site, by its name.',
        since: 3,
      ),
    ],
  ),
  XmlElementSpec(
    _office,
    'An area of the level: a room, a parking.',
    attributes: [
      const XmlAttributeSpec(
        'name',
        XmlValue.text,
        'Area name.',
        required: true,
      ),
      const XmlAttributeSpec(
        'color',
        XmlValue.integer,
        'Colour as a 32-bit ARGB number.',
        required: true,
      ),
      const XmlAttributeSpec(
        'bookable-as-whole',
        XmlValue.boolean,
        'Bookable as one place.',
        required: true,
      ),
      ..._rect,
      _price,
      XmlAttributeSpec(
        'area-kind',
        XmlValue.word,
        'What the area is; absent means a workspace.',
        since: 4,
        values: [for (final k in AreaKind.values) k.name],
      ),
    ],
  ),
  const XmlElementSpec(
    _desk,
    'A desk in its area.',
    attributes: [
      XmlAttributeSpec('name', XmlValue.text, 'Desk name.', required: true),
      ..._rect,
      _price,
      _wholeBookable,
    ],
  ),
  XmlElementSpec(
    _seat,
    'A bookable place at its desk.',
    attributes: [
      const XmlAttributeSpec(
        'name',
        XmlValue.text,
        'Seat name.',
        required: true,
      ),
      const XmlAttributeSpec(
        'x',
        XmlValue.count,
        'Column of the seat.',
        required: true,
      ),
      const XmlAttributeSpec(
        'y',
        XmlValue.count,
        'Row of the seat.',
        required: true,
      ),
      XmlAttributeSpec(
        'orientation',
        XmlValue.word,
        'Which way it faces.',
        required: true,
        values: [for (final o in SeatOrientation.values) o.name],
      ),
      const XmlAttributeSpec(
        'chair',
        XmlValue.text,
        'Chair description.',
        required: true,
      ),
      const XmlAttributeSpec(
        'nfc-uid',
        XmlValue.text,
        'The seat tag\'s UID, for check-in.',
        since: 3,
      ),
      XmlAttributeSpec(
        'resource-kind',
        XmlValue.word,
        'What the place is; absent means a desk seat.',
        since: 4,
        values: [for (final k in ResourceKind.values) k.name],
      ),
      const XmlAttributeSpec(
        'capacity',
        XmlValue.count,
        'People a meeting room holds.',
        since: 4,
      ),
      XmlAttributeSpec(
        'parking-kind',
        XmlValue.word,
        'What a bay is for.',
        since: 4,
        values: [for (final k in ParkingKind.values) k.name],
      ),
      const XmlAttributeSpec(
        'slot-minutes',
        XmlValue.count,
        'Length of a meeting room\'s booking slot.',
        since: 4,
      ),
      const XmlAttributeSpec(
        'blocked-from',
        XmlValue.instant,
        'Out of use from this instant (UTC).',
      ),
      const XmlAttributeSpec(
        'blocked-to',
        XmlValue.instant,
        'Out of use until this instant (UTC).',
      ),
    ],
  ),
  const XmlElementSpec(
    '$_seat/amenity',
    'A legacy amenity word, kept verbatim.',
    attributes: [
      XmlAttributeSpec('name', XmlValue.text, 'The word.', required: true),
    ],
  ),
  const XmlElementSpec(
    '$_seat/accessory',
    'A catalogue accessory assigned to the seat.',
    since: 2,
    attributes: [
      XmlAttributeSpec(
        'name',
        XmlValue.text,
        'The catalogue entry\'s name.',
        required: true,
        since: 2,
      ),
    ],
  ),
  const XmlElementSpec(
    '$_root/configuration',
    'Every other configuration domain (tariffs, legal identity, rules, '
        'designs, sites) as a typed tree. Secrets never travel.',
    since: 3,
  ),
  const XmlElementSpec(
    configurationField,
    'One value of the tree. Object members are sorted by name, array '
    'items keep their order; a field nests in a field.',
    since: 3,
    text: true,
    attributes: [
      XmlAttributeSpec(
        'name',
        XmlValue.text,
        'Member name; absent on an array item.',
        since: 3,
      ),
      XmlAttributeSpec(
        'type',
        XmlValue.word,
        'The value\'s type.',
        required: true,
        since: 3,
        values: ['string', 'number', 'boolean', 'null', 'object', 'array'],
      ),
      XmlAttributeSpec(
        'value',
        XmlValue.text,
        'A string\'s value; a number or a boolean is the text.',
        since: 3,
      ),
    ],
  ),
];

String _escape(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _typeName(XmlElementSpec e) =>
    e.path == configurationField ? 'field' : e.path.replaceAll('/', '.');

/// The XML Schema of v4. Children may come in any order and number; a
/// required attribute is `use="required"`.
String workspaceXmlXsd() {
  final b = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln(
      '<!-- Generated by tool/build_workspace_xml_schema.dart from '
      'tool/workspace_xml_reference.dart. Do not edit. -->',
    )
    ..writeln(
      '<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema" '
      'elementFormDefault="unqualified">',
    )
    ..writeln(
      '  <xs:element name="$_root" type="${_typeName(workspaceXmlElements.first)}"/>',
    );
  for (final e in workspaceXmlElements) {
    final children = [
      for (final c in workspaceXmlElements)
        if (c.parent == e.path) c,
      // A field nests in itself.
      if (e.path == configurationField) e,
    ];
    b
      ..writeln(
        '  <xs:complexType name="${_typeName(e)}"'
        '${e.text ? ' mixed="true"' : ''}>',
      )
      ..writeln(
        '    <xs:annotation><xs:documentation>${_escape(e.doc)}'
        '</xs:documentation></xs:annotation>',
      );
    if (children.isNotEmpty) {
      b.writeln('    <xs:choice minOccurs="0" maxOccurs="unbounded">');
      for (final c in children) {
        b.writeln(
          '      <xs:element name="${c.name}" '
          'type="${_typeName(c)}"/>',
        );
      }
      b.writeln('    </xs:choice>');
    }
    for (final a in e.attributes) {
      b.writeln(
        a.values.isEmpty
            ? '    <xs:attribute name="${a.name}" type="${a.value.xsd}"'
                  '${a.required ? ' use="required"' : ''}/>'
            : '    <xs:attribute name="${a.name}"'
                  '${a.required ? ' use="required"' : ''}>'
                  '<xs:simpleType><xs:restriction base="xs:string">'
                  '${[for (final v in a.values) '<xs:enumeration value="$v"/>'].join()}'
                  '</xs:restriction></xs:simpleType></xs:attribute>',
      );
    }
    b.writeln('  </xs:complexType>');
  }
  b.writeln('</xs:schema>');
  return b.toString();
}

/// The reference page: one section per element, its attributes in a table.
String workspaceXmlReferenceHtml() {
  final b = StringBuffer()
    ..writeln('<!doctype html>')
    ..writeln(
      '<!-- Generated by tool/build_workspace_xml_schema.dart from '
      'tool/workspace_xml_reference.dart. Do not edit. -->',
    )
    ..writeln('<html lang="en"><head><meta charset="utf-8">')
    ..writeln(
      '<meta name="viewport" content="width=device-width, '
      'initial-scale=1">',
    )
    ..writeln(
      '<title>DesKilo workspace XML v$workspaceXmlReferenceVersion'
      '</title>',
    )
    ..writeln(
      '<style>body{font:15px/1.5 system-ui,sans-serif;margin:0 auto;'
      'max-width:960px;padding:16px}code{background:#eef2f6;padding:0 3px}'
      'table{border-collapse:collapse;width:100%;margin:8px 0 24px}'
      'th,td{border-bottom:1px solid #d8dee4;padding:4px 8px;'
      'text-align:left;vertical-align:top}th{background:#eef2f6}'
      '.wrap{overflow-x:auto}</style></head><body>',
    )
    ..writeln('<h1>Workspace XML, version $workspaceXmlReferenceVersion</h1>')
    ..writeln(
      '<p>The file a workspace exports from Settings and imports '
      'back: its settings, accessory catalogue, floor plan and '
      'configuration. Ids, members, bookings, money and secrets never '
      'travel. Validate a file with <a href="schema.xsd">schema.xsd</a>. '
      'Times are ISO 8601 UTC; grid coordinates are cells.</p>',
    );
  for (final e in workspaceXmlElements) {
    b
      ..writeln('<h2 id="${_typeName(e)}"><code>&lt;${e.name}&gt;</code></h2>')
      ..writeln(
        '<p>In <code>${e.parent ?? '(root)'}</code>'
        '${e.since > 1 ? ' · since v${e.since}' : ''}. '
        '${_escape(e.doc)}</p>',
      );
    if (e.attributes.isEmpty) continue;
    b.writeln(
      '<div class="wrap"><table><tr><th>Attribute</th><th>Type</th>'
      '<th>Required</th><th>Since</th><th>Meaning</th></tr>',
    );
    for (final a in e.attributes) {
      final type = a.values.isEmpty
          ? a.value.xsd.substring(3)
          : a.values.join(' | ');
      b.writeln(
        '<tr><td><code>${a.name}</code></td><td>$type</td>'
        '<td>${a.required ? 'yes' : 'no'}</td><td>v${a.since}</td>'
        '<td>${_escape(a.doc)}</td></tr>',
      );
    }
    b.writeln('</table></div>');
  }
  b.writeln('</body></html>');
  return b.toString();
}
