// SPDX-License-Identifier: 0BSD
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
