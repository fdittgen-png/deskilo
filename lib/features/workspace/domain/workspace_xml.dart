// SPDX-License-Identifier: MIT
import 'package:xml/xml.dart';

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
/// desks purely by nesting.
///
/// Schema v1:
/// ```xml
/// <?xml version="1.0" encoding="UTF-8"?>
/// <deskilo-workspace version="1">
///   <settings name country currency timezone>
///     <feature key enabled/>
///     <payment-instruction key value/>
///   </settings>
///   <floor-plan>
///     <level name sort-order>
///       <office name color bookable-as-whole x y w h>
///         <desk name x y w h>
///           <seat name x y orientation chair [blocked-from] [blocked-to]>
///             <amenity name/>
///           </seat>
///         </desk>
///       </office>
///     </level>
///   </floor-plan>
/// </deskilo-workspace>
/// ```
///
/// All timestamps are ISO-8601 UTC. Grid coordinates are absolute cells
/// exactly as stored (ADR 0005); a seat's x/y is its footprint's
/// top-left cell.
abstract final class WorkspaceXmlSchema {
  static const int version = 1;

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

/// A `<seat>`: THE bookable unit. x/y is the footprint's top-left cell.
class WorkspaceXmlSeat {
  const WorkspaceXmlSeat({
    required this.name,
    required this.x,
    required this.y,
    required this.orientation,
    this.chair = '',
    this.amenities = const [],
    this.blockedFrom,
    this.blockedTo,
  });

  final String name;
  final int x;
  final int y;
  final SeatOrientation orientation;
  final String chair;
  final List<String> amenities;
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
      other.blockedFrom == blockedFrom &&
      other.blockedTo == blockedTo;

  @override
  int get hashCode => Object.hash(name, x, y, orientation, chair,
      Object.hashAll(amenities), blockedFrom, blockedTo);
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

/// The whole parsed document: settings + floor-plan structure, no ids.
class WorkspaceXmlData {
  const WorkspaceXmlData({required this.settings, this.levels = const []});

  final WorkspaceXmlSettings settings;
  final List<WorkspaceXmlLevel> levels;

  @override
  bool operator ==(Object other) =>
      other is WorkspaceXmlData &&
      other.settings == settings &&
      _listEquals(other.levels, levels);

  @override
  int get hashCode => Object.hash(settings, Object.hashAll(levels));
}

// ---------------------------------------------------------------------------
// Export
// ---------------------------------------------------------------------------

/// Serializes the workspace configuration to schema-v1 XML. [levels]
/// pairs each level with its drawn plan; desks are nested under the
/// office whose id they reference and seats under their desk, so the
/// document carries no ids at all.
String buildWorkspaceXml({
  required Workspace workspace,
  required List<({Level level, FloorPlan plan})> levels,
}) {
  final sortedLevels = List.of(levels)
    ..sort((a, b) => a.level.sortOrder.compareTo(b.level.sortOrder));
  // Deterministic output: map-backed collections are emitted key-sorted.
  final flagKeys = workspace.featureFlags.keys.toList()..sort();
  final paymentKeys = workspace.paymentInstructions.keys.toList()..sort();

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
                    _seatElement(builder, seat);
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

void _seatElement(XmlBuilder builder, Seat seat) {
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
    for (final amenity in seat.amenities) {
      builder.element(WorkspaceXmlSchema.amenityElement, nest: () {
        builder.attribute(WorkspaceXmlSchema.nameAttr, amenity);
      });
    }
  });
}

// ---------------------------------------------------------------------------
// Import (the parser ships with #164 so round-trip tests pin the schema;
// the import UI is #165)
// ---------------------------------------------------------------------------

/// Parses and validates a schema-v1 document. Throws
/// [WorkspaceXmlException] on anything suspicious — never returns a
/// half-valid structure.
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
  final version =
      _requireAttribute(root, WorkspaceXmlSchema.versionAttr);
  if (version != '${WorkspaceXmlSchema.version}') {
    throw WorkspaceXmlException(WorkspaceXmlError.unsupportedVersion,
        'unsupported ${WorkspaceXmlSchema.versionAttr}="$version"');
  }

  final settingsElement =
      _requireElement(root, WorkspaceXmlSchema.settingsElement);
  final floorPlanElement =
      _requireElement(root, WorkspaceXmlSchema.floorPlanElement);

  return WorkspaceXmlData(
    settings: _parseSettings(settingsElement),
    levels: [
      for (final level
          in floorPlanElement.findElements(WorkspaceXmlSchema.levelElement))
        _parseLevel(level),
    ],
  );
}

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
