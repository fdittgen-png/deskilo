// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1120 — a stored floor plan somebody can start a space from, or share.
//
// The row is `workspace_templates` (0196/0199). Reading it is governed by
// ONE server predicate, `workspace_template_readable`: builtin and public
// for everyone signed in, private for the owning workspace's owners,
// shared for them plus the addresses the owner invited. The client never
// decides who may see a template; it shows what the server returned.
import '../../../core/data/system_columns.dart';

/// Who may see a template. Wire values by name.
enum TemplateVisibility {
  /// Ships with the product; belongs to nobody.
  builtin,

  /// The owning workspace's owners only.
  private,

  /// The owners, plus the e-mail addresses they invited.
  shared,

  /// Everyone signed in — the library.
  public,

  /// A value this build does not know (#1088): shown, never acted on.
  unknown;

  static TemplateVisibility fromDb(String? raw) =>
      TemplateVisibility.values.asNameMap()[raw] ?? TemplateVisibility.unknown;
}

class WorkspaceTemplate implements SystemStamped {
  const WorkspaceTemplate({
    required this.id,
    required this.key,
    required this.name,
    this.description = '',
    this.visibility = TemplateVisibility.private,
    this.ownerWorkspaceId,
    this.floorPlan = const [],
    this.entities = const ['floor_plan'],
    this.schemaVersion = 1,
    this.templateVersion = 1,
    this.tags = const [],
    this.regional = const RegionalSuggestion(),
    this.system = SystemColumns.none,
  });

  /// #992 — the server's stamp on this row.
  @override
  final SystemColumns system;

  final String id;
  final String key;
  final String name;
  final String description;
  final TemplateVisibility visibility;

  /// Null for a builtin. The owning workspace decides who may see it.
  final String? ownerWorkspaceId;

  /// `export_floor_plan` shape: levels → offices → desks → seats. Prices,
  /// storage paths and the site name are stripped server-side before a
  /// snapshot is stored (`strip_template_plan`).
  final List<Object?> floorPlan;

  /// #1276 — the deployable entities the snapshot carries (0229). Everything
  /// saved before it carries `floor_plan` alone and applies as it did.
  final List<String> entities;

  /// The snapshot's format; a server that does not know it refuses to apply.
  final int schemaVersion;

  /// Bumped each time the owners publish over the same key.
  final int templateVersion;

  final List<String> tags;

  /// #1656 — where the template was made, offered at creation only.
  final RegionalSuggestion regional;

  /// More than a floor plan: hours, prices, rules or features travel too.
  bool get carriesConfiguration => entities.any((e) => e != 'floor_plan');

  bool get isBuiltin => visibility == TemplateVisibility.builtin;

  /// Owned by [workspaceId]'s owners — the rows they may edit and share.
  bool ownedBy(String? workspaceId) =>
      ownerWorkspaceId != null && ownerWorkspaceId == workspaceId;

  /// "2 levels · 4 desks · 8 seats" — what a card says at a glance.
  ({int levels, int desks, int seats}) get counts {
    var desks = 0;
    var seats = 0;
    for (final level in floorPlan.whereType<Map<Object?, Object?>>()) {
      for (final office in (level['offices'] as List<Object?>? ?? const <Object?>[]).whereType<Map<Object?, Object?>>()) {
        for (final desk in (office['desks'] as List<Object?>? ?? const <Object?>[]).whereType<Map<Object?, Object?>>()) {
          desks++;
          seats += (desk['seats'] as List<Object?>? ?? const <Object?>[]).length;
        }
      }
    }
    return (levels: floorPlan.length, desks: desks, seats: seats);
  }

  factory WorkspaceTemplate.fromRow(Map<String, dynamic> row) =>
      WorkspaceTemplate(
        system: SystemColumns.fromRow(row),
        id: row['id'] as String,
        key: row['key'] as String? ?? '',
        name: row['name'] as String? ?? '',
        description: row['description'] as String? ?? '',
        visibility: TemplateVisibility.fromDb(row['visibility'] as String?),
        ownerWorkspaceId: row['owner_workspace_id'] as String?,
        floorPlan: (row['floor_plan'] as List?)?.cast<Object?>() ?? const [],
        entities: [
          for (final e in row['entities'] as List? ?? const ['floor_plan']) '$e'
        ],
        schemaVersion: (row['schema_version'] as num?)?.toInt() ?? 1,
        templateVersion: (row['template_version'] as num?)?.toInt() ?? 1,
        tags: [for (final t in row['tags'] as List? ?? const <Object?>[]) '$t'],
        regional: RegionalSuggestion.fromJson(row['regional']),
      );
}

/// A template key from a name: lower-case, digits and underscores, which
/// is what the column's check constraint accepts (`^[a-z][a-z0-9_]{0,39}$`).
String templateKeyFrom(String name) {
  final slug = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  final safe = slug.isEmpty || !RegExp(r'^[a-z]').hasMatch(slug) ? 't_$slug' : slug;
  return safe.length > 40 ? safe.substring(0, 40) : safe;
}

/// #1656 — a template's suggested region for a NEW space (0277): the
/// source workspace's country, currency, timezone and language. Never
/// applied to an existing space, and at creation only by choice.
class RegionalSuggestion {
  const RegionalSuggestion({this.countryCode, this.currencyCode, this.timezone, this.locale});

  final String? countryCode;
  final String? currencyCode;
  final String? timezone;
  final String? locale;

  bool get isEmpty => countryCode == null && currencyCode == null && timezone == null;

  /// Whether it differs from what the form holds now.
  bool differsFrom({required String countryCode, required String currencyCode, required String timezone}) =>
      !isEmpty &&
      ((this.countryCode != null && this.countryCode != countryCode.toUpperCase()) ||
          (this.currencyCode != null && this.currencyCode != currencyCode.trim().toUpperCase()) ||
          (this.timezone != null && this.timezone != timezone.trim()));

  factory RegionalSuggestion.fromJson(Object? json) {
    if (json is! Map) return const RegionalSuggestion();
    String? text(String key, RegExp shape) {
      final v = json[key];
      return v is String && shape.hasMatch(v) ? v : null;
    }

    return RegionalSuggestion(
      countryCode: text('country_code', RegExp(r'^[A-Z]{2}$')),
      currencyCode: text('currency_code', RegExp(r'^[A-Z]{3}$')),
      timezone: text('timezone', RegExp(r'^.{1,64}$')),
      locale: text('locale', RegExp(r'^[a-z]{2}$')),
    );
  }
}

/// #1656 — what applying a template did with its floor-plan prices (0278).
enum TemplatePriceOutcome {
  /// The template carries no prices.
  none,

  /// Same currency: the prices were applied.
  applied,

  /// Another currency: every price here was left as it was.
  currencyMismatch;

  static TemplatePriceOutcome fromResult(Object? result) =>
      switch (result is Map ? result['prices'] : null) {
        'applied' => TemplatePriceOutcome.applied,
        'currency_mismatch' => TemplatePriceOutcome.currencyMismatch,
        _ => TemplatePriceOutcome.none,
      };
}
