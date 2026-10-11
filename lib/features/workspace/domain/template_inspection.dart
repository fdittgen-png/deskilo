// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1655 — what `inspect_workspace_template` (0266) says about a template,
// typed. The server walks the payload against `template_field_registry()`;
// the client never re-derives any of it: values are scalars or lists of
// scalars (a map is a shape, never copied), and an unknown wire word lands
// on `unknown`, never on a usable value.
import 'package:meta/meta.dart';

import '../../../core/data/json_reader.dart';
import 'template_outline.dart';
import 'template_preview.dart';

enum TemplateInspectionStatus {
  ok, unsupportedVersion, rejected, unknown;

  static TemplateInspectionStatus fromWire(String? raw) => switch (raw) {
        'ok' => ok,
        'unsupported_version' => unsupportedVersion,
        'rejected' => rejected,
        _ => unknown,
      };
}

/// Full profile, partial overlay, or an old floor-plan-only template
/// inspected under its legacy semantics.
enum TemplateProfile {
  full, partial, legacy, rejected, unknown;

  static TemplateProfile fromWire(String? raw) =>
      TemplateProfile.values.asNameMap()[raw] ?? unknown;
}

enum TemplateFieldDisposition {
  present, absent, reference, unsupported, excluded, stripped, unknown;

  static TemplateFieldDisposition fromWire(String? raw) =>
      TemplateFieldDisposition.values.asNameMap()[raw] ?? unknown;
}

/// What an absent value means, as the registry declares it.
enum TemplateAbsentMeaning {
  inherit, productDefault, registryDefault, required, unknown;

  static TemplateAbsentMeaning fromWire(String? raw) => switch (raw) {
        'inherit' => inherit,
        'product_default' => productDefault,
        'registry_default' => registryDefault,
        'required' => required,
        _ => unknown,
      };
}

/// A scalar or a list of scalars; anything else is dropped.
@visibleForTesting
Object? scalarOnly(Object? raw) {
  if (raw is String || raw is num || raw is bool || raw == null) return raw;
  if (raw is List && raw.every((e) => e is String || e is num || e is bool)) {
    return List<Object?>.unmodifiable(raw);
  }
  return null;
}

class TemplateFieldRecord {
  const TemplateFieldRecord({
    required this.path,
    required this.id,
    required this.disposition,
    this.value,
    this.shape,
    this.absent = TemplateAbsentMeaning.unknown,
    this.reason,
  });

  /// The concrete path (rows by natural key) and the registry id.
  final String path;
  final String id;
  final TemplateFieldDisposition disposition;
  final Object? value;
  final String? shape;
  final TemplateAbsentMeaning absent;
  final String? reason;

  factory TemplateFieldRecord.fromJson(Map<String, dynamic> json) {
    final r = JsonReader(json, context: 'template_field');
    return TemplateFieldRecord(
      path: r.string('path'),
      id: r.string('id'),
      disposition:
          TemplateFieldDisposition.fromWire(r.stringOrNull('disposition')),
      value: scalarOnly(r.json['value']),
      shape: r.stringOrNull('shape'),
      absent: TemplateAbsentMeaning.fromWire(r.stringOrNull('absent')),
      reason: r.stringOrNull('reason'),
    );
  }
}

class TemplateProblem {
  const TemplateProblem({required this.path, required this.problem, this.value, this.reason});
  final String path;

  /// `unknown_field`, `duplicate_key`, `carries_excluded`, `legacy_excluded`,
  /// `out_of_range`, `too_deep` or `unsupported_version`.
  final String problem;
  final Object? value;
  final String? reason;

  factory TemplateProblem.fromJson(Map<String, dynamic> json) {
    final r = JsonReader(json, context: 'template_problem');
    return TemplateProblem(
      path: r.string('path'),
      problem: r.string('problem'),
      value: scalarOnly(r.json['value']),
      reason: r.stringOrNull('reason'),
    );
  }
}

class TemplateRequiredInput {
  const TemplateRequiredInput({required this.path, required this.id, required this.binding, this.value, this.reason});
  final String path;
  final String id;

  /// `target`, or the natural key a reference could not resolve.
  final String binding;
  final Object? value;
  final String? reason;

  factory TemplateRequiredInput.fromJson(Map<String, dynamic> json) {
    final r = JsonReader(json, context: 'template_required_input');
    return TemplateRequiredInput(
      path: r.string('path'),
      id: r.string('id'),
      binding: r.string('binding'),
      value: scalarOnly(r.json['value']),
      reason: r.stringOrNull('reason'),
    );
  }
}

class TemplateExclusion {
  const TemplateExclusion({required this.id, required this.portability, this.reason});
  final String id, portability;
  final String? reason;

  factory TemplateExclusion.fromJson(Map<String, dynamic> json) {
    final r = JsonReader(json, context: 'template_exclusion');
    return TemplateExclusion(
      id: r.string('id'),
      portability: r.string('portability'),
      reason: r.stringOrNull('reason'),
    );
  }
}

class TemplateCoverage {
  const TemplateCoverage({this.registered = 0, this.present = 0, this.absent = 0, this.unknown = 0, this.requiredInputs = 0});
  final int registered, present, absent, unknown, requiredInputs;

  factory TemplateCoverage.fromJson(Map<String, dynamic> json) {
    final r = JsonReader(json, context: 'template_coverage');
    return TemplateCoverage(
      registered: r.intOrNull('registered') ?? 0,
      present: r.intOrNull('present') ?? 0,
      absent: r.intOrNull('absent') ?? 0,
      unknown: r.intOrNull('unknown') ?? 0,
      requiredInputs: r.intOrNull('required_inputs') ?? 0,
    );
  }
}

class TemplateInspection {
  const TemplateInspection({
    required this.templateId,
    required this.key,
    required this.name,
    required this.status,
    required this.profile,
    required this.compatibility,
    required this.outline,
    this.description = '',
    this.entities = const [],
    this.schemaVersion = 1,
    this.templateVersion = 1,
    this.supportedSchemaVersions = const [],
    this.registryRevision = '',
    this.schemaRevision = 0,
    this.digest,
    this.fields = const [],
    this.problems = const [],
    this.requiredInputs = const [],
    this.exclusions = const [],
    this.coverage = const TemplateCoverage(),
  });

  final String templateId;
  final String key;
  final String name;
  final String description;
  final List<String> entities;
  final int schemaVersion;
  final int templateVersion;
  final List<int> supportedSchemaVersions;

  final String registryRevision;
  final int schemaRevision;
  final TemplateInspectionStatus status;
  final TemplateProfile profile;
  final TemplateCompatibility compatibility;

  /// The same groups `template_outline` answers.
  final TemplateOutline outline;

  /// Null when the version is unsupported.
  final String? digest;
  final List<TemplateFieldRecord> fields;
  final List<TemplateProblem> problems;
  final List<TemplateRequiredInput> requiredInputs;
  final List<TemplateExclusion> exclusions;
  final TemplateCoverage coverage;

  bool get usable => status == TemplateInspectionStatus.ok && !outline.refused;

  factory TemplateInspection.fromJson(Map<String, dynamic> json) {
    final r = JsonReader(json, context: 'inspect_workspace_template');
    final tpl = r.objectOrNull('template') ?? JsonReader(const {});
    List<JsonReader> rows(String key) => [
      for (final row in r.list(key))
        if (row is Map) JsonReader.of(row, context: '${r.context}.$key'),
    ];
    return TemplateInspection(
      templateId: tpl.stringOr('id'),
      key: tpl.stringOr('key'),
      name: tpl.stringOr('name'),
      description: tpl.stringOr('description'),
      entities: [for (final e in tpl.list('entities')) '$e'],
      schemaVersion: tpl.intOrNull('schema_version') ?? 1,
      templateVersion: tpl.intOrNull('template_version') ?? 1,
      supportedSchemaVersions: [
        for (final v in r.list('supported_schema_versions'))
          if (v is num) v.toInt(),
      ],
      registryRevision: r.stringOr('registry_revision'),
      schemaRevision: r.intOrNull('schema_revision') ?? 0,
      status: TemplateInspectionStatus.fromWire(r.stringOrNull('status')),
      profile: TemplateProfile.fromWire(r.stringOrNull('profile')),
      compatibility:
          TemplateCompatibility.fromWire(r.stringOrNull('compatibility')),
      outline: TemplateOutline.fromJson({
        'compatibility': r.json['compatibility'],
        'reason': r.json['compatibility_reason'],
        'groups': r.json['outline'],
      }),
      digest: r.stringOrNull('digest'),
      fields: [for (final row in rows('fields')) TemplateFieldRecord.fromJson(row.json)],
      problems: [for (final row in rows('problems')) TemplateProblem.fromJson(row.json)],
      requiredInputs: [
        for (final row in rows('required_inputs'))
          TemplateRequiredInput.fromJson(row.json),
      ],
      exclusions: [
        for (final row in rows('exclusions')) TemplateExclusion.fromJson(row.json),
      ],
      coverage: TemplateCoverage.fromJson(r.objectOrEmpty('coverage')),
    );
  }
}
