// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2491 (C1 of #2490) — the code-health measurement, reproducible from a
// commit.
//
//   dart run tool/code_health.dart lib out.json     per-file and per-function metrics
//   dart run tool/code_health.dart --baseline       rewrite docs/design/CODE_HEALTH_BASELINE.json
//                                                   and docs/design/CODE_HEALTH.md
//   dart run tool/code_health.dart --hotspots       churn x cognitive complexity
//   dart run tool/code_health.dart --cycles         feature pairs that import each other
//   dart run tool/code_health.dart --check          the ratchet of test/lint/code_health_test.dart
//
// Syntactic AST (`package:analyzer`'s `parseString`, no type resolution):
// cyclomatic and cognitive complexity here are this tool's own
// approximations — a ranking and a trend, not a CodeScene score. The rules
// are those of the reference script measured in #2490:
//
//   cyclomatic  1 + if / for / while / do / catch / ?: / if- and for-elements
//               / each `&&` `||` `??` / each `case` of a switch
//   cognitive   +1 per branch plus the current nesting; `else` +1; a run of
//               the same `&&`/`||` counts once; an `else if` adds 1 and no
//               nesting of its own; `switch` +1 plus nesting
//   nesting     if/else bodies, loops, switch, catch, ?:, collection
//               elements and every closure
//
// A function is identified by file + enclosing type + name + parameter
// signature, so a rename or a move is a NEW function (test/lint/code_health_test.dart).
// A file the parser reports an error for is a failure, never a smaller
// measurement.

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'layering/analysis.dart' as layering;

/// The limits a function must stay under (the baseline header repeats them).
const int cognitiveLimit = 30;
const int cyclomaticLimit = 25;
const int lengthLimit = 150;
const int parameterLimit = 7;

/// The extra bands the epic reports; informational totals only.
const int cyclomaticBand = 9;
const int cognitiveBand = 15;
const int parameterBand = 5;

/// Defaults of `--hotspots`: commits since a date, and a cognitive floor.
const String hotspotSince = '2026-07-01';
const int hotspotCommits = 15;
const int hotspotCognitive = 30;

const String baselinePath = 'docs/design/CODE_HEALTH_BASELINE.json';
const String summaryPath = 'docs/design/CODE_HEALTH.md';

/// One measured function.
class FunctionHealth {
  FunctionHealth({
    required this.id,
    required this.line,
    required this.length,
    required this.cyclomatic,
    required this.cognitive,
    required this.nesting,
    required this.parameters,
  });

  /// `path#Type.name(signature)`; `path#name(signature)` at top level.
  final String id;
  final int line;
  final int length;
  final int cyclomatic;
  final int cognitive;
  final int nesting;
  final int parameters;

  bool get overLimit =>
      cognitive >= cognitiveLimit ||
      cyclomatic >= cyclomaticLimit ||
      length >= lengthLimit ||
      parameters >= parameterLimit;

  Map<String, Object?> toJson() => {
        'id': id,
        'line': line,
        'len': length,
        'cyc': cyclomatic,
        'cog': cognitive,
        'nest': nesting,
        'params': parameters,
      };
}

/// One measured file.
class FileHealth {
  FileHealth({
    required this.path,
    required this.loc,
    required this.isPart,
    required this.functions,
    required this.errors,
  });

  final String path;

  /// Non-blank lines that are not `//` comments.
  final int loc;
  final bool isPart;
  final List<FunctionHealth> functions;

  /// Parser diagnostics: any entry makes the whole run fail.
  final List<String> errors;

  int _max(int Function(FunctionHealth f) of) =>
      functions.fold(0, (m, f) => of(f) > m ? of(f) : m);

  int get maxCognitive => _max((f) => f.cognitive);
  int get maxCyclomatic => _max((f) => f.cyclomatic);
  int get maxLength => _max((f) => f.length);
  int get maxParameters => _max((f) => f.parameters);
  int get maxNesting => _max((f) => f.nesting);

  int _count(bool Function(FunctionHealth f) test) =>
      functions.where(test).length;

  int get overCognitive => _count((f) => f.cognitive >= cognitiveLimit);
  int get overCyclomatic => _count((f) => f.cyclomatic >= cyclomaticLimit);
  int get overLength => _count((f) => f.length >= lengthLimit);
  int get overParameters => _count((f) => f.parameters >= parameterLimit);

  Map<String, Object?> toJson() => {
        'p': path,
        'loc': loc,
        'part': isPart,
        'fn': functions.length,
        'cog': maxCognitive,
        'cyc': maxCyclomatic,
        'len': maxLength,
        'params': maxParameters,
        'nest': maxNesting,
        'over': {
          'cog': overCognitive,
          'cyc': overCyclomatic,
          'len': overLength,
          'params': overParameters,
        },
      };
}

class _Metrics extends RecursiveAstVisitor<void> {
  int cyc = 1, cog = 0, nest = 0, maxNest = 0;

  void _branch() {
    cyc++;
    cog += 1 + nest;
  }

  void _enter(void Function() f) {
    nest++;
    if (nest > maxNest) maxNest = nest;
    f();
    nest--;
  }

  @override
  void visitIfStatement(IfStatement n) {
    // An else-if adds 1 and no nesting of its own.
    final p = n.parent;
    final isElseIf = p is IfStatement && p.elseStatement == n;
    cyc++;
    cog += isElseIf ? 1 : 1 + nest;
    n.expression.accept(this);
    _enter(() => n.thenStatement.accept(this));
    final e = n.elseStatement;
    if (e != null) {
      if (e is! IfStatement) cog++;
      _enter(() => e.accept(this));
    }
  }

  @override
  void visitForStatement(ForStatement n) {
    _branch();
    _enter(() => super.visitForStatement(n));
  }

  @override
  void visitWhileStatement(WhileStatement n) {
    _branch();
    _enter(() => super.visitWhileStatement(n));
  }

  @override
  void visitDoStatement(DoStatement n) {
    _branch();
    _enter(() => super.visitDoStatement(n));
  }

  @override
  void visitSwitchStatement(SwitchStatement n) {
    cog += 1 + nest;
    n.expression.accept(this);
    _enter(() {
      for (final m in n.members) {
        if (m is SwitchCase || m is SwitchPatternCase) cyc++;
        m.accept(this);
      }
    });
  }

  @override
  void visitSwitchExpression(SwitchExpression n) {
    cog += 1 + nest;
    n.expression.accept(this);
    _enter(() {
      for (final c in n.cases) {
        cyc++;
        c.accept(this);
      }
    });
  }

  @override
  void visitCatchClause(CatchClause n) {
    _branch();
    _enter(() => super.visitCatchClause(n));
  }

  @override
  void visitConditionalExpression(ConditionalExpression n) {
    _branch();
    _enter(() => super.visitConditionalExpression(n));
  }

  @override
  void visitIfElement(IfElement n) {
    _branch();
    _enter(() => super.visitIfElement(n));
  }

  @override
  void visitForElement(ForElement n) {
    _branch();
    _enter(() => super.visitForElement(n));
  }

  @override
  void visitBinaryExpression(BinaryExpression n) {
    final t = n.operator.type;
    if (t == TokenType.AMPERSAND_AMPERSAND || t == TokenType.BAR_BAR) {
      cyc++;
      final p = n.parent;
      final same = p is BinaryExpression && p.operator.type == t;
      if (!same) cog++;
    } else if (t == TokenType.QUESTION_QUESTION) {
      cyc++;
    }
    super.visitBinaryExpression(n);
  }

  @override
  void visitFunctionExpression(FunctionExpression n) {
    _enter(() => super.visitFunctionExpression(n));
  }
}

class _Collector extends RecursiveAstVisitor<void> {
  _Collector(this.found);
  final void Function(
    String? type,
    String name,
    FormalParameterList? params,
    FunctionBody body,
    AstNode node,
  ) found;

  String? _typeOf(AstNode node) {
    for (var p = node.parent; p != null; p = p.parent) {
      if (p is ExtensionDeclaration) {
        return p.name?.lexeme ??
            'extension on ${p.onClause?.extendedType.toSource() ?? '?'}';
      }
      if (p is ClassDeclaration) return p.namePart.typeName.lexeme;
      if (p is EnumDeclaration) return p.namePart.typeName.lexeme;
      if (p is ExtensionTypeDeclaration) return p.namePart.typeName.lexeme;
      if (p is MixinDeclaration) return p.name.lexeme;
    }
    return null;
  }

  @override
  void visitMethodDeclaration(MethodDeclaration n) {
    final prefix = n.isGetter
        ? 'get '
        : n.isSetter
            ? 'set '
            : '';
    found(_typeOf(n), '$prefix${n.name.lexeme}', n.parameters, n.body, n);
    super.visitMethodDeclaration(n);
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration n) {
    final named = n.name?.lexeme;
    found(_typeOf(n), named == null ? 'new' : 'new.$named', n.parameters,
        n.body, n);
    super.visitConstructorDeclaration(n);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration n) {
    if (n.parent is CompilationUnit) {
      final prefix = n.isGetter
          ? 'get '
          : n.isSetter
              ? 'set '
              : '';
      found(null, '$prefix${n.name.lexeme}', n.functionExpression.parameters,
          n.functionExpression.body, n);
    }
    super.visitFunctionDeclaration(n);
  }
}

String _signature(FormalParameterList? list) {
  if (list == null) return '';
  final positional = <String>[], optional = <String>[], named = <String>[];
  for (final p in list.parameters) {
    final clause = p.defaultClause;
    var text = p.toSource();
    if (clause != null && text.endsWith(clause.toSource())) {
      text = text.substring(0, text.length - clause.toSource().length);
    }
    text = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    (p.isNamed ? named : p.isOptionalPositional ? optional : positional)
        .add(text);
  }
  return [
    ...positional,
    if (optional.isNotEmpty) '[${optional.join(',')}]',
    if (named.isNotEmpty) '{${named.join(',')}}',
  ].join(',');
}

/// Measures one source text. [path] only labels the result.
FileHealth measureSource(String path, String source) {
  final result = parseString(content: source, path: path, throwIfDiagnostics: false);
  final unit = result.unit;
  final lineInfo = unit.lineInfo;
  int lineOf(int offset) => lineInfo.getLocation(offset).lineNumber;
  final errors = <String>[
    for (final e in result.errors)
      '$path:${lineOf(e.offset)}: ${e.message}',
  ];
  final nonBlank = source.split('\n').where((l) {
    final t = l.trim();
    return t.isNotEmpty && !t.startsWith('//');
  }).length;
  final isPart = RegExp(r'^part of ', multiLine: true).hasMatch(source);
  final functions = <FunctionHealth>[];
  final taken = <String, int>{};
  unit.accept(_Collector((type, name, params, body, node) {
    if (body is EmptyFunctionBody) return;
    final m = _Metrics();
    body.accept(m);
    var id = '$path#${type == null ? '' : '$type.'}$name(${_signature(params)})';
    final seen = taken.update(id, (n) => n + 1, ifAbsent: () => 1);
    if (seen > 1) id = '$id~$seen';
    functions.add(FunctionHealth(
      id: id,
      line: lineOf(node.offset),
      length: lineOf(node.end) - lineOf(node.offset) + 1,
      cyclomatic: m.cyc,
      cognitive: m.cog,
      nesting: m.maxNest,
      parameters: params?.parameters.length ?? 0,
    ));
  }));
  return FileHealth(
    path: path,
    loc: nonBlank,
    isPart: isPart,
    functions: functions,
    errors: errors,
  );
}

/// True for files that are measured: hand-written Dart.
bool isMeasured(String path) =>
    path.endsWith('.dart') &&
    !path.endsWith('.g.dart') &&
    !path.endsWith('.freezed.dart') &&
    !path.contains('app_localizations') &&
    !layering.isGenerated(path);

/// Every measured file under [root], in path order.
List<FileHealth> measureTree(String root) {
  final paths = [
    for (final f in Directory(root).listSync(recursive: true).whereType<File>())
      if (isMeasured(f.path)) f.path.replaceAll(r'\', '/'),
  ]..sort();
  return [for (final p in paths) measureSource(p, File(p).readAsStringSync())];
}

/// One JSON document, an entry per line: header lines, then the two lists.
String _document(
  List<String> header,
  Iterable<String> files,
  Iterable<String> functions,
) =>
    '{\n${header.map((l) => '  $l,\n').join()}'
    '  "files": [\n${files.map((l) => '    $l').join(',\n')}\n  ],\n'
    '  "functions": [\n${functions.map((l) => '    $l').join(',\n')}\n  ]\n'
    '}\n';

/// The deterministic JSON of a measurement: same tree, same bytes.
String measurementJson(List<FileHealth> files) => _document(
      ['"thresholds": ${jsonEncode(thresholdsJson())}'],
      files.map((f) => jsonEncode(f.toJson())),
      [
        for (final f in files)
          for (final fn in f.functions) jsonEncode(fn.toJson()),
      ],
    );

Map<String, int> thresholdsJson() => const {
      'cognitive': cognitiveLimit,
      'cyclomatic': cyclomaticLimit,
      'length': lengthLimit,
      'parameters': parameterLimit,
    };

/// The epic's totals, computed from [files].
Map<String, int> totalsOf(List<FileHealth> files) {
  final fns = [for (final f in files) ...f.functions];
  int n(bool Function(FunctionHealth f) t) => fns.where(t).length;
  return {
    'files': files.length,
    'functions': fns.length,
    'cyclomatic>=$cyclomaticBand': n((f) => f.cyclomatic >= cyclomaticBand),
    'cyclomatic>=$cyclomaticLimit': n((f) => f.cyclomatic >= cyclomaticLimit),
    'cognitive>=$cognitiveBand': n((f) => f.cognitive >= cognitiveBand),
    'cognitive>=$cognitiveLimit': n((f) => f.cognitive >= cognitiveLimit),
    'length>=$lengthLimit': n((f) => f.length >= lengthLimit),
    'parameters>=$parameterBand': n((f) => f.parameters >= parameterBand),
    'parameters>=$parameterLimit': n((f) => f.parameters >= parameterLimit),
    'partOfFiles': files.where((f) => f.isPart).length,
  };
}

/// The baseline file: a snapshot header, the per-file table and the
/// functions the ratchet holds (those at or over a limit), one entry per
/// line and sorted, so two pull requests changing different functions
/// merge cleanly (#2121).
String baselineJson(List<FileHealth> files, {String? sha, String? date}) =>
    _document(
      [
        '"recordedSha": ${jsonEncode(sha)}',
        '"recordedDate": ${jsonEncode(date)}',
        '"thresholds": ${jsonEncode(thresholdsJson())}',
        '"totals": ${jsonEncode(totalsOf(files))}',
      ],
      files.map((f) => jsonEncode(f.toJson())),
      [
        for (final f in files)
          for (final fn in f.functions)
            if (fn.overLimit) jsonEncode(baselineEntry(fn)),
      ],
    );

/// The line the ratchet stores for [fn]; the failing test prints it.
Map<String, Object?> baselineEntry(FunctionHealth fn) => {
      'id': fn.id,
      'cog': fn.cognitive,
      'cyc': fn.cyclomatic,
      'len': fn.length,
      'params': fn.parameters,
    };

/// The summary generated from the baseline alone (not from the tree), so
/// it changes only when the baseline does.
String summaryOf(Map<String, Object?> baseline) {
  final totals = (baseline['totals']! as Map).cast<String, Object?>();
  final th = (baseline['thresholds']! as Map).cast<String, Object?>();
  final fns = (baseline['functions']! as List)
      .cast<Map<String, Object?>>();
  final b = StringBuffer()
    ..writeln('<!-- GENERATED by `dart run tool/code_health.dart --baseline` '
        '— do not edit by hand. -->')
    ..writeln()
    ..writeln('# Code health baseline')
    ..writeln()
    ..writeln('Checkpoint C1 of #2490 / #2491. Measured with '
        '`dart run tool/code_health.dart`: a syntactic AST pass over `lib/` '
        '(no type resolution), so cyclomatic and cognitive complexity are '
        'this tool\'s own approximations — a ranking and a trend. Recorded '
        'at `${baseline['recordedSha']}` on ${baseline['recordedDate']}.')
    ..writeln()
    ..writeln('A function is held by `test/lint/code_health_test.dart` when it '
        'reaches a limit: cognitive ${th['cognitive']}, cyclomatic '
        '${th['cyclomatic']}, length ${th['length']} lines, parameters '
        '${th['parameters']}. Its entry in `CODE_HEALTH_BASELINE.json` may '
        'only fall; any other function must stay under every limit or sit '
        'in `test/lint/code_health_exceptions.txt`.')
    ..writeln()
    ..writeln('## Totals at the recorded commit')
    ..writeln()
    ..writeln('| measure | count |')
    ..writeln('|---|---|');
  for (final e in totals.entries) {
    b.writeln('| ${e.key} | ${e.value} |');
  }
  b
    ..writeln()
    ..writeln('## Worst functions by cognitive complexity (baseline)')
    ..writeln()
    ..writeln('| cognitive | cyclomatic | lines | parameters | function |')
    ..writeln('|---|---|---|---|---|');
  final ranked = [...fns]
    ..sort((a, c) {
      final d = (c['cog']! as int) - (a['cog']! as int);
      return d != 0 ? d : (a['id']! as String).compareTo(c['id']! as String);
    });
  for (final f in ranked.take(25)) {
    b.writeln('| ${f['cog']} | ${f['cyc']} | ${f['len']} | ${f['params']} '
        '| `${(f['id']! as String).split('(').first}` |');
  }
  b.writeln();
  return b.toString();
}

/// Files by non-merge commits since [since], joined with the file's
/// maximum cognitive complexity.
List<({String path, int commits, int cognitive})> hotspots(
  List<FileHealth> files, {
  String since = hotspotSince,
  int minCommits = hotspotCommits,
  int minCognitive = hotspotCognitive,
}) {
  final r = Process.runSync('git',
      ['log', '--since=$since', '--no-merges', '--name-only', '--pretty=format:']);
  if (r.exitCode != 0) {
    throw StateError('git log failed: ${r.stderr}');
  }
  final commits = <String, int>{};
  for (final line in (r.stdout as String).split('\n')) {
    final p = line.trim();
    if (p.isNotEmpty) commits.update(p, (n) => n + 1, ifAbsent: () => 1);
  }
  final out = [
    for (final f in files)
      if ((commits[f.path] ?? 0) >= minCommits && f.maxCognitive >= minCognitive)
        (path: f.path, commits: commits[f.path]!, cognitive: f.maxCognitive),
  ]..sort((a, b) {
      final d = b.commits - a.commits;
      return d != 0 ? d : a.path.compareTo(b.path);
    });
  return out;
}

/// The reciprocal feature pairs, `a <-> b  a->b/b->a imports`, sorted.
List<String> cycles() {
  final counts = layering.crossFeatureImports(
      layering.handWrittenDartFiles('lib/features').toList()
        ..sort((a, b) => a.path.compareTo(b.path)));
  final pairs = layering.reciprocalPairs(counts).toList()..sort();
  return [
    for (final p in pairs)
      () {
        final ends = p.split(' <-> ');
        return '$p  ${counts['${ends[0]} -> ${ends[1]}']}/'
            '${counts['${ends[1]} -> ${ends[0]}']}';
      }(),
  ];
}

/// One function the baseline holds.
class BaselineFunction {
  const BaselineFunction(this.id, this.cognitive, this.cyclomatic, this.length,
      this.parameters);

  factory BaselineFunction.fromJson(Map<String, Object?> j) => BaselineFunction(
        j['id']! as String,
        j['cog']! as int,
        j['cyc']! as int,
        j['len']! as int,
        j['params']! as int,
      );

  final String id;
  final int cognitive;
  final int cyclomatic;
  final int length;
  final int parameters;
}

/// The baseline's held functions by identity.
Map<String, BaselineFunction> baselineFunctions(String json) => {
      for (final e in ((jsonDecode(json) as Map<String, Object?>)['functions']!
              as List)
          .cast<Map<String, Object?>>())
        e['id']! as String: BaselineFunction.fromJson(e),
    };

/// `id -> "#issue reason"` from the reviewed exceptions file. A line is
/// `<function id> | #<issue> | <reason>`; `#` lines are comments.
Map<String, String> parseExceptions(String text) {
  final out = <String, String>{};
  final line = RegExp(r'^(.+?) \| (#\d+) \| (\S.*)$');
  for (final raw in text.split('\n')) {
    final l = raw.trim();
    if (l.isEmpty || l.startsWith('#')) continue;
    final m = line.firstMatch(l);
    if (m == null) {
      throw FormatException('exception line needs "<id> | #<issue> | '
          '<reason>": $l');
    }
    out[m.group(1)!] = '${m.group(2)} ${m.group(3)}';
  }
  return out;
}

/// Every way [current] breaks the ratchet held by [baseline], each with the
/// line to write. Empty means the tree may not get worse.
///
///  * a held function may only stay or fall in each of cognitive,
///    cyclomatic, length and parameters — and when it falls, the baseline
///    falls with it in the same change;
///  * a function the baseline does not hold (new, renamed, extracted,
///    re-signed) must stay under every limit or sit in [exceptions];
///  * a held function that has gone, and an exception that no longer
///    excuses anything, are removed.
List<String> ratchetFailures({
  required Map<String, BaselineFunction> baseline,
  required Iterable<FunctionHealth> current,
  Map<String, String> exceptions = const {},
}) {
  final out = <String>[];
  final seen = <String>{};
  String line(FunctionHealth f) => '    ${jsonEncode(baselineEntry(f))}';
  for (final f in current) {
    seen.add(f.id);
    final held = baseline[f.id];
    final excused = exceptions.containsKey(f.id);
    if (held == null) {
      if (f.overLimit && !excused) {
        out.add('NEW over a limit (cognitive ${f.cognitive}/$cognitiveLimit, '
            'cyclomatic ${f.cyclomatic}/$cyclomaticLimit, '
            'length ${f.length}/$lengthLimit, '
            'parameters ${f.parameters}/$parameterLimit): ${f.id}\n'
            '    A renamed, moved or extracted function is a new one: fix it, '
            'or add "${f.id} | #<issue> | <reason>" to '
            'test/lint/code_health_exceptions.txt');
      }
      if (excused && !f.overLimit) {
        out.add('STALE exception, the function is under every limit: '
            '${f.id}\n    delete its line from '
            'test/lint/code_health_exceptions.txt');
      }
      continue;
    }
    if (excused) {
      out.add('REDUNDANT exception, the baseline already holds: ${f.id}');
    }
    final raised = <String>[
      if (f.cognitive > held.cognitive)
        'cognitive ${held.cognitive}→${f.cognitive}',
      if (f.cyclomatic > held.cyclomatic)
        'cyclomatic ${held.cyclomatic}→${f.cyclomatic}',
      if (f.length > held.length) 'length ${held.length}→${f.length}',
      if (f.parameters > held.parameters)
        'parameters ${held.parameters}→${f.parameters}',
    ];
    if (raised.isNotEmpty) {
      out.add('WORSE, ${raised.join(', ')}: ${f.id}\n'
          '    a held function may only stay or fall');
    } else if (f.cognitive < held.cognitive ||
        f.cyclomatic < held.cyclomatic ||
        f.length < held.length ||
        f.parameters < held.parameters) {
      out.add('IMPROVED, lower its baseline entry: ${f.id}\n'
          '${f.overLimit ? '    replace the line with\n${line(f)}' : '    it is under every limit now: delete its line'}');
    }
  }
  for (final id in baseline.keys) {
    if (!seen.contains(id)) {
      out.add('GONE from the tree, delete its baseline line: $id');
    }
  }
  for (final id in exceptions.keys) {
    if (!seen.contains(id)) {
      out.add('STALE exception, no such function: $id');
    }
  }
  return out..sort();
}

/// Per-file counts over each limit: they may fall, never rise (an
/// exception excuses the function it names). Redundant with the
/// per-function rules unless one of them has a hole; it holds the epic's
/// own figures.
List<String> aggregateFailures({
  required Map<String, BaselineFunction> baseline,
  required Iterable<FileHealth> current,
  Map<String, String> exceptions = const {},
}) {
  Map<String, List<int>> countsOf(Iterable<(String, List<int>)> rows) {
    final m = <String, List<int>>{};
    for (final (path, c) in rows) {
      final t = m.putIfAbsent(path, () => [0, 0, 0, 0]);
      for (var i = 0; i < 4; i++) {
        t[i] += c[i];
      }
    }
    return m;
  }

  List<int> over(int cog, int cyc, int len, int params) => [
        if (cog >= cognitiveLimit) 1 else 0,
        if (cyc >= cyclomaticLimit) 1 else 0,
        if (len >= lengthLimit) 1 else 0,
        if (params >= parameterLimit) 1 else 0,
      ];
  final held = countsOf([
    for (final b in baseline.values)
      (
        b.id.substring(0, b.id.indexOf('#')),
        over(b.cognitive, b.cyclomatic, b.length, b.parameters),
      ),
  ]);
  final now = countsOf([
    for (final f in current)
      for (final fn in f.functions)
        if (!exceptions.containsKey(fn.id))
          (f.path, over(fn.cognitive, fn.cyclomatic, fn.length, fn.parameters)),
  ]);
  const names = ['cognitive', 'cyclomatic', 'length', 'parameters'];
  return [
    for (final e in now.entries)
      for (var i = 0; i < 4; i++)
        if (e.value[i] > (held[e.key]?[i] ?? 0))
          '${e.key}: ${e.value[i]} functions over the ${names[i]} limit, '
              'the baseline holds ${held[e.key]?[i] ?? 0}',
  ]..sort();
}

String? _git(List<String> args) {
  final r = Process.runSync('git', args);
  return r.exitCode == 0 ? (r.stdout as String).trim() : null;
}

/// Prints parse errors and returns false when there are any.
bool reportErrors(List<FileHealth> files) {
  final errors = [for (final f in files) ...f.errors];
  for (final e in errors) {
    stderr.writeln('PARSE ERROR $e');
  }
  if (errors.isNotEmpty) {
    stderr.writeln('${errors.length} parse error(s): a file the parser '
        'rejects is not measured as if it were whole');
  }
  return errors.isEmpty;
}

int run(List<String> args) {
  final flags = args.where((a) => a.startsWith('--')).toList();
  final rest = args.where((a) => !a.startsWith('--')).toList();
  String flag(String name, String fallback) {
    for (final f in flags) {
      if (f.startsWith('--$name=')) return f.substring(name.length + 3);
    }
    return fallback;
  }

  if (flags.contains('--cycles')) {
    cycles().forEach(stdout.writeln);
    return 0;
  }
  final root = rest.isNotEmpty ? rest.first : 'lib';
  final files = measureTree(root);
  if (!reportErrors(files)) return 1;

  if (flags.contains('--check')) {
    // The ratchet of test/lint/code_health_test.dart, without the test runner.
    final base = baselineFunctions(File(baselinePath).readAsStringSync());
    final excused = parseExceptions(
        File('test/lint/code_health_exceptions.txt').readAsStringSync());
    final failures = [
      ...ratchetFailures(
        baseline: base,
        current: [for (final f in files) ...f.functions],
        exceptions: excused,
      ),
      ...aggregateFailures(baseline: base, current: files, exceptions: excused),
    ];
    stdout
      ..writeAll(failures, '\n')
      ..writeln(failures.isEmpty ? 'ratchet holds' : '\n${failures.length} failure(s)');
    return failures.isEmpty ? 0 : 1;
  }
  if (flags.contains('--hotspots')) {
    final list = hotspots(
      files,
      since: flag('since', hotspotSince),
      minCommits: int.parse(flag('commits', '$hotspotCommits')),
      minCognitive: int.parse(flag('cognitive', '$hotspotCognitive')),
    );
    for (final h in list) {
      stdout.writeln('${h.commits}\t${h.cognitive}\t${h.path}');
    }
    stdout.writeln('${list.length} files');
    return 0;
  }
  if (flags.contains('--baseline')) {
    final sha = flag('sha', _git(['rev-parse', 'HEAD']) ?? 'unknown');
    final date =
        flag('date', _git(['show', '-s', '--format=%cs', 'HEAD']) ?? 'unknown');
    final text = baselineJson(files, sha: sha, date: date);
    File(baselinePath)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(text);
    File(summaryPath)
        .writeAsStringSync(summaryOf(jsonDecode(text) as Map<String, Object?>));
    stdout.writeln('wrote $baselinePath and $summaryPath');
    return 0;
  }
  final out = rest.length > 1 ? rest[1] : null;
  final text = measurementJson(files);
  if (out != null) {
    File(out).writeAsStringSync(text);
  }
  final t = totalsOf(files);
  stdout.writeln(t.entries.map((e) => '${e.key}=${e.value}').join(' '));
  return 0;
}

void main(List<String> args) => exitCode = run(args);
