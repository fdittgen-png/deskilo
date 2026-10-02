// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The pure half of tool/contract_predict.dart: which contract entries a
// migration determines on its own, the query that reads them, and the
// splice into assets/instance/contract.txt.
import 'dart:convert';

/// What a migration determines by itself, and what it cannot.
class MigrationScope {
  MigrationScope(this.routines, this.tables, this.unsafe);

  /// Routines defined WHOLE here (`create function public.x(...)`) or
  /// dropped here: their contract lines depend only on this file.
  final Set<String> routines;

  /// Tables created here: their constraints and triggers likewise.
  final Set<String> tables;

  /// Why a part of the change cannot be predicted (an anchored patch: the
  /// reference project's body has drifted from the replay's).
  final List<String> unsafe;
}

final _create = RegExp(
  r'create\s+(?:or\s+replace\s+)?function\s+public\.(\w+)\s*\(',
  caseSensitive: false,
);
final _drop = RegExp(
  r'drop\s+function\s+(?:if\s+exists\s+)?public\.(\w+)',
  caseSensitive: false,
);
final _createTable = RegExp(
  r'create\s+table\s+(?:if\s+not\s+exists\s+)?public\.(\w+)',
  caseSensitive: false,
);
final _patched = [
  RegExp(r"proname\s*=\s*'(\w+)'", caseSensitive: false),
  RegExp(r"'public\.(\w+)'\s*::\s*regproc", caseSensitive: false),
  RegExp(r"anchor_replace\(\s*'(?:public\.)?(\w+)'", caseSensitive: false),
];
final _alterConstraint = RegExp(
  r'alter\s+table\s+(?:only\s+)?(?:if\s+exists\s+)?public\.(\w+)[^;]*'
  r'(add\s+constraint|drop\s+constraint|references|check\s*\(|unique|primary\s+key)',
  caseSensitive: false,
);
final _triggerOn = RegExp(
  r'create\s+(?:or\s+replace\s+)?(?:constraint\s+)?trigger\s+\w+[^;]*?\bon\s+public\.(\w+)',
  caseSensitive: false,
);

/// Strips `--` comments so a comment that NAMES a pattern is not one.
String _code(String sql) =>
    sql.split('\n').map((l) => l.replaceFirst(RegExp(r'--.*$'), '')).join('\n');

MigrationScope scan(String migration) {
  final sql = _code(migration);
  final routines = {
    for (final m in _create.allMatches(sql)) m.group(1)!,
    for (final m in _drop.allMatches(sql)) m.group(1)!,
  };
  final tables = {for (final m in _createTable.allMatches(sql)) m.group(1)!};
  final unsafe = <String>[];
  for (final re in _patched) {
    for (final m in re.allMatches(sql)) {
      final name = m.group(1)!;
      routines.remove(name);
      unsafe.add('routine $name is patched by anchor');
    }
  }
  // A patch loop names its routines in data (`p.proname = v_step.fn`),
  // not in a pattern above: any pg_get_functiondef left unexplained is an
  // anchored patch whose digest only the CI replay knows.
  if (unsafe.isEmpty &&
      RegExp('pg_get_functiondef', caseSensitive: false).hasMatch(sql)) {
    unsafe.add('a routine is patched by anchor (names not parsed)');
  }
  for (final m in _alterConstraint.allMatches(sql)) {
    if (!tables.contains(m.group(1))) {
      unsafe.add('constraints of existing table ${m.group(1)} change');
    }
  }
  for (final m in _triggerOn.allMatches(sql)) {
    if (!tables.contains(m.group(1))) {
      unsafe.add('a trigger on existing table ${m.group(1)} changes');
    }
  }
  return MigrationScope(routines, tables, unsafe.toSet().toList()..sort());
}

/// The contract query of scripts/contract_check.sh, narrowed to [scope]
/// and returned as ONE json array, in the file's order.
String predictionSql(String contractCheckScript, MigrationScope scope) {
  final start = contractCheckScript.indexOf('-At -c "');
  final end = contractCheckScript.indexOf('order by 1"', start);
  if (start < 0 || end < 0) {
    throw const FormatException(
      'contract query not found in contract_check.sh',
    );
  }
  final query = contractCheckScript.substring(start + 8, end);
  final patterns = [
    for (final r in scope.routines) "'routine public.$r(%'",
    for (final t in scope.tables) ...["'constraint $t.%'", "'trigger $t.%'"],
  ];
  if (patterns.isEmpty) return '';
  return 'select json_agg(line order by line collate "C") as lines from ($query) q\n'
      ' where line like any (array[${patterns.join(', ')}]);';
}

bool _isEntryStart(String l) =>
    l.startsWith('routine ') ||
    l.startsWith('constraint ') ||
    l.startsWith('trigger ');

/// [contract] with every entry [scope] owns replaced by [entries], sorted
/// the way the replay sorts (bytewise, `collate "C"`), header kept.
String splice(String contract, MigrationScope scope, List<String> entries) {
  final lines = contract.split('\n');
  if (lines.isNotEmpty && lines.last.isEmpty) lines.removeLast();
  final header = <String>[];
  final body = <String>[];
  for (final l in lines) {
    if (body.isEmpty && !_isEntryStart(l)) {
      header.add(l);
    } else if (_isEntryStart(l)) {
      body.add(l);
    } else {
      body[body.length - 1] = '${body.last}\n$l';
    }
  }
  bool owned(String e) =>
      scope.routines.any((r) => e.startsWith('routine public.$r(')) ||
      scope.tables.any(
        (t) => e.startsWith('constraint $t.') || e.startsWith('trigger $t.'),
      );
  final kept = [
    for (final e in body)
      if (!owned(e)) e,
    ...entries,
  ]..sort((a, b) => _bytes(a).compareTo(_bytes(b)));
  return '${[...header, ...kept].join('\n')}\n';
}

class _Bytes implements Comparable<_Bytes> {
  _Bytes(this.b);
  final List<int> b;
  @override
  int compareTo(_Bytes o) {
    for (var i = 0; i < b.length && i < o.b.length; i++) {
      if (b[i] != o.b[i]) return b[i] - o.b[i];
    }
    return b.length - o.b.length;
  }
}

_Bytes _bytes(String s) => _Bytes(utf8.encode(s));

/// The entries from a pasted query result: a json array of lines, or the
/// MCP row shape `[{"lines": [...]}]`.
List<String> parseEntries(String pasted) {
  final decoded = jsonDecode(pasted);
  final list = decoded is List && decoded.isNotEmpty && decoded.first is Map
      ? (decoded.first as Map)['lines']
      : decoded;
  return [for (final e in (list as List?) ?? const []) e as String];
}
