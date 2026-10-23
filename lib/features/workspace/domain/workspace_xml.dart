// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:xml/xml.dart';

import '../../plan/domain/accessory.dart';
import '../../plan/domain/floor_plan.dart';
import '../../plan/domain/grid_geometry.dart';
import '../../plan/domain/level.dart';
import '../../plan/domain/seat.dart';
import 'workspace.dart';
import 'workspace_branding.dart';
import 'workspace_xml_configuration.dart';
import 'workspace_xml_model.dart';

export 'workspace_xml_model.dart';

part 'workspace_xml_part2.dart';


/// Versioned XML interchange format for a workspace configuration
/// (#164, Epic #162): the owner-editable settings plus the full floor
/// plan. Deliberately excluded: the invite code (a secret) and all
/// member / reservation / ledger data. Ids are NOT part of the format —
/// import (#165) regenerates them; desks belong to offices and seats to
/// desks purely by nesting, and seats reference accessories by NAME.
///
/// Schema v2 (#180 — v1 plus the accessory catalog and per-seat
/// assignments the editor writes since #168):
/// ```xml
/// <?xml version="1.0" encoding="UTF-8"?>
/// <deskilo-workspace version="2">
///   <settings name country currency timezone>
///     <feature key enabled/>
///     <payment-instruction key value/>
///   </settings>
///   <accessories>
///     <accessory name supplement-cents active sort-order/>
///   </accessories>
///   <floor-plan>
///     <level name sort-order>
///       <office name color bookable-as-whole x y w h>
///         <desk name x y w h>
///           <seat name x y orientation chair [blocked-from] [blocked-to]>
///             <amenity name/>
///             <accessory name/>
///           </seat>
///         </desk>
///       </office>
///     </level>
///   </floor-plan>
/// </deskilo-workspace>
/// ```
///
/// The `<accessories>` catalog is complete — inactive entries included, a
/// backup must restore everything. A seat's `<accessory name/>` children
/// reference catalog entries by name (ids regenerate on import); its
/// legacy `<amenity name/>` children keep mirroring `seats.amenities`
/// verbatim. A v1 document simply has no `<accessories>` section and no
/// seat `<accessory>` children — it parses to an empty catalog.
///
/// All timestamps are ISO-8601 UTC. Grid coordinates are absolute cells
/// exactly as stored (ADR 0005); a seat's x/y is its footprint's
/// top-left cell.
///
/// Schema v3 (#916 — the exported space IS the space): v2 plus
/// - a `<configuration>` section carrying every configuration domain
///   the settings block does not (tariffs, legal identity, booking and
///   validation rules, governance, document designs, sites, closure
///   days, document links) as a typed tree — see
///   `workspace_xml_configuration.dart`; absent in a v1/v2 file;
/// - the plan attributes v2 dropped: `price-cents` and
///   `bookable-as-whole` on levels and desks, `price-cents` on offices,
///   `site` (the site's name) on levels, `nfc-uid` on seats, `vat-rate`
///   (the rate's label) on catalogue accessories — every one optional,
///   so a v2 document is a valid v3 document.
/// Secrets never travel: the invite code, the e-invoice and payment
/// provider credentials. Neither does anything transactional.
abstract final class WorkspaceXmlSchema {
  /// The version the app EXPORTS.
  static const int version = 4;

  /// The versions the parser ACCEPTS: v1 (pre-accessories, #164), v2
  /// (#180), v3 (#916) and v4 (#2860). Anything else was exported by a
  /// newer app → unsupported.
  static const Set<int> supportedVersions = {1, 2, 3, 4};

  static const String rootElement = 'deskilo-workspace';
  static const String versionAttr = 'version';

  static const String settingsElement = 'settings';
  static const String nameAttr = 'name';
  static const String countryAttr = 'country';
  static const String currencyAttr = 'currency';
  static const String timezoneAttr = 'timezone';

  /// #1289 — the brand seed on `<settings>`, `#RRGGBB`; optional.
  static const String brandColorAttr = 'brand-color';

  static const String featureElement = 'feature';
  static const String keyAttr = 'key';
  static const String enabledAttr = 'enabled';
  static const String paymentInstructionElement = 'payment-instruction';
  static const String valueAttr = 'value';

  static const String floorPlanElement = 'floor-plan';
  static const String levelElement = 'level';
  static const String sortOrderAttr = 'sort-order';
  static const String officeElement = 'office';
  static const String colorAttr = 'color';
  static const String bookableAsWholeAttr = 'bookable-as-whole';
  static const String deskElement = 'desk';
  static const String seatElement = 'seat';
  static const String xAttr = 'x';
  static const String yAttr = 'y';
  static const String wAttr = 'w';
  static const String hAttr = 'h';
  static const String orientationAttr = 'orientation';
  static const String chairAttr = 'chair';
  static const String blockedFromAttr = 'blocked-from';
  static const String blockedToAttr = 'blocked-to';
  static const String amenityElement = 'amenity';

  // v2 (#180): accessory catalog + per-seat references by name.
  static const String accessoriesElement = 'accessories';
  static const String accessoryElement = 'accessory';
  static const String supplementCentsAttr = 'supplement-cents';
  static const String activeAttr = 'active';

  // v3 (#916): plan attributes and the configuration section.
  static const String priceCentsAttr = 'price-cents';
  static const String siteAttr = 'site';
  static const String nfcUidAttr = 'nfc-uid';

  // v4 (#2860): what kind of place a seat is — a desk seat, a meeting room
  // with its capacity and slot, a parking bay — and an area's kind. All
  // optional: a v3 file reads as seats in workspace areas, as before.
  static const String resourceKindAttr = 'resource-kind';
  static const String capacityAttr = 'capacity';
  static const String parkingKindAttr = 'parking-kind';
  static const String slotMinutesAttr = 'slot-minutes';
  static const String areaKindAttr = 'area-kind';
  static const String vatRateAttr = 'vat-rate';
  static const String configurationElement =
      WorkspaceXmlConfigurationSchema.element;
}

WorkspaceXmlSeat _parseSeat(XmlElement element) {
  final rawOrientation =
      _requireAttribute(element, WorkspaceXmlSchema.orientationAttr);
  SeatOrientation? orientation;
  for (final candidate in SeatOrientation.values) {
    if (candidate.name == rawOrientation) orientation = candidate;
  }
  if (orientation == null) {
    throw WorkspaceXmlException(WorkspaceXmlError.invalidValue,
        '<${element.name.local}> ${WorkspaceXmlSchema.orientationAttr}='
        '"$rawOrientation" is not one of '
        '${SeatOrientation.values.map((o) => o.name).join('|')}');
  }
  return WorkspaceXmlSeat(
    name: _requireAttribute(element, WorkspaceXmlSchema.nameAttr),
    x: _requireInt(element, WorkspaceXmlSchema.xAttr, min: 0),
    y: _requireInt(element, WorkspaceXmlSchema.yAttr, min: 0),
    orientation: orientation,
    chair: element.getAttribute(WorkspaceXmlSchema.chairAttr) ?? '',
    amenities: [
      for (final amenity
          in element.findElements(WorkspaceXmlSchema.amenityElement))
        _requireAttribute(amenity, WorkspaceXmlSchema.nameAttr),
    ],
    accessoryNames: [
      for (final accessory
          in element.findElements(WorkspaceXmlSchema.accessoryElement))
        _requireAttribute(accessory, WorkspaceXmlSchema.nameAttr),
    ],
    blockedFrom: _optionalUtc(element, WorkspaceXmlSchema.blockedFromAttr),
    blockedTo: _optionalUtc(element, WorkspaceXmlSchema.blockedToAttr),
    nfcUid: element.getAttribute(WorkspaceXmlSchema.nfcUidAttr) ?? '',
    resourceKind: _optionalEnum(
            element, WorkspaceXmlSchema.resourceKindAttr, ResourceKind.values) ??
        ResourceKind.seat,
    capacity: _nullableInt(element, WorkspaceXmlSchema.capacityAttr),
    parkingKind: _optionalEnum(
        element, WorkspaceXmlSchema.parkingKindAttr, ParkingKind.values),
    slotMinutes: _nullableInt(element, WorkspaceXmlSchema.slotMinutesAttr),
  );
}

/// v4 — an optional enum attribute, by its name; absent reads as null, an
/// unknown word is refused with the words it may be.
T? _optionalEnum<T extends Enum>(
    XmlElement element, String attribute, List<T> values) {
  final raw = element.getAttribute(attribute);
  if (raw == null || raw.isEmpty) return null;
  for (final v in values) {
    if (v.name == raw) return v;
  }
  throw WorkspaceXmlException(WorkspaceXmlError.invalidValue,
      '<${element.name.local}> $attribute="$raw" is not one of '
      '${values.map((v) => v.name).join('|')}');
}

/// v4 — an optional whole number; absent reads as null.
int? _nullableInt(XmlElement element, String attribute) =>
    element.getAttribute(attribute) == null
        ? null
        : _requireInt(element, attribute, min: 1);

/// v3 optional attributes: absent means the default (0 / false).
int _optionalInt(XmlElement element, String name) =>
    element.getAttribute(name) == null
        ? 0
        : _requireInt(element, name, min: 0);

bool _optionalBool(XmlElement element, String name) =>
    element.getAttribute(name) != null && _requireBool(element, name);

GridRect _parseRect(XmlElement element) => GridRect(
      x: _requireInt(element, WorkspaceXmlSchema.xAttr, min: 0),
      y: _requireInt(element, WorkspaceXmlSchema.yAttr, min: 0),
      // GridRect cell counts are strictly positive (ADR 0005).
      w: _requireInt(element, WorkspaceXmlSchema.wAttr, min: 1),
      h: _requireInt(element, WorkspaceXmlSchema.hAttr, min: 1),
    );

XmlElement _requireElement(XmlElement parent, String name) {
  final element = parent.getElement(name);
  if (element == null) {
    throw WorkspaceXmlException(WorkspaceXmlError.missingElement,
        '<${parent.name.local}> has no <$name>');
  }
  return element;
}

String _requireAttribute(XmlElement element, String name) {
  final value = element.getAttribute(name);
  if (value == null) {
    throw WorkspaceXmlException(WorkspaceXmlError.missingAttribute,
        '<${element.name.local}> is missing "$name"');
  }
  return value;
}

int _requireInt(XmlElement element, String name, {required int min}) {
  final raw = _requireAttribute(element, name);
  final value = int.tryParse(raw);
  if (value == null || value < min) {
    throw WorkspaceXmlException(WorkspaceXmlError.invalidValue,
        '<${element.name.local}> $name="$raw" is not an integer >= $min');
  }
  return value;
}

bool _requireBool(XmlElement element, String name) {
  final raw = _requireAttribute(element, name);
  return switch (raw) {
    'true' => true,
    'false' => false,
    _ => throw WorkspaceXmlException(WorkspaceXmlError.invalidValue,
        '<${element.name.local}> $name="$raw" is not true|false'),
  };
}

DateTime? _optionalUtc(XmlElement element, String name) {
  final raw = element.getAttribute(name);
  if (raw == null) return null;
  final value = DateTime.tryParse(raw);
  if (value == null) {
    throw WorkspaceXmlException(WorkspaceXmlError.invalidValue,
        '<${element.name.local}> $name="$raw" is not an ISO-8601 timestamp');
  }
  return value.toUtc();
}
