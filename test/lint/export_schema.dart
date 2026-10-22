// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2859 — the current columns of every public table, replayed from the
// migrations: `create table`, `add column`, `drop column`,
// `rename column`, `rename to` and `drop table`, in file order. The
// export coverage lint compares them with what the workbook declares.
import 'lint_sources.dart';

/// The six technical columns `ensure_system_columns` adds to every table
/// (#992): never business data, never asked about.
const systemColumns = {
  'created_datetime',
  'modified_datetime',
  'company_id',
  'site_id',
  'created_by_user',
  'modified_by_user',
};

/// One table as the migrations leave it.
class SchemaTable {
  SchemaTable(this.name);
  String name;
  final Set<String> columns = {};

  /// The tables this one's columns reference (`references public.x`).
  final Set<String> references = {};
}

final _create = RegExp(
  r'create table (?:if not exists )?public\.(\w+)\s*\((.*?)\n\s*\);',
  dotAll: true,
  caseSensitive: false,
);
final _alter = RegExp(
  r'alter table (?:if exists )?(?:only )?public\.(\w+)\s+(.*?);',
  dotAll: true,
  caseSensitive: false,
);
final _drop = RegExp(
  r'drop table (?:if exists )?public\.(\w+)',
  caseSensitive: false,
);
final _reference = RegExp(r'references public\.(\w+)', caseSensitive: false);
final _notAColumn = RegExp(
  r'^(constraint|primary|unique|check|foreign|exclude|like)\b',
  caseSensitive: false,
);

/// Every public table the migrations leave behind, by name.
Map<String, SchemaTable> replaySchema() {
  final tables = <String, SchemaTable>{};
  for (final f in sqlFiles('supabase/migrations')) {
    final sql = _withoutComments(f.readAsStringSync());
    final events = <(int, void Function())>[
      for (final m in _create.allMatches(sql))
        (m.start, () => _created(tables, m.group(1)!, m.group(2)!)),
      for (final m in _alter.allMatches(sql))
        (m.start, () => _altered(tables, m.group(1)!, m.group(2)!)),
      for (final m in _drop.allMatches(sql))
        (m.start, () => tables.remove(m.group(1))),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    for (final (_, apply) in events) {
      apply();
    }
  }
  return tables;
}

String _withoutComments(String sql) => sql.replaceAll(RegExp(r'--[^\n]*'), '');

void _created(Map<String, SchemaTable> tables, String name, String body) {
  final table = tables[name] = SchemaTable(name);
  for (final part in _topLevelParts(body)) {
    final line = part.trim();
    if (line.isEmpty || _notAColumn.hasMatch(line)) {
      table.references.addAll(
        _reference.allMatches(line).map((m) => m.group(1)!),
      );
      continue;
    }
    final column = RegExp(r'^"?(\w+)"?').firstMatch(line)?.group(1);
    if (column != null) table.columns.add(column.toLowerCase());
    table.references.addAll(
      _reference.allMatches(line).map((m) => m.group(1)!),
    );
  }
}

void _altered(Map<String, SchemaTable> tables, String name, String body) {
  final table = tables[name];
  if (table == null) return;
  final renamed = RegExp(
    r'^rename to (\w+)',
    caseSensitive: false,
  ).firstMatch(body.trim());
  if (renamed != null) {
    tables.remove(name);
    tables[renamed.group(1)!] = table..name = renamed.group(1)!;
    return;
  }
  for (final part in _topLevelParts(body)) {
    final action = part.trim();
    final add = RegExp(
      r'^add column (?:if not exists )?"?(\w+)"?',
      caseSensitive: false,
    ).firstMatch(action);
    if (add != null) {
      table.columns.add(add.group(1)!.toLowerCase());
      table.references.addAll(
        _reference.allMatches(action).map((m) => m.group(1)!),
      );
    }
    final drop = RegExp(
      r'^drop column (?:if exists )?"?(\w+)"?',
      caseSensitive: false,
    ).firstMatch(action);
    if (drop != null) table.columns.remove(drop.group(1)!.toLowerCase());
    final rename = RegExp(
      r'^rename column "?(\w+)"? to "?(\w+)"?',
      caseSensitive: false,
    ).firstMatch(action);
    if (rename != null &&
        table.columns.remove(rename.group(1)!.toLowerCase())) {
      table.columns.add(rename.group(2)!.toLowerCase());
    }
  }
}

/// [body] split at the commas that are not inside parentheses.
List<String> _topLevelParts(String body) {
  final parts = <String>[];
  var depth = 0;
  var start = 0;
  for (var i = 0; i < body.length; i++) {
    final c = body[i];
    if (c == '(') depth++;
    if (c == ')') depth--;
    if (c == ',' && depth == 0) {
      parts.add(body.substring(start, i));
      start = i + 1;
    }
  }
  parts.add(body.substring(start));
  return parts;
}
