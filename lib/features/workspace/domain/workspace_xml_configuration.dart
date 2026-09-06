// SPDX-License-Identifier: 0BSD
import 'package:xml/xml.dart';

import 'workspace_xml.dart' show WorkspaceXmlError, WorkspaceXmlException;

/// The `<configuration>` section of schema v3 (#916): everything a
/// workspace IS beyond its settings and its floor plan — tariffs, legal
/// identity, the rules of the house, governance, the document designs,
/// the sites — as the server hands it over in one JSON tree
/// (`export_workspace_configuration`, migration 0177) and takes it back
/// (`import_workspace_configuration`).
///
/// The tree is written as typed, name-sorted XML:
/// ```xml
/// <configuration>
///   <field name="tables" type="object">
///     <field name="fee_bands" type="array">
///       <field type="object">
///         <field name="fee_cents" type="number">12000</field>
///         <field name="from_pct" type="number">0</field>
///       </field>
///     </field>
///   </field>
///   <field name="workspace" type="object">
///     <field name="booking_rules" type="object">…</field>
///     <field name="address" type="string" value="4 rue Silène"/>
///     <field name="invitation_template" type="string" value="Bonjour,&#10;…"/>
///     <field name="subscription_vat_rate" type="null"/>
///   </field>
/// </configuration>
/// ```
/// Every value carries its type, object members are sorted by name and
/// arrays keep their order, so the same tree always produces the same
/// bytes and export → import → export is provably identical. Strings
/// travel in the `value` attribute: line breaks and tabs are written as
/// character references, which XML attribute normalisation leaves alone
/// and the pretty-printer never touches (text content, by contrast, has
/// its whitespace collapsed by the printer).
///
/// The codec knows nothing about the domains inside: a new configuration
/// column on the server travels without a client release.
abstract final class WorkspaceXmlConfigurationSchema {
  static const String element = 'configuration';
  static const String fieldElement = 'field';
  static const String nameAttr = 'name';
  static const String typeAttr = 'type';
  static const String valueAttr = 'value';
  static const String typeString = 'string';
  static const String typeNumber = 'number';
  static const String typeBoolean = 'boolean';
  static const String typeNull = 'null';
  static const String typeObject = 'object';
  static const String typeArray = 'array';
}

/// Writes [configuration] as the `<configuration>` element.
void writeConfigurationXml(
  XmlBuilder builder,
  Map<String, Object?> configuration,
) {
  builder.element(WorkspaceXmlConfigurationSchema.element, nest: () {
    _writeMembers(builder, configuration);
  });
}

void _writeMembers(XmlBuilder builder, Map<String, Object?> members) {
  final names = members.keys.toList()..sort();
  for (final name in names) {
    _writeValue(builder, name, members[name]);
  }
}

void _writeValue(XmlBuilder builder, String? name, Object? value) {
  builder.element(WorkspaceXmlConfigurationSchema.fieldElement, nest: () {
    if (name != null) {
      builder.attribute(WorkspaceXmlConfigurationSchema.nameAttr, name);
    }
    switch (value) {
      case null:
        builder.attribute(WorkspaceXmlConfigurationSchema.typeAttr,
            WorkspaceXmlConfigurationSchema.typeNull);
      case bool v:
        builder.attribute(WorkspaceXmlConfigurationSchema.typeAttr,
            WorkspaceXmlConfigurationSchema.typeBoolean);
        builder.text('$v');
      case num v:
        builder.attribute(WorkspaceXmlConfigurationSchema.typeAttr,
            WorkspaceXmlConfigurationSchema.typeNumber);
        builder.text(canonicalConfigurationNumber(v));
      case String v:
        builder.attribute(WorkspaceXmlConfigurationSchema.typeAttr,
            WorkspaceXmlConfigurationSchema.typeString);
        builder.attribute(WorkspaceXmlConfigurationSchema.valueAttr, v);
      case Map<dynamic, dynamic> m:
        builder.attribute(WorkspaceXmlConfigurationSchema.typeAttr,
            WorkspaceXmlConfigurationSchema.typeObject);
        _writeMembers(builder, m.cast<String, Object?>());
      case List<dynamic> l:
        builder.attribute(WorkspaceXmlConfigurationSchema.typeAttr,
            WorkspaceXmlConfigurationSchema.typeArray);
        for (final item in l) {
          _writeValue(builder, null, item);
        }
      default:
        throw ArgumentError(
            'unsupported configuration value: ${value.runtimeType}');
    }
  });
}

/// One spelling per number: an integral value prints without a fraction
/// (`20.00` from a numeric column and `20` from an integer one are the
/// same configuration), everything else as Dart prints it.
String canonicalConfigurationNumber(num v) {
  if (v is int) return '$v';
  if (v.isFinite && v == v.roundToDouble() && v.abs() < 1e15) {
    return '${v.toInt()}';
  }
  return '$v';
}

/// Reads a `<configuration>` element back into the JSON tree.
Map<String, Object?> parseConfigurationXml(XmlElement element) =>
    _readMembers(element);

Map<String, Object?> _readMembers(XmlElement parent) {
  final members = <String, Object?>{};
  for (final field
      in parent.findElements(WorkspaceXmlConfigurationSchema.fieldElement)) {
    final name = field.getAttribute(WorkspaceXmlConfigurationSchema.nameAttr);
    if (name == null) {
      throw const WorkspaceXmlException(WorkspaceXmlError.missingAttribute,
          '<field> inside an object is missing "name"');
    }
    if (members.containsKey(name)) {
      throw WorkspaceXmlException(WorkspaceXmlError.invalidValue,
          'duplicate configuration field "$name"');
    }
    members[name] = _readValue(field);
  }
  return members;
}

Object? _readValue(XmlElement field) {
  final type = field.getAttribute(WorkspaceXmlConfigurationSchema.typeAttr);
  if (type == null) {
    throw const WorkspaceXmlException(WorkspaceXmlError.missingAttribute,
        '<field> is missing "type"');
  }
  switch (type) {
    case WorkspaceXmlConfigurationSchema.typeNull:
      return null;
    case WorkspaceXmlConfigurationSchema.typeBoolean:
      return switch (field.innerText.trim()) {
        'true' => true,
        'false' => false,
        final raw => throw WorkspaceXmlException(WorkspaceXmlError.invalidValue,
            '<field> boolean "$raw" is not true|false'),
      };
    case WorkspaceXmlConfigurationSchema.typeNumber:
      final raw = field.innerText.trim();
      final value = int.tryParse(raw) ?? double.tryParse(raw);
      if (value == null) {
        throw WorkspaceXmlException(WorkspaceXmlError.invalidValue,
            '<field> number "$raw" is not a number');
      }
      return value;
    case WorkspaceXmlConfigurationSchema.typeString:
      final value =
          field.getAttribute(WorkspaceXmlConfigurationSchema.valueAttr);
      if (value == null) {
        throw const WorkspaceXmlException(WorkspaceXmlError.missingAttribute,
            '<field> string is missing "value"');
      }
      return value;
    case WorkspaceXmlConfigurationSchema.typeObject:
      return _readMembers(field);
    case WorkspaceXmlConfigurationSchema.typeArray:
      return [
        for (final item in field
            .findElements(WorkspaceXmlConfigurationSchema.fieldElement))
          _readValue(item),
      ];
    default:
      throw WorkspaceXmlException(WorkspaceXmlError.invalidValue,
          '<field> type="$type" is not one of string|number|boolean|null|object|array');
  }
}

/// What the confirm dialog says about a configuration: how many
/// workspace-level settings and how many table rows it carries.
({int settings, int tables, int rows}) configurationCounts(
  Map<String, Object?> configuration,
) {
  final workspace = configuration['workspace'];
  final tables = configuration['tables'];
  var rows = 0;
  if (tables is Map) {
    for (final table in tables.values) {
      if (table is List) rows += table.length;
    }
  }
  return (
    settings: workspace is Map ? workspace.length : 0,
    tables: tables is Map ? tables.length : 0,
    rows: rows,
  );
}
