// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1911 — renders the data dictionary from the catalogue extraction.
//
// Input is `docs/database/dictionary.json`, which `scripts/db_dictionary.sql`
// writes from the PostgreSQL catalogues of the migration replay. Output is
// derived from that ONE document, so the JSON, the CSVs and the HTML cannot
// disagree: `test/tool/db_dictionary_test.dart` fails when a committed
// rendering is not what this writes.
//
// The HTML is a single self-contained file: no CDN, no external font, a
// restrictive Content-Security-Policy, every catalogue string escaped, and
// the only script is a static search filter.
//
// Pure Dart: no Flutter.
library;

import 'dart:convert';

const _escape = HtmlEscape(HtmlEscapeMode.attribute);

/// One relationship between two tables.
class Relationship {
  const Relationship({
    required this.kind,
    required this.fromSchema,
    required this.fromTable,
    required this.fromColumns,
    required this.toSchema,
    required this.toTable,
    required this.toColumns,
    required this.name,
    this.onDelete = '',
    this.onUpdate = '',
    this.validated = true,
  });

  /// `defined` (a foreign key constraint) or `inferred` (a naming match
  /// with NO constraint: a logical link the database does not enforce).
  final String kind;
  final String fromSchema;
  final String fromTable;
  final List<String> fromColumns;
  final String toSchema;
  final String toTable;
  final List<String> toColumns;
  final String name;
  final String onDelete;
  final String onUpdate;
  final bool validated;

  String get from => '$fromSchema.$fromTable';
  String get to => '$toSchema.$toTable';
}

List<Map<String, dynamic>> _list(Object? v) =>
    (v as List? ?? const []).cast<Map<String, dynamic>>();

List<String> _strings(Object? v) => (v as List? ?? const []).cast<String>();

String _qualified(Map<String, dynamic> o) => '${o['schema']}.${o['name']}';

/// The objects of [dictionary], ordered by schema then name.
List<Map<String, dynamic>> dictionaryObjects(Map<String, dynamic> dictionary) =>
    _list(dictionary['objects'])
      ..sort((a, b) => _qualified(a).compareTo(_qualified(b)));

const _tableKinds = {'table', 'partitioned table'};

/// What is wrong with [dictionary]: the declared counts against the
/// objects, every defined relationship against its endpoints, every key
/// against its columns. Empty = complete and self-consistent. A field or
/// relationship dropped from the objects is reported here, not rendered
/// silently.
List<String> verifyDictionary(Map<String, dynamic> dictionary) {
  final problems = <String>[];
  final objects = _list(dictionary['objects']);
  final types = _list(dictionary['types']);
  final meta = (dictionary['meta'] as Map?)?.cast<String, dynamic>() ?? {};
  final declared = (meta['counts'] as Map?)?.cast<String, dynamic>() ?? {};
  int kinds(Set<String> k) =>
      objects.where((o) => k.contains(o['kind'])).length;
  final actual = <String, int>{
    'tables': kinds(_tableKinds),
    'partitions': kinds({'partition'}),
    'views': kinds({'view', 'materialized view'}),
    'columns': objects.fold(0, (n, o) => n + _list(o['columns']).length),
    'foreignKeys': objects.fold(
      0,
      (n, o) =>
          n +
          _list(o['constraints'])
              .where((c) => c['type'] == 'foreign key')
              .length,
    ),
    'enums': types.where((t) => t['kind'] == 'enum').length,
    'domains': types.where((t) => t['kind'] == 'domain').length,
  };
  for (final e in actual.entries) {
    if (declared[e.key] != e.value) {
      problems.add(
        'count ${e.key}: the extraction says ${declared[e.key]}, '
        'the objects hold ${e.value}',
      );
    }
  }
  final byName = {for (final o in objects) _qualified(o): o};
  for (final o in objects) {
    final q = _qualified(o);
    final cols = _list(o['columns']);
    final names = {for (final c in cols) c['name'] as String};
    for (var i = 0; i < cols.length; i++) {
      if (cols[i]['position'] != i + 1) {
        problems.add('$q: column ${cols[i]['name']} breaks the order at $i');
      }
    }
    for (final k in _list(o['constraints'])) {
      for (final c in _strings(k['columns'])) {
        if (!names.contains(c)) {
          problems.add('$q.${k['name']}: unknown column $c');
        }
      }
      if (k['type'] != 'foreign key') continue;
      final ref = (k['references'] as Map).cast<String, dynamic>();
      final target = '${ref['schema']}.${ref['table']}';
      final to = byName[target];
      if (to == null) {
        // A managed table (auth.users) is a reference, not an object.
        if (ref['schema'] == 'public') {
          problems.add('$q.${k['name']}: unknown target $target');
        }
        continue;
      }
      final toNames = {for (final c in _list(to['columns'])) c['name']};
      for (final c in _strings(ref['columns'])) {
        if (!toNames.contains(c)) {
          problems.add('$q.${k['name']}: $target has no column $c');
        }
      }
      if (_strings(k['columns']).length != _strings(ref['columns']).length) {
        problems.add('$q.${k['name']}: key and reference differ in width');
      }
    }
  }
  return problems;
}

/// Every foreign key as a [Relationship], then the inferred ones.
///
/// Inferred = a column named `<thing>_id` with NO foreign key whose
/// `<thing>` (or its plural) is a table with a single-column primary key of
/// the same type. `company_id` and `site_id` are tenancy stamps present on
/// every table (system columns) and are never inferred.
List<Relationship> relationshipsOf(Map<String, dynamic> dictionary) {
  final objects = dictionaryObjects(dictionary);
  final out = <Relationship>[];
  final fkColumns = <String>{};
  for (final o in objects) {
    for (final k in _list(o['constraints'])) {
      if (k['type'] != 'foreign key') continue;
      final ref = (k['references'] as Map).cast<String, dynamic>();
      final cols = _strings(k['columns']);
      for (final c in cols) {
        fkColumns.add('${_qualified(o)}.$c');
      }
      final setNull = _strings(k['onDeleteColumns']);
      out.add(
        Relationship(
          kind: 'defined',
          fromSchema: o['schema'] as String,
          fromTable: o['name'] as String,
          fromColumns: cols,
          toSchema: ref['schema'] as String,
          toTable: ref['table'] as String,
          toColumns: _strings(ref['columns']),
          name: k['name'] as String,
          onDelete: setNull.isEmpty
              ? '${k['onDelete']}'
              : '${k['onDelete']} (${setNull.join(', ')})',
          onUpdate: '${k['onUpdate']}',
          validated: k['validated'] != false,
        ),
      );
    }
  }
  final tables = {
    for (final o in objects)
      if (_tableKinds.contains(o['kind'])) o['name'] as String: o,
  };
  String? singlePkType(Map<String, dynamic> t) {
    for (final k in _list(t['constraints'])) {
      if (k['type'] != 'primary key') continue;
      final cols = _strings(k['columns']);
      if (cols.length != 1) return null;
      for (final c in _list(t['columns'])) {
        if (c['name'] == cols.single) return c['type'] as String;
      }
    }
    return null;
  }

  String? singlePkName(Map<String, dynamic> t) {
    for (final k in _list(t['constraints'])) {
      if (k['type'] == 'primary key' && _strings(k['columns']).length == 1) {
        return _strings(k['columns']).single;
      }
    }
    return null;
  }

  const stamps = {'company_id', 'site_id'};
  for (final o in objects) {
    if (!_tableKinds.contains(o['kind'])) continue;
    for (final c in _list(o['columns'])) {
      final name = c['name'] as String;
      if (!name.endsWith('_id') || stamps.contains(name)) continue;
      if (fkColumns.contains('${_qualified(o)}.$name')) continue;
      final stem = name.substring(0, name.length - 3);
      final target = tables[stem] ?? tables['${stem}s'] ?? tables['${stem}es'];
      if (target == null || target['name'] == o['name']) continue;
      if (singlePkType(target) != c['type']) continue;
      out.add(
        Relationship(
          kind: 'inferred',
          fromSchema: o['schema'] as String,
          fromTable: o['name'] as String,
          fromColumns: [name],
          toSchema: target['schema'] as String,
          toTable: target['name'] as String,
          toColumns: [singlePkName(target)!],
          name: '',
        ),
      );
    }
  }
  return out;
}

String _csvCell(Object? v) {
  final s = v == null ? '' : '$v';
  return s.contains(RegExp('[",\n\r]')) ? '"${s.replaceAll('"', '""')}"' : s;
}

String _csv(List<List<Object?>> rows) =>
    '${rows.map((r) => r.map(_csvCell).join(',')).join('\n')}\n';

/// One row per column, ordered by object then position.
String columnsCsv(Map<String, dynamic> dictionary) {
  final rows = <List<Object?>>[
    [
      'schema',
      'object',
      'kind',
      'position',
      'column',
      'type',
      'not_null',
      'default',
      'identity',
      'generated',
      'primary_key',
      'references',
      'comment',
    ],
  ];
  for (final o in dictionaryObjects(dictionary)) {
    final pk = <String>{};
    final fks = <String, List<String>>{};
    for (final k in _list(o['constraints'])) {
      if (k['type'] == 'primary key') pk.addAll(_strings(k['columns']));
      if (k['type'] == 'foreign key') {
        final ref = (k['references'] as Map).cast<String, dynamic>();
        final cols = _strings(k['columns']);
        final refCols = _strings(ref['columns']);
        for (var i = 0; i < cols.length; i++) {
          (fks[cols[i]] ??= []).add(
            '${ref['schema']}.${ref['table']}.${i < refCols.length ? refCols[i] : ''}',
          );
        }
      }
    }
    for (final c in _list(o['columns'])) {
      rows.add([
        o['schema'],
        o['name'],
        o['kind'],
        c['position'],
        c['name'],
        c['type'],
        c['notNull'] == true,
        c['default'],
        c['identity'],
        c['generated'],
        pk.contains(c['name']),
        (fks[c['name']] ?? const []).join('; '),
        c['comment'],
      ]);
    }
  }
  return _csv(rows);
}

/// One row per relationship, defined first, in table order.
String relationshipsCsv(Map<String, dynamic> dictionary) {
  final rows = <List<Object?>>[
    [
      'kind',
      'from',
      'from_columns',
      'to',
      'to_columns',
      'constraint',
      'on_delete',
      'on_update',
      'validated',
    ],
  ];
  final rels = relationshipsOf(dictionary)
    ..sort((a, b) {
      final k = a.kind.compareTo(b.kind);
      if (k != 0) return k;
      final f = a.from.compareTo(b.from);
      return f != 0 ? f : a.fromColumns.join().compareTo(b.fromColumns.join());
    });
  for (final r in rels) {
    rows.add([
      r.kind,
      r.from,
      r.fromColumns.join(' '),
      r.to,
      r.toColumns.join(' '),
      r.name,
      r.onDelete,
      r.onUpdate,
      r.kind == 'defined' ? r.validated : '',
    ]);
  }
  return _csv(rows);
}

String _e(Object? v) => _escape.convert('${v ?? ''}');

String _san(String s) => s.replaceAll(RegExp('[^A-Za-z0-9_]'), '_');

String _tableId(String schema, String name) =>
    't-${_san(schema)}__${_san(name)}';

String _colId(String schema, String name, String col) =>
    'c-${_san(schema)}__${_san(name)}__${_san(col)}';

const _css = '''
body{font:15px/1.5 system-ui,sans-serif;margin:0;color:#1b1f24;background:#fff}
header,main{max-width:1100px;margin:0 auto;padding:0 16px}
h1{margin:24px 0 8px}h2{margin:32px 0 4px;font-size:20px}h3{margin:16px 0 4px;font-size:15px}
table{border-collapse:collapse;width:100%;margin:4px 0 8px;font-size:13px}
th,td{border:1px solid #d0d7de;padding:3px 6px;text-align:left;vertical-align:top}
th{background:#f6f8fa}code{font:12px ui-monospace,monospace}
nav ul{columns:3;list-style:none;padding:0;font-size:13px}
.kind{color:#57606a;font-weight:normal;font-size:13px}.muted{color:#57606a}
.inferred{font-style:italic}input{width:100%;padding:8px;font-size:15px;margin:8px 0}
section.obj{border-top:2px solid #d0d7de}svg{max-width:100%;height:auto;margin:4px 0}
@media (prefers-color-scheme:dark){body{background:#0d1117;color:#e6edf3}
th{background:#161b22}th,td{border-color:#30363d}section.obj{border-color:#30363d}
a{color:#58a6ff}.kind,.muted{color:#8b949e}}
''';

const _script = '''
document.getElementById('q').addEventListener('input',function(e){
var q=e.target.value.toLowerCase().trim();
document.querySelectorAll('[data-s]').forEach(function(n){
n.hidden=q!==''&&n.getAttribute('data-s').indexOf(q)<0;});});
''';

String _link(String schema, String table, Set<String> known) =>
    known.contains('$schema.$table')
    ? '<a href="#${_e(_tableId(schema, table))}">${_e(schema)}.${_e(table)}</a>'
    : '${_e(schema)}.${_e(table)} <span class="muted">(managed)</span>';

String _neighbourhood(
  String qualified,
  List<Relationship> out,
  List<Relationship> inc,
  Set<String> known,
) {
  const cap = 8;
  final right = {
    for (final r in out)
      if (r.to != qualified) r.to,
  }.toList()..sort();
  final left = {
    for (final r in inc)
      if (r.from != qualified) r.from,
  }.toList()..sort();
  if (right.isEmpty && left.isEmpty) return '';
  final rows = [left.length, right.length].reduce((a, b) => a > b ? a : b);
  final shown = rows > cap + 1 ? cap + 1 : rows;
  final height = 40 + shown * 28;
  String node(String q, double x, double y, {bool link = true}) {
    final parts = q.split('.');
    final label =
        '<text x="${x + 6}" y="${y + 17}" font-size="12" '
        'fill="currentColor">${_e(q)}</text>';
    final rect =
        '<rect x="$x" y="$y" width="230" height="24" rx="4" '
        'fill="none" stroke="currentColor" opacity="0.6"/>';
    return link && known.contains(q)
        ? '<a href="#${_e(_tableId(parts.first, parts.sublist(1).join('.')))}">$rect$label</a>'
        : '$rect$label';
  }

  final b = StringBuffer(
    '<svg role="img" width="720" height="$height" viewBox="0 0 720 $height" '
    'aria-label="${_e('Relations of $qualified')}">',
  );
  final cy = height / 2 - 12;
  b.write(node(qualified, 245, cy, link: false));
  void side(List<String> names, double x, bool isLeft) {
    final n = names.length > cap ? cap : names.length;
    for (var i = 0; i < n; i++) {
      final y = 20.0 + i * 28;
      b.write(node(names[i], x, y));
      final x1 = isLeft ? x + 230 : x;
      final x2 = isLeft ? 245.0 : 475.0;
      b.write(
        '<line x1="$x1" y1="${y + 12}" x2="$x2" y2="${cy + 12}" '
        'stroke="currentColor" opacity="0.4"/>',
      );
    }
    if (names.length > cap) {
      b.write(
        '<text x="${x + 6}" y="${20.0 + cap * 28 + 17}" font-size="12" '
        'fill="currentColor">+${names.length - cap} more</text>',
      );
    }
  }

  side(left, 5, true);
  side(right, 485, false);
  b.write('</svg>');
  return '<p class="muted">Left: tables that reference this one. '
      'Right: tables this one references.</p>$b';
}

String _object(
  Map<String, dynamic> o,
  List<Relationship> out,
  List<Relationship> inc,
  Set<String> known,
) {
  final schema = o['schema'] as String;
  final name = o['name'] as String;
  final q = '$schema.$name';
  final b = StringBuffer();
  final search = StringBuffer('$q ${o['kind']} ${o['comment'] ?? ''}');
  for (final c in _list(o['columns'])) {
    search.write(' ${c['name']} ${c['type']}');
  }
  b.writeln(
    '<section class="obj" id="${_e(_tableId(schema, name))}" '
    'data-s="${_e(search.toString().toLowerCase())}">',
  );
  b.writeln('<h2>${_e(q)} <span class="kind">${_e(o['kind'])}</span></h2>');
  if (o['comment'] != null) b.writeln('<p>${_e(o['comment'])}</p>');
  if (o['partitionKey'] != null) {
    b.writeln('<p>Partitioned by <code>${_e(o['partitionKey'])}</code></p>');
  }
  if (o['partitionOf'] != null) {
    b.writeln(
      '<p>Partition of ${_link(schema, '${o['partitionOf']}', known)}: '
      '<code>${_e(o['partitionBound'])}</code></p>',
    );
  }
  b.writeln(
    '<table><thead><tr><th>#</th><th>Column</th><th>Type</th><th>Null</th>'
    '<th>Default / generated</th><th>Comment</th></tr></thead><tbody>',
  );
  for (final c in _list(o['columns'])) {
    final extra = [
      if (c['identity'] != null)
        'identity ${c['identity'] == 'a' ? 'always' : 'by default'}',
      if (c['generated'] != null)
        'generated stored: ${c['default']}'
      else if (c['default'] != null)
        '${c['default']}',
    ].join(' · ');
    b.writeln(
      '<tr id="${_e(_colId(schema, name, '${c['name']}'))}">'
      '<td>${_e(c['position'])}</td><td><code>${_e(c['name'])}</code></td>'
      '<td>${_e(c['type'])}</td><td>${c['notNull'] == true ? 'NOT NULL' : 'null'}</td>'
      '<td><code>${_e(extra)}</code></td><td>${_e(c['comment'])}</td></tr>',
    );
  }
  b.writeln('</tbody></table>');
  final cons = _list(o['constraints']);
  if (cons.isNotEmpty) {
    b.writeln('<h3>Constraints</h3><table><tbody>');
    for (final k in cons) {
      b.writeln(
        '<tr><td><code>${_e(k['name'])}</code></td><td>${_e(k['type'])}</td>'
        '<td><code>${_e(k['definition'])}</code>'
        '${k['validated'] == false ? ' <b>NOT VALID</b>' : ''}</td></tr>',
      );
    }
    b.writeln('</tbody></table>');
  } else if (o['kind'] != 'view' && o['kind'] != 'materialized view') {
    b.writeln('<p class="muted">No constraints (no primary key).</p>');
  }
  final idx = _list(o['indexes']);
  if (idx.isNotEmpty) {
    b.writeln('<h3>Indexes</h3><table><tbody>');
    for (final i in idx) {
      b.writeln(
        '<tr><td><code>${_e(i['name'])}</code></td>'
        '<td><code>${_e(i['definition'])}</code>'
        '${i['valid'] == false ? ' <b>INVALID</b>' : ''}</td></tr>',
      );
    }
    b.writeln('</tbody></table>');
  }
  if (out.isNotEmpty || inc.isNotEmpty) {
    b.writeln(
      '<h3>Relationships</h3><table><thead><tr><th>Kind</th>'
      '<th>From</th><th>To</th><th>On delete</th></tr></thead><tbody>',
    );
    String side(Relationship r, bool from) {
      final cols = (from ? r.fromColumns : r.toColumns).join(', ');
      final t = from
          ? _link(r.fromSchema, r.fromTable, known)
          : _link(r.toSchema, r.toTable, known);
      return '$t (${_e(cols)})';
    }

    for (final r in [...out, ...inc]) {
      b.writeln(
        '<tr class="${r.kind}"><td>${r.kind == 'defined' ? 'foreign key' : 'inferred, not enforced'}</td>'
        '<td>${side(r, true)}</td><td>${side(r, false)}</td>'
        '<td>${_e(r.onDelete)}</td></tr>',
      );
    }
    b.writeln('</tbody></table>');
    b.writeln(_neighbourhood(q, out, inc, known));
  }
  b.writeln('</section>');
  return b.toString();
}

/// The self-contained document.
String dictionaryHtml(Map<String, dynamic> dictionary) {
  final meta = (dictionary['meta'] as Map).cast<String, dynamic>();
  final counts = (meta['counts'] as Map).cast<String, dynamic>();
  final objects = dictionaryObjects(dictionary);
  final known = {for (final o in objects) _qualified(o)};
  final rels = relationshipsOf(dictionary);
  final b = StringBuffer()
    ..writeln('<!doctype html><html lang="en"><head><meta charset="utf-8">')
    ..writeln(
      '<meta http-equiv="Content-Security-Policy" content="default-src '
      "'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; "
      "img-src data:\">",
    )
    ..writeln(
      '<meta name="viewport" content="width=device-width,initial-scale=1">',
    )
    ..writeln(
      '<title>DesKilo data dictionary</title><style>$_css</style></head><body>',
    )
    ..writeln('<header><h1>DesKilo data dictionary</h1>')
    ..writeln(
      '<p>Generated from the PostgreSQL catalogues of the migration replay, '
      'never written by hand. It describes the CURRENT data model; '
      'proposed schemas are not in it.</p>',
    )
    ..writeln('<table><tbody>');
  void row(String k, Object? v) =>
      b.writeln('<tr><th>${_e(k)}</th><td>${_e(v)}</td></tr>');
  row('Source', meta['source']);
  row('Application schema', meta['applicationSchema']);
  row('Schema marker (last migration)', meta['schemaMarker']);
  row('PostgreSQL major version', meta['postgresMajor']);
  row('Counts', counts.entries.map((e) => '${e.value} ${e.key}').join(', '));
  row('Catalogue checksum (sha-256)', meta['checksum']);
  row('Not in this document', (meta['excluded'] as List).join('; '));
  b
    ..writeln('</tbody></table>')
    ..writeln(
      '<input id="q" type="search" placeholder="Search tables and columns" '
      'aria-label="Search tables and columns"></header><main>',
    )
    ..writeln('<nav aria-label="Tables"><ul>');
  for (final o in objects) {
    final q = _qualified(o);
    b.writeln(
      '<li data-s="${_e(q.toLowerCase())}"><a href="#${_e(_tableId(o['schema'] as String, o['name'] as String))}">'
      '${_e(q)}</a></li>',
    );
  }
  b.writeln('</ul></nav>');
  final types = _list(dictionary['types']);
  if (types.isNotEmpty) {
    b.writeln('<h2>Enumerated and domain types</h2><table><tbody>');
    for (final t in types) {
      final detail = t['kind'] == 'enum'
          ? _strings(t['labels']).join(', ')
          : '${t['baseType']}${t['notNull'] == true ? ' NOT NULL' : ''} '
                '${_strings(t['checks']).join(' ')}';
      b.writeln(
        '<tr><td><code>${_e(t['schema'])}.${_e(t['name'])}</code></td>'
        '<td>${_e(t['kind'])}</td><td>${_e(detail)}</td></tr>',
      );
    }
    b.writeln('</tbody></table>');
  }
  for (final o in objects) {
    final q = _qualified(o);
    b.write(
      _object(
        o,
        [
          for (final r in rels)
            if (r.from == q) r,
        ],
        [
          for (final r in rels)
            if (r.to == q && r.from != q) r,
        ],
        known,
      ),
    );
  }
  b.writeln('</main><script>$_script</script></body></html>');
  return b.toString();
}

/// Every rendering, by repository path.
Map<String, String> renderDictionary(Map<String, dynamic> dictionary) => {
  'docs/database/columns.csv': columnsCsv(dictionary),
  'docs/database/relationships.csv': relationshipsCsv(dictionary),
  'docs/database/dictionary.html': dictionaryHtml(dictionary),
};
