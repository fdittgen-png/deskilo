// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2522 (F3 of #2519) — the feature structure, proved from the code.
//
//   dart run tool/feature_audit.dart            # a short Markdown summary
//   dart run tool/feature_audit.dart --json     # the full deterministic report
//   dart run tool/feature_audit.dart --check    # exit 1 unless the baseline matches
//   dart run tool/feature_audit.dart --baseline # rewrite the findings baseline
//
// Reads `lib/` with the same parser rule as `tool/code_health.dart`: a file the
// parser rejects fails the run (exit 1), it is never audited as if it were
// whole. Re-proves nothing that a test already pins (process homes, acyclic
// `requires`, registry/SQL drift): it reports what those tests do not see.
//
// Client gate spellings (found by grep on master, the exact list):
//   <x>.contains(WorkspaceFeature.f)        features / enabledFeatures sets
//   featureEnabled(WorkspaceFeature.f)      route_access, route_env, facts
//   isFeatureEnabled(WorkspaceFeature.f)    helpers
//   on(WorkspaceFeature.f), _on(...)        screen-local helpers over the same set
//   feature: WorkspaceFeature.f             a named `feature:` / `features: [..]`
//                                           argument (help tips, routes, tabs)
// Server gate spellings, in `supabase/migrations/*.sql`:
//   feature_effective(<ws>, 'key')          and feature_effective_in(<flags>, 'key')
// The LATEST definition of each function wins (an older body no longer
// exists); policy statements outside a function body are read from every file.
//
// Findings:
//   deadFlags              no client gate and no server gate anywhere
//   unregisteredServerKeys a server gate on a key the registry does not have
//   doubleGates            a gate on B nested inside a gate on A (an `if`, a
//                          collection-if, a conditional, `a && b`) where
//                          neither is in the other's `requires` chain: a
//                          hypothesis that B should require A, never a verdict
// Information, not ratcheted:
//   serverOnlyFlags, platformDefaultOn, singleCapabilitySubprocesses and the
//   errors of validateProcessRegistry.
//
// NOT detected: "the surrounding screen is owned by feature B and A is not in
// B's chain" needs a screen-to-feature ownership map that does not exist; only
// the nested form is found, and the human review of #2522 step 2 adds the rest.
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_process.dart';

import 'code_health.dart' show isMeasured;

const String baselinePath = 'docs/design/FEATURE_AUDIT_BASELINE.json';

/// The registry facts the audit needs, as plain data: feature name -> the
/// name it requires (or null). Fixtures build their own.
class AuditRegistry {
  const AuditRegistry(this.requires);
  final Map<String, String?> requires;

  Set<String> get keys => requires.keys.toSet();

  /// Every ancestor of [feature], nearest first.
  List<String> chain(String feature) {
    final out = <String>[];
    var at = requires[feature];
    while (at != null && !out.contains(at)) {
      out.add(at);
      at = requires[at];
    }
    return out;
  }

  bool related(String a, String b) =>
      chain(a).contains(b) || chain(b).contains(a);
}

/// What one source file gates on.
class FileGates {
  FileGates(this.path);
  final String path;
  final gates = <String>{};

  /// Outer, inner, line - a gate nested inside another gate's guarded part.
  final nested = <({String outer, String inner, int line})>[];
  final errors = <String>[];
}

const _gateCalls = {
  'contains',
  'featureEnabled',
  'isFeatureEnabled',
  'on',
  '_on',
  'isOn',
};

final RegExp _positional = RegExp(r'^WorkspaceFeature\.(\w+)$');
final RegExp _named = RegExp(r'^features?\s*:');
final RegExp _anyFeature = RegExp(r'WorkspaceFeature\.(\w+)');

/// The features a call argument names: `WorkspaceFeature.f`, or everything
/// after a `feature:` / `features:` label. By source text, so the audit does
/// not depend on the analyzer's argument node types, which changed between
/// releases.
List<String> _argFeatures(AstNode arg, {required bool named}) {
  final source = arg.toSource();
  if (!named) {
    final m = _positional.firstMatch(source);
    return m == null ? const [] : [m.group(1)!];
  }
  if (!_named.hasMatch(source)) return const [];
  // The registry's own entries name their feature too (`feature: ...` of a
  // FeatureManifestEntry); that is the definition, not a consumer.
  final call = arg.parent?.parent;
  if (call != null && call.toSource().startsWith('FeatureManifestEntry(')) {
    return const [];
  }
  return [for (final m in _anyFeature.allMatches(source)) m.group(1)!];
}

/// The features [node] itself gates on (not those below an inner function),
/// ignoring negated subtrees: `!contains(A)` guards the absence of A.
Set<String> _positiveGates(AstNode node) {
  final v = _GateFinder();
  node.accept(v);
  return v.found;
}

class _GateFinder extends RecursiveAstVisitor<void> {
  final found = <String>{};

  @override
  void visitPrefixExpression(PrefixExpression node) {
    if (node.operator.type == TokenType.BANG) return;
    super.visitPrefixExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final f = gateOf(node);
    if (f != null) found.add(f);
    super.visitMethodInvocation(node);
  }

  @override
  void visitArgumentList(ArgumentList node) {
    for (final arg in node.arguments) {
      found.addAll(_argFeatures(arg, named: true));
    }
    super.visitArgumentList(node);
  }
}

/// The feature a call gates on, or null.
String? gateOf(MethodInvocation node) {
  if (!_gateCalls.contains(node.methodName.name)) return null;
  for (final arg in node.argumentList.arguments) {
    final f = _argFeatures(arg, named: false);
    if (f.isNotEmpty) return f.first;
  }
  return null;
}

class _Collector extends RecursiveAstVisitor<void> {
  _Collector(this.out, this.lineOf);
  final FileGates out;
  final int Function(int) lineOf;
  final _stack = <String>[];

  void _record(String inner, AstNode at) {
    out.gates.add(inner);
    for (final outer in _stack) {
      if (outer != inner) {
        out.nested.add((outer: outer, inner: inner, line: lineOf(at.offset)));
      }
    }
  }

  void _guarded(Expression condition, void Function() then) {
    final gates = _positiveGates(condition);
    _stack.addAll(gates);
    then();
    _stack.removeRange(_stack.length - gates.length, _stack.length);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final f = gateOf(node);
    if (f != null) _record(f, node);
    super.visitMethodInvocation(node);
  }

  @override
  void visitArgumentList(ArgumentList node) {
    for (final arg in node.arguments) {
      for (final f in _argFeatures(arg, named: true)) {
        _record(f, arg);
      }
    }
    super.visitArgumentList(node);
  }

  @override
  void visitIfStatement(IfStatement node) {
    node.expression.accept(this);
    _guarded(node.expression, () => node.thenStatement.accept(this));
    node.elseStatement?.accept(this);
  }

  @override
  void visitIfElement(IfElement node) {
    node.expression.accept(this);
    _guarded(node.expression, () => node.thenElement.accept(this));
    node.elseElement?.accept(this);
  }

  @override
  void visitConditionalExpression(ConditionalExpression node) {
    node.condition.accept(this);
    _guarded(node.condition, () => node.thenExpression.accept(this));
    node.elseExpression.accept(this);
  }

  @override
  void visitBinaryExpression(BinaryExpression node) {
    if (node.operator.type != TokenType.AMPERSAND_AMPERSAND) {
      super.visitBinaryExpression(node);
      return;
    }
    node.leftOperand.accept(this);
    _guarded(node.leftOperand, () => node.rightOperand.accept(this));
  }
}

/// Parses [source] and returns what it gates on. A parse error is reported
/// in [FileGates.errors].
FileGates gatesOfSource(String path, String source) {
  final out = FileGates(path);
  final result = parseString(
    content: source,
    path: path,
    throwIfDiagnostics: false,
  );
  final lineInfo = result.unit.lineInfo;
  int lineOf(int offset) => lineInfo.getLocation(offset).lineNumber;
  for (final e in result.errors) {
    out.errors.add('$path:${lineOf(e.offset)}: ${e.message}');
  }
  result.unit.accept(_Collector(out, lineOf));
  return out;
}

/// The keys a SQL text gates on.
final RegExp _serverGate = RegExp(
  r"feature_effective(?:_in)?\s*\([^;]*?,\s*'([A-Za-z0-9_]+)'\s*\)",
);

/// function name + argument text -> keys, from the LATEST definition of each
/// function, plus the keys of every statement outside a function body.
({Map<String, Set<String>> byFunction, Set<String> outside}) serverGates(
  Iterable<MapEntry<String, String>> migrationsInOrder,
) {
  final latest = <String, Set<String>>{};
  final outside = <String>{};
  final head = RegExp(
    r'create\s+(?:or\s+replace\s+)?function\s+(?:public\.)?(\w+)\s*\(([^)]*)\)',
    caseSensitive: false,
  );
  for (final migration in migrationsInOrder) {
    final sql = migration.value;
    var cursor = 0;
    final rest = StringBuffer();
    for (final m in head.allMatches(sql)) {
      if (m.start < cursor) continue;
      rest.write(sql.substring(cursor, m.start));
      final tag = RegExp(r'\$(\w*)\$').firstMatch(sql.substring(m.end));
      if (tag == null) {
        cursor = m.start;
        continue;
      }
      final open = m.end + tag.end;
      final close = sql.indexOf(tag.group(0)!, open);
      final end = close < 0 ? sql.length : close + tag.group(0)!.length;
      final id =
          '${m.group(1)}(${m.group(2)!.replaceAll(RegExp(r'\s+'), ' ')})';
      latest[id] = {
        for (final k in _serverGate.allMatches(
          sql.substring(open, close < 0 ? sql.length : close),
        ))
          k.group(1)!,
      };
      cursor = end;
    }
    rest.write(sql.substring(cursor));
    for (final k in _serverGate.allMatches(rest.toString())) {
      outside.add(k.group(1)!);
    }
  }
  latest.removeWhere((_, v) => v.isEmpty);
  return (byFunction: latest, outside: outside);
}

/// The whole audit as plain data.
class AuditReport {
  AuditReport({
    required this.consumers,
    required this.serverGates,
    required this.registry,
    required this.deadFlags,
    required this.unregisteredServerKeys,
    required this.doubleGates,
    required this.serverOnlyFlags,
    required this.platformDefaultOn,
    required this.singleCapabilitySubprocesses,
    required this.processHomeErrors,
  });
  final Map<String, List<String>> consumers;
  final Map<String, List<String>> serverGates;
  final AuditRegistry registry;
  final List<String> deadFlags;
  final List<String> unregisteredServerKeys;
  final List<String> doubleGates;
  final List<String> serverOnlyFlags;
  final List<String> platformDefaultOn;
  final List<String> singleCapabilitySubprocesses;
  final List<String> processHomeErrors;

  /// The ratcheted findings, by kind. Sorted; the baseline holds exactly these.
  Map<String, List<String>> get findings => {
    'deadFlags': deadFlags,
    'doubleGates': doubleGates,
    'unregisteredServerKeys': unregisteredServerKeys,
  };

  Map<String, Object?> toJson() => {
    'format': 1,
    'features': {
      for (final f in registry.keys.toList()..sort())
        f: {
          'consumers': consumers[f] ?? const <String>[],
          'serverGates': serverGates[f] ?? const <String>[],
          'requires': registry.chain(f),
        },
    },
    'findings': findings,
    'information': {
      'serverOnlyFlags': serverOnlyFlags,
      'platformDefaultOn': platformDefaultOn,
      'singleCapabilitySubprocesses': singleCapabilitySubprocesses,
      'processHomeErrors': processHomeErrors,
    },
  };
}

/// Builds the report from already-read inputs, so a fixture can drive it.
AuditReport audit({
  required AuditRegistry registry,
  required List<FileGates> files,
  required Map<String, Set<String>> serverByFunction,
  required Set<String> serverOutside,
  Set<String> platformDefaultOn = const {},
  List<String> singleCapabilitySubprocesses = const [],
  List<String> processHomeErrors = const [],
}) {
  final consumers = <String, Set<String>>{};
  final pairs = <String>{};
  for (final f in files) {
    for (final g in f.gates) {
      consumers.putIfAbsent(g, () => {}).add(f.path);
    }
    for (final n in f.nested) {
      if (registry.requires.containsKey(n.outer) &&
          registry.requires.containsKey(n.inner) &&
          !registry.related(n.outer, n.inner)) {
        pairs.add('${n.outer}>${n.inner}@${f.path}');
      }
    }
  }
  final server = <String, Set<String>>{};
  for (final e in serverByFunction.entries) {
    for (final k in e.value) {
      server.putIfAbsent(k, () => {}).add(e.key.split('(').first);
    }
  }
  final serverKeys = {...server.keys, ...serverOutside};
  List<String> sorted(Iterable<String> it) => it.toList()..sort();
  final keys = registry.keys;
  return AuditReport(
    consumers: {for (final e in consumers.entries) e.key: sorted(e.value)},
    serverGates: {
      for (final k in serverKeys) k: sorted(server[k] ?? const <String>{}),
    },
    registry: registry,
    deadFlags: sorted(
      keys.where((k) => !consumers.containsKey(k) && !serverKeys.contains(k)),
    ),
    unregisteredServerKeys: sorted(serverKeys.where((k) => !keys.contains(k))),
    doubleGates: sorted(pairs),
    serverOnlyFlags: sorted(
      keys.where((k) => !consumers.containsKey(k) && serverKeys.contains(k)),
    ),
    platformDefaultOn: sorted(platformDefaultOn),
    singleCapabilitySubprocesses: sorted(singleCapabilitySubprocesses),
    processHomeErrors: processHomeErrors,
  );
}

/// The registry of the running app.
AuditRegistry appRegistry() => AuditRegistry({
  for (final e in featureManifest.entries) e.key.name: e.value.requires?.name,
});

/// Audits the working tree. Returns null, after printing them, when a file
/// has parse errors.
AuditReport? auditTree({String root = '.'}) {
  final files = <FileGates>[];
  final lib = Directory('$root/lib');
  final paths = [
    for (final f in lib.listSync(recursive: true).whereType<File>())
      if (isMeasured(f.path.replaceAll(r'\', '/')))
        f.path.replaceAll(r'\', '/'),
  ]..sort();
  var failed = false;
  for (final p in paths) {
    final rel = p.startsWith('$root/') ? p.substring(root.length + 1) : p;
    final g = gatesOfSource(rel, File(p).readAsStringSync());
    for (final e in g.errors) {
      stderr.writeln('PARSE ERROR $e');
      failed = true;
    }
    files.add(g);
  }
  if (failed) return null;
  final migrations = [
    for (final f in Directory(
      '$root/supabase/migrations',
    ).listSync().whereType<File>().where((f) => f.path.endsWith('.sql')))
      f,
  ]..sort((a, b) => a.path.compareTo(b.path));
  final sql = serverGates([
    for (final f in migrations) MapEntry(f.path, f.readAsStringSync()),
  ]);
  return audit(
    registry: appRegistry(),
    files: files,
    serverByFunction: sql.byFunction,
    serverOutside: sql.outside,
    platformDefaultOn: {
      for (final e in featureManifest.values)
        if (e.tier == FeatureTier.platform && e.defaultOn) e.feature.name,
    },
    singleCapabilitySubprocesses: [
      for (final p in workspaceProcesses)
        for (final s in p.subprocesses)
          if (s.capabilities.length == 1) '${p.key}/${s.key}',
    ],
    processHomeErrors: validateProcessRegistry(workspaceProcesses),
  );
}

/// The baseline text for [findings]: a reason per entry, kept from [previous].
String baselineText(
  Map<String, List<String>> findings,
  Map<String, Map<String, String>> previous,
) {
  final b = StringBuffer()
    ..writeln('{')
    ..writeln('  "format": 1,');
  final kinds = findings.keys.toList()..sort();
  for (var i = 0; i < kinds.length; i++) {
    final kind = kinds[i];
    b.writeln('  ${jsonEncode(kind)}: {');
    final items = findings[kind]!;
    for (var j = 0; j < items.length; j++) {
      final reason = previous[kind]?[items[j]] ?? 'UNREVIEWED';
      b.writeln(
        '    ${jsonEncode(items[j])}: ${jsonEncode(reason)}'
        '${j == items.length - 1 ? '' : ','}',
      );
    }
    b.writeln('  }${i == kinds.length - 1 ? '' : ','}');
  }
  b.writeln('}');
  return b.toString();
}

Map<String, Map<String, String>> readBaseline(String text) {
  final json = jsonDecode(text) as Map<String, dynamic>;
  return {
    for (final e in json.entries)
      if (e.value is Map)
        e.key: {
          for (final r in (e.value as Map).entries)
            r.key as String: r.value as String,
        },
  };
}

/// What differs between the findings and the baseline; empty when equal and
/// every baseline entry carries a reviewed reason.
List<String> baselineDrift(
  Map<String, List<String>> findings,
  Map<String, Map<String, String>> baseline,
) {
  final out = <String>[];
  for (final kind in findings.keys) {
    final held = baseline[kind] ?? const <String, String>{};
    for (final f in findings[kind]!) {
      if (!held.containsKey(f)) {
        out.add(
          '$kind: NEW $f - fix it, or review it and add it to '
          '$baselinePath with a reason',
        );
      }
    }
    for (final entry in held.entries) {
      if (!findings[kind]!.contains(entry.key)) {
        out.add(
          '$kind: GONE ${entry.key} - delete its line from '
          '$baselinePath (`dart run tool/feature_audit.dart --baseline`)',
        );
      } else if (entry.value.trim().isEmpty || entry.value == 'UNREVIEWED') {
        out.add('$kind: ${entry.key} has no reviewed reason');
      }
    }
  }
  return out..sort();
}

String summary(AuditReport r) {
  final b = StringBuffer()
    ..writeln('# Feature audit (#2522)')
    ..writeln()
    ..writeln(
      '${r.registry.keys.length} features, '
      '${r.consumers.length} gated by client code, '
      '${r.serverGates.length} by the server.',
    )
    ..writeln();
  void list(String title, List<String> items) {
    b.writeln('## $title (${items.length})');
    for (final i in items) {
      b.writeln('- $i');
    }
    b.writeln();
  }

  list('Dead flags', r.deadFlags);
  list('Server gates on unregistered keys', r.unregisteredServerKeys);
  list('Nested double gates (candidates)', r.doubleGates);
  list('Gated by the server only', r.serverOnlyFlags);
  b
    ..writeln(
      'Platform tier, default on: ${r.platformDefaultOn.length} '
      '(information, see --json)',
    )
    ..writeln();
  list('Subprocesses with one capability', r.singleCapabilitySubprocesses);
  list('Process-home errors', r.processHomeErrors);
  return b.toString();
}

int run(List<String> args) {
  final report = auditTree();
  if (report == null) {
    stderr.writeln(
      'a file the parser rejects is not audited as if it were whole',
    );
    return 1;
  }
  if (args.contains('--json')) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(report.toJson()));
    return 0;
  }
  if (args.contains('--check')) {
    final drift = baselineDrift(
      report.findings,
      readBaseline(File(baselinePath).readAsStringSync()),
    );
    for (final line in drift) {
      stderr.writeln(line);
    }
    return drift.isEmpty ? 0 : 1;
  }
  if (args.contains('--baseline')) {
    final file = File(baselinePath);
    final previous = file.existsSync()
        ? readBaseline(file.readAsStringSync())
        : const <String, Map<String, String>>{};
    file.writeAsStringSync(baselineText(report.findings, previous));
    stdout.writeln('wrote $baselinePath');
    return 0;
  }
  stdout.write(summary(report));
  return 0;
}

void main(List<String> args) => exitCode = run(args);
