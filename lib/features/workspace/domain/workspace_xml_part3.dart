// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'workspace_xml.dart';


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
  );
}

/// v3 optional attributes: absent means the default (0 / false).
int _optionalInt(XmlElement element, String name) =>
    element.getAttribute(name) == null
        ? 0
        : _requireInt(element, name, min: 0);

bool _optionalBool(XmlElement element, String name) =>
    !(element.getAttribute(name) == null) && _requireBool(element, name);

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

/// Structural equality of two configuration trees (maps, lists, scalars).
bool _deepEquals(Object? a, Object? b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || !_deepEquals(a[key], b[key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}
