// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1655 — what `inspect_workspace_template` (0266) says about a template,
// typed. The server walks the payload against `template_field_registry()`;
// the client never re-derives any of it: values are scalars or lists of
// scalars (a map is a shape, never copied), and an unknown wire word lands
// on `unknown`, never on a usable value.
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

  factory TemplateFieldRecord.fromJson(Map<String, dynamic> json) =>
      TemplateFieldRecord(
        path: '${json['path']}',
        id: '${json['id']}',
        disposition: TemplateFieldDisposition.fromWire(json['disposition'] as String?),
        value: scalarOnly(json['value']),
        shape: json['shape'] as String?,
        absent: TemplateAbsentMeaning.fromWire(json['absent'] as String?),
        reason: json['reason'] as String?,
      );
}

class TemplateProblem {
  const TemplateProblem({required this.path, required this.problem, this.value, this.reason});
  final String path;

  /// `unknown_field`, `duplicate_key`, `carries_excluded`, `legacy_excluded`,
  /// `out_of_range`, `too_deep` or `unsupported_version`.
  final String problem;
  final Object? value;
  final String? reason;

  factory TemplateProblem.fromJson(Map<String, dynamic> json) => TemplateProblem(
        path: '${json['path']}',
        problem: '${json['problem']}',
        value: scalarOnly(json['value']),
        reason: json['reason'] as String?,
      );
}

class TemplateRequiredInput {
  const TemplateRequiredInput({required this.path, required this.id, required this.binding, this.value, this.reason});
  final String path;
  final String id;

  /// `target`, or the natural key a reference could not resolve.
  final String binding;
  final Object? value;
  final String? reason;

  factory TemplateRequiredInput.fromJson(Map<String, dynamic> json) => TemplateRequiredInput(
        path: '${json['path']}',
        id: '${json['id']}',
        binding: '${json['binding']}',
        value: scalarOnly(json['value']),
        reason: json['reason'] as String?,
      );
}

class TemplateExclusion {
  const TemplateExclusion({required this.id, required this.portability, this.reason});
  final String id, portability;
  final String? reason;

  factory TemplateExclusion.fromJson(Map<String, dynamic> json) => TemplateExclusion(
        id: '${json['id']}',
        portability: '${json['portability']}',
        reason: json['reason'] as String?,
      );
}

class TemplateCoverage {
  const TemplateCoverage({this.registered = 0, this.present = 0, this.absent = 0, this.unknown = 0, this.requiredInputs = 0});
  final int registered, present, absent, unknown, requiredInputs;

  factory TemplateCoverage.fromJson(Map<String, dynamic> json) => TemplateCoverage(
        registered: (json['registered'] as num?)?.toInt() ?? 0,
        present: (json['present'] as num?)?.toInt() ?? 0,
        absent: (json['absent'] as num?)?.toInt() ?? 0,
        unknown: (json['unknown'] as num?)?.toInt() ?? 0,
        requiredInputs: (json['required_inputs'] as num?)?.toInt() ?? 0,
      );
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
    final tpl = Map<String, dynamic>.from(json['template'] as Map? ?? const <String, dynamic>{});
    List<Map<String, dynamic>> rows(String key) => [
          for (final r in json[key] as List? ?? const <Object?>[])
            if (r is Map) Map<String, dynamic>.from(r),
        ];
    return TemplateInspection(
      templateId: '${tpl['id']}',
      key: '${tpl['key'] ?? ''}',
      name: '${tpl['name'] ?? ''}',
      description: '${tpl['description'] ?? ''}',
      entities: [for (final e in tpl['entities'] as List? ?? const <Object?>[]) '$e'],
      schemaVersion: (tpl['schema_version'] as num?)?.toInt() ?? 1,
      templateVersion: (tpl['template_version'] as num?)?.toInt() ?? 1,
      supportedSchemaVersions: [
        for (final v in json['supported_schema_versions'] as List? ?? const <Object?>[]) (v as num).toInt(),
      ],
      registryRevision: '${json['registry_revision'] ?? ''}',
      schemaRevision: (json['schema_revision'] as num?)?.toInt() ?? 0,
      status: TemplateInspectionStatus.fromWire(json['status'] as String?),
      profile: TemplateProfile.fromWire(json['profile'] as String?),
      compatibility: TemplateCompatibility.fromWire(json['compatibility'] as String?),
      outline: TemplateOutline.fromJson({
        'compatibility': json['compatibility'],
        'reason': json['compatibility_reason'],
        'groups': json['outline'],
      }),
      digest: json['digest'] as String?,
      fields: [for (final r in rows('fields')) TemplateFieldRecord.fromJson(r)],
      problems: [for (final r in rows('problems')) TemplateProblem.fromJson(r)],
      requiredInputs: [for (final r in rows('required_inputs')) TemplateRequiredInput.fromJson(r)],
      exclusions: [for (final r in rows('exclusions')) TemplateExclusion.fromJson(r)],
      coverage: TemplateCoverage.fromJson(
          Map<String, dynamic>.from(json['coverage'] as Map? ?? const <String, dynamic>{})),
    );
  }
}
