// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3731 (K4) -- what a migration's `-- apps:` line promises, read from its
// text. A conservative scanner: it flags what it can prove from the SQL and
// leaves behaviour to the tests. The lint (test/lint/consumer_contract_test.dart)
// runs it over supabase/migrations.

/// One function a migration creates: its name and its parameters in order.
class FunctionDef {
  FunctionDef(this.name, this.params);
  final String name;

  /// parameter name -> has a default
  final Map<String, bool> params;
}

final appsLinePattern = RegExp(
  r'^-- apps: (additive|needs app at least \d+|breaks apps below \d+)\s*$',
);

final _dropsOrRenames = RegExp(
  r'\b(drop\s+(table|column|function|view|materialized\s+view|type)|rename\s+(column|to))\b',
  caseSensitive: false,
);
final _dropFunction = RegExp(
  r'drop\s+function\s+(?:if\s+exists\s+)?(?:public\.)?"?(\w+)"?',
  caseSensitive: false,
);
final _createFunction = RegExp(
  r'create\s+(?:or\s+replace\s+)?function\s+(?:public\.)?"?(\w+)"?\s*\(',
  caseSensitive: false,
);

/// The SQL without line comments (a `--` inside a string is rare enough).
String stripSqlComments(String sql) => sql
    .split('\n')
    .map((l) => l.trimLeft().startsWith('--') ? '' : l)
    .join('\n');

/// Every `create [or replace] function` of [sql] with its parameters.
List<FunctionDef> functionDefs(String sql) {
  final text = stripSqlComments(sql);
  final out = <FunctionDef>[];
  for (final m in _createFunction.allMatches(text)) {
    var depth = 1;
    var i = m.end;
    final start = i;
    while (i < text.length && depth > 0) {
      final c = text[i];
      if (c == '(') depth++;
      if (c == ')') depth--;
      i++;
    }
    if (depth != 0) continue;
    final args = text.substring(start, i - 1);
    final params = <String, bool>{};
    var d = 0;
    var from = 0;
    final parts = <String>[];
    for (var k = 0; k < args.length; k++) {
      final c = args[k];
      if (c == '(') d++;
      if (c == ')') d--;
      if (c == ',' && d == 0) {
        parts.add(args.substring(from, k));
        from = k + 1;
      }
    }
    parts.add(args.substring(from));
    for (final p in parts) {
      final t = p.trim();
      if (t.isEmpty) continue;
      final words = t.split(RegExp(r'\s+'));
      var n = 0;
      while (n < words.length - 1 &&
          const {
            'in',
            'out',
            'inout',
            'variadic',
          }.contains(words[n].toLowerCase())) {
        n++;
      }
      final hasDefault = RegExp(
        r'\bdefault\b|:?=',
        caseSensitive: false,
      ).hasMatch(t);
      params[words[n].replaceAll('"', '')] = hasDefault;
    }
    out.add(FunctionDef(m.group(1)!.toLowerCase(), params));
  }
  return out;
}

/// What the file says about itself, or null when it has no apps line in its
/// first eight lines.
String? appsLine(List<String> lines) {
  for (final l in lines.take(8)) {
    if (appsLinePattern.hasMatch(l)) return l;
  }
  return null;
}

/// The findings for one migration. [earlier] holds the function definitions
/// of the migrations before it (name -> every parameter list seen).
List<String> appsFindings(
  String fileName,
  String sql, {
  Map<String, List<Map<String, bool>>> earlier = const {},
}) {
  final lines = sql.split('\n');
  final line = appsLine(lines);
  if (line == null) return ['$fileName: no `-- apps:` line in its header'];
  final body = stripSqlComments(sql);
  final found = <String>[];
  if (line.contains('additive')) {
    final defs = functionDefs(sql);
    final recreated = {for (final d in defs) d.name};
    // A function dropped and created again in the same file is the
    // documented way to add a defaulted parameter (two overloads would make
    // every call ambiguous); its new parameter list is judged below.
    final hit = body.split('\n').where(_dropsOrRenames.hasMatch).where((l) {
      final m = _dropFunction.firstMatch(l);
      return m == null || !recreated.contains(m.group(1)!.toLowerCase());
    }).toList();
    if (hit.isNotEmpty) {
      found.add(
        '$fileName: says additive but drops or renames: ${hit.first.trim()}',
      );
    }
    for (final d in defs) {
      final olds = earlier[d.name];
      if (olds == null || olds.isEmpty) continue;
      // Compatible with one earlier list: every old parameter is still
      // there, one an old call could omit still has its default, and every
      // new one has a default.
      final compatible = olds.any(
        (o) =>
            o.keys.every(d.params.containsKey) &&
            o.entries.every((e) => !e.value || d.params[e.key]!) &&
            d.params.entries.every((e) => o.containsKey(e.key) || e.value),
      );
      if (!compatible) {
        found.add(
          '$fileName: says additive but changes the parameters of '
          '${d.name}(${d.params.keys.join(', ')}) without defaulting the new '
          'ones, keeping the old ones and their defaults; a changed signature is a new '
          'function, or the line is `needs app at least N`',
        );
      }
    }
  }
  final breaks = RegExp(r'breaks apps below (\d+)').firstMatch(line);
  if (breaks != null) {
    final raises = RegExp(
      r'deskilo_app_floor\s*\(\s*\)[\s\S]*?select\s+' +
          breaks.group(1)! +
          r'\b',
      caseSensitive: false,
    );
    if (!RegExp(
          r'create\s+or\s+replace\s+function\s+public\.deskilo_app_floor',
          caseSensitive: false,
        ).hasMatch(body) ||
        !raises.hasMatch(body)) {
      found.add(
        '$fileName: says breaks apps below ${breaks.group(1)} but does not '
        'raise deskilo_app_floor() to ${breaks.group(1)} in the same file',
      );
    }
  }
  return found;
}

/// Folds the functions of one migration into [earlier].
void rememberFunctions(
  Map<String, List<Map<String, bool>>> earlier,
  String sql,
) {
  for (final d in functionDefs(sql)) {
    final list = earlier.putIfAbsent(d.name, () => []);
    if (!list.any((p) => p.keys.join(',') == d.params.keys.join(','))) {
      list.add(d.params);
    }
  }
}
