// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3731 (K4) — what an app calls on its installation: the functions it calls
// with the parameter names it sends, and the columns it reads and writes on
// each table. Extracted from the source by its syntax alone (no resolution),
// so the same code reads a release tag's tree and today's.
//
// A call whose function or table name is not a string literal cannot be
// read from the syntax. Its file names it instead, in a comment on the call
// or the line above it:
//   // consumer-contract: fn_one, fn_two
// An unnamed one is listed in [ConsumerContract.unresolved], and the lint
// fails on it, so a call never leaves the contract silently.
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// One function the app calls: the parameter names it may send. Null when a
/// call sends a map the syntax cannot read: then only the function's
/// existence is claimed.
class CalledFunction {
  CalledFunction(this.name);
  final String name;
  final Set<String> params = {};
  bool paramsKnown = true;

  /// The app reads an installation without this function as an answer
  /// (`isMissingFunction` beside the call): its absence breaks nothing.
  bool get optional => calls > 0 && calls == tolerant;
  int calls = 0;
  int tolerant = 0;
}

/// One table or view the app reads or writes, and the columns it names.
/// [allColumns] is true when it selects `*`: then only the table is claimed.
class TouchedTable {
  TouchedTable(this.name);
  final String name;
  final Set<String> columns = {};
  bool allColumns = false;
}

class ConsumerContract {
  final Map<String, CalledFunction> functions = {};

  /// The functions every call of which tolerates their absence.
  Iterable<String> get optional =>
      functions.values.where((f) => f.optional).map((f) => f.name);
  final Map<String, TouchedTable> tables = {};

  /// `path:line` of a call whose name is not a literal and that no
  /// `consumer-contract:` comment names.
  final List<String> unresolved = [];

  /// The JSON the repository commits: sorted, so a diff shows a change.
  Map<String, Object?> toJson({String? source}) => {
    'format': 'deskilo.consumer-contract',
    'version': 1,
    'source': ?source,
    'functions': {
      for (final f
          in (functions.values.toList()
            ..sort((a, b) => a.name.compareTo(b.name))))
        f.name: f.paramsKnown ? (f.params.toList()..sort()) : null,
    },
    'optional': (optional.toList()..sort()),
    'tables': {
      for (final t
          in (tables.values.toList()..sort((a, b) => a.name.compareTo(b.name))))
        t.name: t.allColumns ? null : (t.columns.toList()..sort()),
    },
  };
}

final _declared = RegExp(r'consumer-contract:\s*([a-z0-9_,\s]+)');

/// The names the server defines, read from its migrations: a call through
/// a helper (`_call(fn, params)`) is attributed to every string in its file
/// that names one of them.
class ServerNames {
  ServerNames(this.functions, this.tables);
  final Set<String> functions;
  final Set<String> tables;

  static final _fn = RegExp(
    r'create\s+(?:or\s+replace\s+)?function\s+public\.([a-z0-9_]+)\s*\(',
    caseSensitive: false,
  );
  static final _rel = RegExp(
    r'create\s+(?:or\s+replace\s+)?(?:materialized\s+)?(?:table|view)\s+(?:if\s+not\s+exists\s+)?public\.([a-z0-9_]+)',
    caseSensitive: false,
  );

  /// Reads every `create function public.x` and `create table|view
  /// public.x` from [migrations] (the SQL of each file).
  factory ServerNames.fromMigrations(Iterable<String> migrations) {
    final fns = <String>{};
    final rels = <String>{};
    for (final sql in migrations) {
      fns.addAll(_fn.allMatches(sql).map((m) => m.group(1)!.toLowerCase()));
      rels.addAll(_rel.allMatches(sql).map((m) => m.group(1)!.toLowerCase()));
    }
    return ServerNames(fns, rels);
  }
}

/// Adds what [source] (the file at [path]) calls to [into].
void extractInto(
  ConsumerContract into,
  String path,
  String source, {
  ServerNames? server,
}) {
  final unit = parseString(content: source, throwIfDiagnostics: false).unit;
  final lines = source.split('\n');
  final collector = _Collector(into, path, lines, unit.lineInfo.getLocation);
  unit.accept(collector);
  if (collector.pendingRpc.isEmpty && collector.pendingFrom.isEmpty) return;
  // A call whose name the syntax does not show: the names this file spells
  // that the server defines are what it calls.
  final literals = _Literals();
  unit.accept(literals);
  var fnFound = false;
  var relFound = false;
  for (final lit in literals.found) {
    final v = lit.value;
    if (collector.pendingRpc.isNotEmpty &&
        (server?.functions.contains(v) ?? false)) {
      fnFound = true;
      final f = into.functions.putIfAbsent(v, () => CalledFunction(v))
        ..calls += 1;
      // `_call('fn', {'p_a': ..})`: the map beside the name is its params.
      final parent = lit.parent;
      final map = parent is ArgumentList
          ? parent.arguments
                .map((a) => a.argumentExpression)
                .whereType<SetOrMapLiteral>()
                .firstOrNull
          : null;
      final keys = map == null ? null : collector.literalKeys(map);
      if (keys == null) {
        f.paramsKnown = false;
      } else {
        f.params.addAll(keys);
      }
    }
    if (collector.pendingFrom.isNotEmpty &&
        (server?.tables.contains(v) ?? false)) {
      relFound = true;
      into.tables.putIfAbsent(v, () => TouchedTable(v)).allColumns = true;
    }
  }
  if (!fnFound) into.unresolved.addAll(collector.pendingRpc);
  if (!relFound) into.unresolved.addAll(collector.pendingFrom);
}

class _Literals extends RecursiveAstVisitor<void> {
  final found = <SimpleStringLiteral>[];
  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) => found.add(node);
}

class _Collector extends RecursiveAstVisitor<void> {
  _Collector(this.into, this.path, this.lines, this.locate);
  final ConsumerContract into;
  final String path;
  final List<String> lines;
  final dynamic Function(int) locate;

  /// `path:line` of calls whose name the syntax does not show, resolved
  /// after the visit (see [extractInto]).
  final pendingRpc = <String>[];
  final pendingFrom = <String>[];

  int _line(AstNode n) => (locate(n.offset) as dynamic).lineNumber as int;

  /// Names declared by a `consumer-contract:` comment on the call's first
  /// line or the line above it.
  List<String>? _declaredAt(AstNode n) {
    final line = _line(n);
    for (final i in [line - 1, line - 2]) {
      if (i < 0 || i >= lines.length) continue;
      final m = _declared.firstMatch(lines[i]);
      if (m != null) {
        return m
            .group(1)!
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
    }
    return null;
  }

  /// A public-network operation spec names its server object in a named
  /// argument (`rpc: 'fn'`, `relation: 'view'`); its call sites read
  /// `spec.rpc!` / `spec.relation!`, which [_bySpec] accepts.
  @override
  void visitNamedArgument(NamedArgument node) {
    final e = node.argumentExpression;
    if (e is SimpleStringLiteral) {
      switch (node.name.lexeme) {
        case 'rpc':
          into.functions.putIfAbsent(e.value, () => CalledFunction(e.value))
            ..paramsKnown = false
            ..calls += 1;
        case 'relation':
          into.tables
                  .putIfAbsent(e.value, () => TouchedTable(e.value))
                  .allColumns =
              true;
      }
    }
    super.visitNamedArgument(node);
  }

  /// Whether the function around [node] reads a missing function as an
  /// answer: it names `isMissingFunction`.
  static bool _toleratesAbsence(AstNode node) {
    AstNode? up = node.parent;
    while (up != null && up is! FunctionBody) {
      up = up.parent;
    }
    return up != null && up.toSource().contains('isMissingFunction');
  }

  static bool _bySpec(Expression e) =>
      RegExp(r'\.(rpc|relation)!?$').hasMatch(e.toSource());

  @override
  void visitMethodInvocation(MethodInvocation node) {
    switch (node.methodName.name) {
      case 'rpc':
        _rpc(node);
      case 'from':
        _from(node);
    }
    super.visitMethodInvocation(node);
  }

  void _rpc(MethodInvocation node) {
    final args = node.argumentList.arguments;
    if (args.isEmpty) return;
    final first = args.first.argumentExpression;
    final names = first is SimpleStringLiteral
        ? [first.value]
        : _declaredAt(node);
    if (names == null) {
      if (!_bySpec(first)) pendingRpc.add('$path:${_line(node)}');
      return;
    }
    final params = args
        .whereType<NamedArgument>()
        .where((a) => a.name.lexeme == 'params')
        .map((a) => a.argumentExpression)
        .firstOrNull;
    final tolerant = _toleratesAbsence(node);
    for (final name in names) {
      final f = into.functions.putIfAbsent(name, () => CalledFunction(name));
      f.calls++;
      if (tolerant) f.tolerant++;
      if (params == null) continue;
      final keys = literalKeys(params);
      if (keys == null) {
        f.paramsKnown = false;
      } else {
        f.params.addAll(keys);
      }
    }
  }

  void _from(MethodInvocation node) {
    // Only a Supabase query builder: `x.from('t')` with one string argument,
    // never `Stream.from`, `List.from` or similar constructors' calls.
    final target = node.target;
    if (target is SimpleIdentifier && RegExp(r'^[A-Z]').hasMatch(target.name)) {
      return;
    }
    // Storage buckets (`client.storage.from('b')`) are not tables.
    if (target != null && target.toSource().endsWith('storage')) return;
    final args = node.argumentList.arguments;
    if (args.length != 1) return;
    final first = args.first.argumentExpression;
    final names = first is SimpleStringLiteral
        ? [first.value]
        : first is StringLiteral
        ? null
        : _declaredAt(node);
    if (names == null) {
      if (first is! StringLiteral && !_bySpec(first)) {
        pendingFrom.add('$path:${_line(node)}');
      }
      return;
    }
    final tables = [
      for (final n in names) into.tables.putIfAbsent(n, () => TouchedTable(n)),
    ];
    // Walk up the chain: from('t').select('a,b').eq('c', ...) ...
    AstNode? up = node.parent;
    while (up is MethodInvocation || up is PropertyAccess) {
      if (up is MethodInvocation) _chained(up, tables);
      up = up?.parent;
    }
  }

  void _chained(MethodInvocation call, List<TouchedTable> tables) {
    final args = [
      for (final a in call.argumentList.arguments)
        if (a is! NamedArgument) a.argumentExpression,
    ];
    final name = call.methodName.name;
    void add(Iterable<String> cols) {
      for (final t in tables) {
        t.columns.addAll(cols);
      }
    }

    switch (name) {
      case 'select':
        final first = args.firstOrNull;
        if (first == null) {
          for (final t in tables) {
            t.allColumns = true;
          }
        } else if (first is SimpleStringLiteral) {
          final cols = selectColumns(first.value);
          if (cols == null) {
            for (final t in tables) {
              t.allColumns = true;
            }
          } else {
            add(cols);
          }
        }
      case 'insert' || 'update' || 'upsert':
        final first = args.firstOrNull;
        if (first != null) add(literalKeys(first) ?? const []);
      case 'eq' ||
          'neq' ||
          'gt' ||
          'gte' ||
          'lt' ||
          'lte' ||
          'is_' ||
          'inFilter' ||
          'order' ||
          'like' ||
          'ilike' ||
          'contains':
        final first = args.firstOrNull;
        if (first is SimpleStringLiteral && _isColumn(first.value)) {
          add([first.value]);
        }
    }
  }

  /// String keys of a map literal (also inside a list literal of maps), or
  /// null when the syntax does not show them.
  Set<String>? literalKeys(Expression e) {
    if (e is SetOrMapLiteral) {
      final keys = <String>{};
      for (final el in e.elements) {
        if (el is MapLiteralEntry && el.key is SimpleStringLiteral) {
          keys.add((el.key as SimpleStringLiteral).value);
        } else if (el is MapLiteralEntry) {
          return null;
        }
        // Spreads and ifs: keep the literal keys, the rest is unknown.
        if (el is SpreadElement) return null;
        if (el is IfElement) {
          final inner = el.thenElement;
          if (inner is MapLiteralEntry && inner.key is SimpleStringLiteral) {
            keys.add((inner.key as SimpleStringLiteral).value);
          }
        }
      }
      return keys;
    }
    if (e is ListLiteral) {
      final keys = <String>{};
      for (final el in e.elements) {
        if (el is! Expression) return null;
        final k = literalKeys(el);
        if (k == null) return null;
        keys.addAll(k);
      }
      return keys;
    }
    return null;
  }
}

bool _isColumn(String s) => RegExp(r'^[a-z_][a-z0-9_]*$').hasMatch(s);

/// The plain columns a PostgREST select string names, or null when it
/// selects `*`. Embedded resources (`rel(...)`) are skipped; an alias
/// (`label:col`) and a cast (`col::text`) name `col`.
Set<String>? selectColumns(String select) {
  final cols = <String>{};
  var depth = 0;
  final buf = StringBuffer();
  void flush() {
    var part = buf.toString().trim();
    buf.clear();
    if (part.isEmpty) return;
    if (part.contains('(')) return; // an embedded resource
    if (part.contains(':') && !part.contains('::')) {
      part = part.substring(part.indexOf(':') + 1);
    }
    part = part.split('::').first.split('->').first.trim();
    if (part == '*') {
      cols.add('*');
      return;
    }
    if (_isColumn(part)) cols.add(part);
  }

  for (final ch in select.split('')) {
    if (ch == '(') depth++;
    if (ch == ')') depth--;
    if (ch == ',' && depth == 0) {
      flush();
    } else {
      buf.write(ch);
    }
  }
  flush();
  return cols.contains('*') ? null : cols;
}
