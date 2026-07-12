// SPDX-License-Identifier: MIT
import 'package:xml/xml.dart';

import '../../plan/domain/accessory.dart';
import '../../plan/domain/floor_plan.dart';
import '../../plan/domain/grid_geometry.dart';
import '../../plan/domain/level.dart';
import '../../plan/domain/seat.dart';
import 'workspace.dart';

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
abstract final class WorkspaceXmlSchema {
  /// The version the app EXPORTS.
  static const int version = 2;

  /// The versions the parser ACCEPTS: v1 (pre-accessories, #164) and v2
  /// (#180). Anything else was exported by a newer app → unsupported.
  static const Set<int> supportedVersions = {1, 2};

  static const String rootElement = 'deskilo-workspace';
  static const String versionAttr = 'version';

  static const String settingsElement = 'settings';
  static const String nameAttr = 'name';
  static const String countryAttr = 'country';
  static const String currencyAttr = 'currency';
  static const String timezoneAttr = 'timezone';

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
}

/// Why a document was rejected. #165 maps each value to a localized
/// message; [WorkspaceXmlException.detail] carries the technical detail
/// (element/attribute path, offending value) for logs.
enum WorkspaceXmlError {
  /// Not well-formed XML at all.
  malformed,

  /// Well-formed XML but the root element is not `deskilo-workspace`.
  wrongRoot,

  /// A `version` we do not understand (newer app exported it).
  unsupportedVersion,

  /// A required element is missing.
  missingElement,

  /// A required attribute is missing.
  missingAttribute,

  /// An attribute value failed validation (bad int, unknown
  /// orientation, bad bool, bad timestamp, negative geometry, ...).
  invalidValue,
}

/// Typed parse failure (#164): [error] selects the user-facing message,
/// [detail] is for logging only — never shown to users.
class WorkspaceXmlException implements Exception {
  const WorkspaceXmlException(this.error, this.detail);

  final WorkspaceXmlError error;
  final String detail;

  @override
  String toString() => 'WorkspaceXmlException(${error.name}): $detail';
}

// ---------------------------------------------------------------------------
// Parsed structure (no ids — import regenerates them)
// ---------------------------------------------------------------------------

/// The `<settings>` block: everything the owner configures outside the
/// floor plan. No invite code — it is a secret and never exported.
class WorkspaceXmlSettings {
  const WorkspaceXmlSettings({
    required this.name,
    required this.countryCode,
    required this.currencyCode,
    required this.timezone,
    this.featureFlags = const {},
    this.paymentInstructions = const {},
  });

  final String name;
  final String countryCode;
  final String currencyCode;
  final String timezone;

  /// Explicit per-workspace feature overrides (#146). Absent key =
  /// registry default, exactly like [Workspace.featureFlags].
  final Map<String, bool> featureFlags;

  /// Owner payment instructions (#155) as opaque key/value pairs
  /// (`iban`, `paypal_me`, `reference`, ...). Empty values are dropped.
  final Map<String, String> paymentInstructions;

  @override
  bool operator ==(Object other) =>
      other is WorkspaceXmlSettings &&
      other.name == name &&
      other.countryCode == countryCode &&
      other.currencyCode == currencyCode &&
      other.timezone == timezone &&
      _mapEquals(other.featureFlags, featureFlags) &&
      _mapEquals(other.paymentInstructions, paymentInstructions);

  @override
  int get hashCode => Object.hash(name, countryCode, currencyCode, timezone,
      _mapHash(featureFlags), _mapHash(paymentInstructions));
}

/// An `<accessory>` catalog entry (v2, #180). Referenced from seats by
/// [name]; ids regenerate on import like everything else in the format.
class WorkspaceXmlAccessory {
  const WorkspaceXmlAccessory({
    required this.name,
    this.supplementCents = 0,
    this.active = true,
    this.sortOrder = 0,
  });

  final String name;
  final int supplementCents;
  final bool active;
  final int sortOrder;

  @override
  bool operator ==(Object other) =>
      other is WorkspaceXmlAccessory &&
      other.name == name &&
      other.supplementCents == supplementCents &&
      other.active == active &&
      other.sortOrder == sortOrder;

  @override
  int get hashCode => Object.hash(name, supplementCents, active, sortOrder);
}

/// A `<seat>`: THE bookable unit. x/y is the footprint's top-left cell.
class WorkspaceXmlSeat {
  const WorkspaceXmlSeat({
    required this.name,
    required this.x,
    required this.y,
    required this.orientation,
    this.chair = '',
    this.amenities = const [],
    this.accessoryNames = const [],
    this.blockedFrom,
    this.blockedTo,
  });

  final String name;
  final int x;
  final int y;
  final SeatOrientation orientation;
  final String chair;
  final List<String> amenities;

  /// Catalog references by name (v2, #180) — always empty in a v1 file.
  final List<String> accessoryNames;
  final DateTime? blockedFrom;
  final DateTime? blockedTo;

  @override
  bool operator ==(Object other) =>
      other is WorkspaceXmlSeat &&
      other.name == name &&
      other.x == x &&
      other.y == y &&
      other.orientation == orientation &&
      other.chair == chair &&
      _listEquals(other.amenities, amenities) &&
      _listEquals(other.accessoryNames, accessoryNames) &&
      other.blockedFrom == blockedFrom &&
      other.blockedTo == blockedTo;

  @override
  int get hashCode => Object.hash(name, x, y, orientation, chair,
      Object.hashAll(amenities), Object.hashAll(accessoryNames), blockedFrom,
      blockedTo);
}

/// A `<desk>` with its seats nested inside.
class WorkspaceXmlDesk {
  const WorkspaceXmlDesk({
    required this.name,
    required this.rect,
    this.seats = const [],
  });

  final String name;
  final GridRect rect;
  final List<WorkspaceXmlSeat> seats;

  @override
  bool operator ==(Object other) =>
      other is WorkspaceXmlDesk &&
      other.name == name &&
      other.rect == rect &&
      _listEquals(other.seats, seats);

  @override
  int get hashCode => Object.hash(name, rect, Object.hashAll(seats));
}

/// An `<office>` with its desks nested inside.
class WorkspaceXmlOffice {
  const WorkspaceXmlOffice({
    required this.name,
    required this.color,
    required this.bookableAsWhole,
    required this.rect,
    this.desks = const [],
  });

  final String name;
  final int color;
  final bool bookableAsWhole;
  final GridRect rect;
  final List<WorkspaceXmlDesk> desks;

  @override
  bool operator ==(Object other) =>
      other is WorkspaceXmlOffice &&
      other.name == name &&
      other.color == color &&
      other.bookableAsWhole == bookableAsWhole &&
      other.rect == rect &&
      _listEquals(other.desks, desks);

  @override
  int get hashCode =>
      Object.hash(name, color, bookableAsWhole, rect, Object.hashAll(desks));
}

/// A `<level>` (floor) with its offices nested inside.
class WorkspaceXmlLevel {
  const WorkspaceXmlLevel({
    required this.name,
    required this.sortOrder,
    this.offices = const [],
  });

  final String name;
  final int sortOrder;
  final List<WorkspaceXmlOffice> offices;

  @override
  bool operator ==(Object other) =>
      other is WorkspaceXmlLevel &&
      other.name == name &&
      other.sortOrder == sortOrder &&
      _listEquals(other.offices, offices);

  @override
  int get hashCode => Object.hash(name, sortOrder, Object.hashAll(offices));
}

/// The whole parsed document: settings + accessory catalog + floor-plan
/// structure, no ids. [accessories] is empty for a v1 file (#180).
class WorkspaceXmlData {
  const WorkspaceXmlData({
    required this.settings,
    this.accessories = const [],
    this.levels = const [],
  });

  final WorkspaceXmlSettings settings;
  final List<WorkspaceXmlAccessory> accessories;
  final List<WorkspaceXmlLevel> levels;

  @override
  bool operator ==(Object other) =>
      other is WorkspaceXmlData &&
      other.settings == settings &&
      _listEquals(other.accessories, accessories) &&
      _listEquals(other.levels, levels);

  @override
  int get hashCode => Object.hash(
      settings, Object.hashAll(accessories), Object.hashAll(levels));
}

// ---------------------------------------------------------------------------
// Export
// ---------------------------------------------------------------------------

/// Serializes the workspace configuration to schema-v2 XML. [levels]
/// pairs each level with its drawn plan; desks are nested under the
/// office whose id they reference and seats under their desk, so the
/// document carries no ids at all.
///
/// [accessories] is the WHOLE catalog (inactive included — a backup must
/// be complete, #180) and [seatAccessories] the seat id → accessory ids
/// assignments; both serialize id-free, seats referencing accessories by
/// name in catalog order.
String buildWorkspaceXml({
  required Workspace workspace,
  required List<({Level level, FloorPlan plan})> levels,
  List<Accessory> accessories = const [],
  Map<String, Set<String>> seatAccessories = const {},
}) {
  final sortedLevels = List.of(levels)
    ..sort((a, b) => a.level.sortOrder.compareTo(b.level.sortOrder));
  // Deterministic output: map-backed collections are emitted key-sorted,
  // the catalog in its display order (sort_order, then name — the order
  // the repository serves, re-established here for raw inputs).
  final flagKeys = workspace.featureFlags.keys.toList()..sort();
  final paymentKeys = workspace.paymentInstructions.keys.toList()..sort();
  final sortedAccessories = List.of(accessories)
    ..sort((a, b) {
      final bySortOrder = a.sortOrder.compareTo(b.sortOrder);
      return bySortOrder != 0 ? bySortOrder : a.name.compareTo(b.name);
    });

  final builder = XmlBuilder();
  builder.declaration(encoding: 'UTF-8');
  builder.element(WorkspaceXmlSchema.rootElement, nest: () {
    builder.attribute(
        WorkspaceXmlSchema.versionAttr, '${WorkspaceXmlSchema.version}');
    builder.element(WorkspaceXmlSchema.settingsElement, nest: () {
      builder.attribute(WorkspaceXmlSchema.nameAttr, workspace.name);
      builder.attribute(
          WorkspaceXmlSchema.countryAttr, workspace.countryCode);
      builder.attribute(
          WorkspaceXmlSchema.currencyAttr, workspace.currencyCode);
      builder.attribute(WorkspaceXmlSchema.timezoneAttr, workspace.timezone);
      for (final key in flagKeys) {
        final value = workspace.featureFlags[key];
        if (value is! bool) continue; // defensive: only bools are flags
        builder.element(WorkspaceXmlSchema.featureElement, nest: () {
          builder.attribute(WorkspaceXmlSchema.keyAttr, key);
          builder.attribute(WorkspaceXmlSchema.enabledAttr, '$value');
        });
      }
      for (final key in paymentKeys) {
        final value = workspace.paymentInstructions[key];
        if (value is! String || value.trim().isEmpty) continue;
        builder.element(WorkspaceXmlSchema.paymentInstructionElement,
            nest: () {
          builder.attribute(WorkspaceXmlSchema.keyAttr, key);
          builder.attribute(WorkspaceXmlSchema.valueAttr, value);
        });
      }
    });
    builder.element(WorkspaceXmlSchema.accessoriesElement, nest: () {
      for (final accessory in sortedAccessories) {
        builder.element(WorkspaceXmlSchema.accessoryElement, nest: () {
          builder.attribute(WorkspaceXmlSchema.nameAttr, accessory.name);
          builder.attribute(WorkspaceXmlSchema.supplementCentsAttr,
              '${accessory.supplementCents}');
          builder.attribute(
              WorkspaceXmlSchema.activeAttr, '${accessory.active}');
          builder.attribute(
              WorkspaceXmlSchema.sortOrderAttr, '${accessory.sortOrder}');
        });
      }
    });
    builder.element(WorkspaceXmlSchema.floorPlanElement, nest: () {
      for (final entry in sortedLevels) {
        builder.element(WorkspaceXmlSchema.levelElement, nest: () {
          builder.attribute(WorkspaceXmlSchema.nameAttr, entry.level.name);
          builder.attribute(
              WorkspaceXmlSchema.sortOrderAttr, '${entry.level.sortOrder}');
          for (final office in entry.plan.offices) {
            builder.element(WorkspaceXmlSchema.officeElement, nest: () {
              builder.attribute(WorkspaceXmlSchema.nameAttr, office.name);
              builder.attribute(
                  WorkspaceXmlSchema.colorAttr, '${office.color}');
              builder.attribute(WorkspaceXmlSchema.bookableAsWholeAttr,
                  '${office.bookableAsWhole}');
              _rectAttributes(builder, office.rect);
              for (final desk in entry.plan.desksOf(office.id)) {
                builder.element(WorkspaceXmlSchema.deskElement, nest: () {
                  builder.attribute(WorkspaceXmlSchema.nameAttr, desk.name);
                  _rectAttributes(builder, desk.rect);
                  for (final seat in entry.plan.seatsOf(desk.id)) {
                    // Assigned catalog entries, referenced by NAME in
                    // catalog order — ids never enter the document.
                    final assignedIds =
                        seatAccessories[seat.id] ?? const <String>{};
                    _seatElement(builder, seat, [
                      for (final accessory in sortedAccessories)
                        if (assignedIds.contains(accessory.id)) accessory.name,
                    ]);
                  }
                });
              }
            });
          }
        });
      }
    });
  });
  return builder.buildDocument().toXmlString(pretty: true, indent: '  ');
}

/// `deskilo-<slugified name>.xml` — the file name handed to the share
/// sheet; pure so tests can pin it.
String workspaceXmlFileName(String workspaceName) {
  final slug = workspaceName
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp('^-+|-+\$'), '');
  return 'deskilo-${slug.isEmpty ? 'workspace' : slug}.xml';
}

void _rectAttributes(XmlBuilder builder, GridRect rect) {
  builder.attribute(WorkspaceXmlSchema.xAttr, '${rect.x}');
  builder.attribute(WorkspaceXmlSchema.yAttr, '${rect.y}');
  builder.attribute(WorkspaceXmlSchema.wAttr, '${rect.w}');
  builder.attribute(WorkspaceXmlSchema.hAttr, '${rect.h}');
}

void _seatElement(
    XmlBuilder builder, Seat seat, List<String> accessoryNames) {
  builder.element(WorkspaceXmlSchema.seatElement, nest: () {
    builder.attribute(WorkspaceXmlSchema.nameAttr, seat.name);
    builder.attribute(WorkspaceXmlSchema.xAttr, '${seat.x}');
    builder.attribute(WorkspaceXmlSchema.yAttr, '${seat.y}');
    builder.attribute(
        WorkspaceXmlSchema.orientationAttr, seat.orientation.name);
    builder.attribute(WorkspaceXmlSchema.chairAttr, seat.chair);
    final from = seat.blockedFrom;
    if (from != null) {
      builder.attribute(WorkspaceXmlSchema.blockedFromAttr,
          from.toUtc().toIso8601String());
    }
    final to = seat.blockedTo;
    if (to != null) {
      builder.attribute(
          WorkspaceXmlSchema.blockedToAttr, to.toUtc().toIso8601String());
    }
    // Legacy amenities keep exporting verbatim (fidelity of the
    // seats.amenities column) ALONGSIDE the v2 catalog references.
    for (final amenity in seat.amenities) {
      builder.element(WorkspaceXmlSchema.amenityElement, nest: () {
        builder.attribute(WorkspaceXmlSchema.nameAttr, amenity);
      });
    }
    for (final name in accessoryNames) {
      builder.element(WorkspaceXmlSchema.accessoryElement, nest: () {
        builder.attribute(WorkspaceXmlSchema.nameAttr, name);
      });
    }
  });
}

// ---------------------------------------------------------------------------
// Import (the parser ships with #164 so round-trip tests pin the schema;
// the import UI is #165)
// ---------------------------------------------------------------------------

/// Parses and validates a schema-v1 OR schema-v2 document (#180). Throws
/// [WorkspaceXmlException] on anything suspicious — never returns a
/// half-valid structure. A v1 document (no `<accessories>`, no seat
/// `<accessory>` refs) parses to an empty catalog; version 3+ →
/// [WorkspaceXmlError.unsupportedVersion].
WorkspaceXmlData parseWorkspaceXml(String input) {
  final XmlElement root;
  try {
    // rootElement throws StateError on a rootless (comments-only) doc.
    root = XmlDocument.parse(input).rootElement;
    // Both catches only translate to the typed error — nothing to log here;
    // the caller (#165 UI) traces the typed exception with its own stack.
    // ignore: catch_no_st
  } on XmlException catch (e) {
    throw WorkspaceXmlException(WorkspaceXmlError.malformed, e.message);
    // ignore: catch_no_st
  } on StateError catch (e) {
    throw WorkspaceXmlException(WorkspaceXmlError.malformed, e.message);
  }
  if (root.name.local != WorkspaceXmlSchema.rootElement) {
    throw WorkspaceXmlException(WorkspaceXmlError.wrongRoot,
        'expected <${WorkspaceXmlSchema.rootElement}>, got <${root.name.local}>');
  }
  final rawVersion =
      _requireAttribute(root, WorkspaceXmlSchema.versionAttr);
  final version = int.tryParse(rawVersion);
  if (version == null ||
      !WorkspaceXmlSchema.supportedVersions.contains(version)) {
    throw WorkspaceXmlException(WorkspaceXmlError.unsupportedVersion,
        'unsupported ${WorkspaceXmlSchema.versionAttr}="$rawVersion"');
  }

  final settingsElement =
      _requireElement(root, WorkspaceXmlSchema.settingsElement);
  final floorPlanElement =
      _requireElement(root, WorkspaceXmlSchema.floorPlanElement);
  // Optional in BOTH versions: absent in every v1 file, and a v2 export
  // of a catalog-less workspace round-trips through an empty element.
  final accessoriesElement =
      root.getElement(WorkspaceXmlSchema.accessoriesElement);

  final data = WorkspaceXmlData(
    settings: _parseSettings(settingsElement),
    accessories: [
      if (accessoriesElement != null)
        for (final accessory in accessoriesElement
            .findElements(WorkspaceXmlSchema.accessoryElement))
          _parseAccessory(accessory),
    ],
    levels: [
      for (final level
          in floorPlanElement.findElements(WorkspaceXmlSchema.levelElement))
        _parseLevel(level),
    ],
  );
  _validateAccessoryRefs(data);
  return data;
}

/// Cross-checks the v2 accessory references (#180): catalog names must be
/// unique (the DB upserts by (workspace_id, name)) and every seat ref
/// must resolve to a catalog entry — the server would raise 'malformed
/// plan: unknown accessory', but a typed client error is clearer.
void _validateAccessoryRefs(WorkspaceXmlData data) {
  final catalogNames = <String>{};
  for (final accessory in data.accessories) {
    if (!catalogNames.add(accessory.name)) {
      throw WorkspaceXmlException(WorkspaceXmlError.invalidValue,
          'duplicate <${WorkspaceXmlSchema.accessoryElement}> '
          '${WorkspaceXmlSchema.nameAttr}="${accessory.name}" in the catalog');
    }
  }
  for (final level in data.levels) {
    for (final office in level.offices) {
      for (final desk in office.desks) {
        for (final seat in desk.seats) {
          for (final name in seat.accessoryNames) {
            if (!catalogNames.contains(name)) {
              throw WorkspaceXmlException(WorkspaceXmlError.invalidValue,
                  'seat "${seat.name}" references unknown accessory "$name"');
            }
          }
        }
      }
    }
  }
}

WorkspaceXmlAccessory _parseAccessory(XmlElement element) =>
    WorkspaceXmlAccessory(
      name: _requireAttribute(element, WorkspaceXmlSchema.nameAttr),
      supplementCents: _requireInt(
          element, WorkspaceXmlSchema.supplementCentsAttr, min: 0),
      active: _requireBool(element, WorkspaceXmlSchema.activeAttr),
      sortOrder:
          _requireInt(element, WorkspaceXmlSchema.sortOrderAttr, min: 0),
    );

WorkspaceXmlSettings _parseSettings(XmlElement element) {
  final featureFlags = <String, bool>{};
  for (final feature
      in element.findElements(WorkspaceXmlSchema.featureElement)) {
    featureFlags[_requireAttribute(feature, WorkspaceXmlSchema.keyAttr)] =
        _requireBool(feature, WorkspaceXmlSchema.enabledAttr);
  }
  final paymentInstructions = <String, String>{};
  for (final instruction in element
      .findElements(WorkspaceXmlSchema.paymentInstructionElement)) {
    paymentInstructions[
            _requireAttribute(instruction, WorkspaceXmlSchema.keyAttr)] =
        _requireAttribute(instruction, WorkspaceXmlSchema.valueAttr);
  }
  return WorkspaceXmlSettings(
    name: _requireAttribute(element, WorkspaceXmlSchema.nameAttr),
    countryCode: _requireAttribute(element, WorkspaceXmlSchema.countryAttr),
    currencyCode: _requireAttribute(element, WorkspaceXmlSchema.currencyAttr),
    timezone: _requireAttribute(element, WorkspaceXmlSchema.timezoneAttr),
    featureFlags: featureFlags,
    paymentInstructions: paymentInstructions,
  );
}

WorkspaceXmlLevel _parseLevel(XmlElement element) => WorkspaceXmlLevel(
      name: _requireAttribute(element, WorkspaceXmlSchema.nameAttr),
      sortOrder:
          _requireInt(element, WorkspaceXmlSchema.sortOrderAttr, min: 0),
      offices: [
        for (final office
            in element.findElements(WorkspaceXmlSchema.officeElement))
          _parseOffice(office),
      ],
    );

WorkspaceXmlOffice _parseOffice(XmlElement element) => WorkspaceXmlOffice(
      name: _requireAttribute(element, WorkspaceXmlSchema.nameAttr),
      color: _requireInt(element, WorkspaceXmlSchema.colorAttr, min: 0),
      bookableAsWhole:
          _requireBool(element, WorkspaceXmlSchema.bookableAsWholeAttr),
      rect: _parseRect(element),
      desks: [
        for (final desk
            in element.findElements(WorkspaceXmlSchema.deskElement))
          _parseDesk(desk),
      ],
    );

WorkspaceXmlDesk _parseDesk(XmlElement element) => WorkspaceXmlDesk(
      name: _requireAttribute(element, WorkspaceXmlSchema.nameAttr),
      rect: _parseRect(element),
      seats: [
        for (final seat
            in element.findElements(WorkspaceXmlSchema.seatElement))
          _parseSeat(seat),
      ],
    );

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
  );
}

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

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _mapEquals<V>(Map<String, V> a, Map<String, V> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key) || b[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}

int _mapHash<V>(Map<String, V> map) => Object.hashAllUnordered(
    map.entries.map((e) => Object.hash(e.key, e.value)));
