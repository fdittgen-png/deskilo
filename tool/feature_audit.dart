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
//   screenGates            `B>A`: every surface gating on A sits in screens
//                          the route guards of B own, and neither is in the
//                          other's chain (the same hypothesis). The screen-to-
//                          feature map is derived from the code: the GoRoutes
//                          of lib/ (their `RouteAccess(features:)` and
//                          `if (!featureEnabled(f)) return` redirects,
//                          parents included), the classes their builders construct,
//                          the RouteRules that class a path `workspace`, and
//                          the presentation imports of each screen
//                          (`screenOwnership`).
// Information, not ratcheted:
//   routeOwners, serverOnlyFlags, platformDefaultOn,
//   singleCapabilitySubprocesses and the errors of validateProcessRegistry.
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:deskilo/features/workspace/domain/platform_default_reasons.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_process.dart';

import 'code_health.dart' show isMeasured;

const String baselinePath = 'docs/design/FEATURE_AUDIT_BASELINE.json';

/// The features whose default-on has a stated reason (#2519).
final Set<String> _reasonNames = {
  for (final f in platformDefaultReasons.keys) f.name,
};

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

  /// The classes this file declares.
  final classes = <String>{};

  /// The `import` URIs, as written.
  final imports = <String>[];

  /// The `part` URIs, as written.
  final parts = <String>[];

  /// The top-level names this file declares (classes among them).
  final declared = <String>{};

  /// Every simple identifier this file uses.
  final referenced = <String>{};

  /// The `GoRoute`s this file declares, nested ones flattened.
  final routes = <RouteFacts>[];

  /// `RouteRule(pattern, RouteClass.kind)` entries: pattern -> kind.
  final routeRules = <String, String>{};
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
    _structure(node);
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _structure(node);
    super.visitInstanceCreationExpression(node);
  }

  /// A top-level `GoRoute` (its children come with it) or a `RouteRule`.
  void _structure(Expression node) {
    final call = callOf(node);
    if (call == null) return;
    if (call.name == 'GoRoute' && !_insideRoute(node)) {
      out.routes.addAll(routeTree(node, '', const {}));
    } else if (call.name == 'RouteRule') {
      final args = call.args.arguments;
      final kind = args.length == 2
          ? RegExp(r'^RouteClass\.(\w+)$').firstMatch(args[1].toSource())
          : null;
      final pattern = args.isEmpty ? null : args.first;
      if (kind != null && pattern is SimpleStringLiteral) {
        out.routeRules[pattern.value] = kind.group(1)!;
      }
    }
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    out.classes.add(node.namePart.typeName.lexeme);
    out.declared.add(node.namePart.typeName.lexeme);
    super.visitClassDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (node.parent is CompilationUnit) out.declared.add(node.name.lexeme);
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    for (final v in node.variables.variables) {
      out.declared.add(v.name.lexeme);
    }
    super.visitTopLevelVariableDeclaration(node);
  }

  @override
  void visitEnumDeclaration(EnumDeclaration node) {
    out.declared.add(node.namePart.typeName.lexeme);
    super.visitEnumDeclaration(node);
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    out.declared.add(node.name.lexeme);
    super.visitMixinDeclaration(node);
  }

  @override
  void visitExtensionDeclaration(ExtensionDeclaration node) {
    final name = node.name?.lexeme;
    if (name != null) out.declared.add(name);
    super.visitExtensionDeclaration(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    out.referenced.add(node.name);
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitImportDirective(ImportDirective node) {
    final uri = node.uri.stringValue;
    if (uri != null) out.imports.add(uri);
    super.visitImportDirective(node);
  }

  @override
  void visitPartDirective(PartDirective node) {
    final uri = node.uri.stringValue;
    if (uri != null) out.parts.add(uri);
    super.visitPartDirective(node);
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

// ---- (b) a screen owned by feature B gates on feature A -----------------

/// A call by its callee name: `X(...)`, `const X(...)`, `new X.named(...)`.
({String name, ArgumentList args})? callOf(AstNode node) {
  if (node is MethodInvocation && node.target == null) {
    return (name: node.methodName.name, args: node.argumentList);
  }
  if (node is InstanceCreationExpression) {
    final type = node.constructorName.type.toSource().split('<').first;
    return (name: type.split('.').last, args: node.argumentList);
  }
  return null;
}

bool _insideRoute(AstNode node) {
  for (var p = node.parent; p != null; p = p.parent) {
    if (callOf(p)?.name == 'GoRoute') return true;
  }
  return false;
}

/// The expression of the named argument [name] of [args], or null.
AstNode? namedArgument(ArgumentList args, String name) {
  for (final a in args.arguments) {
    if (a is NamedArgument && a.name.lexeme == name) {
      final value = a.childEntities.last;
      return value is AstNode ? value : null;
    }
  }
  return null;
}

/// One registered route: its full path, the features its guard and its
/// parents' guards ask (go_router runs a parent's redirect for a child), and
/// the classes its builder constructs.
class RouteFacts {
  const RouteFacts(this.path, this.owners, this.screens);
  final String path;
  final Set<String> owners;
  final Set<String> screens;
}

/// The features a `redirect:` refuses without: every `RouteAccess(features:
/// [...])` in it, and every `if (!gate(f)) return ...;`. A redirect that
/// only sends elsewhere when features are ON (`/messages` -> `/calendar`)
/// owns nothing.
Set<String> redirectOwners(AstNode? redirect) {
  final out = <String>{};
  redirect?.accept(_RedirectOwners(out));
  return out;
}

class _RedirectOwners extends RecursiveAstVisitor<void> {
  _RedirectOwners(this.out);
  final Set<String> out;

  void _access(AstNode node) {
    final call = callOf(node);
    if (call?.name != 'RouteAccess') return;
    final features = namedArgument(call!.args, 'features');
    if (features == null) return;
    for (final m in _anyFeature.allMatches(features.toSource())) {
      out.add(m.group(1)!);
    }
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    _access(node);
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _access(node);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitIfStatement(IfStatement node) {
    final condition = node.expression;
    final then = node.thenStatement;
    final refuses =
        then is ReturnStatement ||
        (then is Block && then.statements.lastOrNull is ReturnStatement);
    if (refuses &&
        condition is PrefixExpression &&
        condition.operator.type == TokenType.BANG) {
      final operand = condition.operand;
      final f = operand is MethodInvocation ? gateOf(operand) : null;
      if (f != null) out.add(f);
    }
    super.visitIfStatement(node);
  }
}

/// The classes [builder] constructs (`XScreen(...)`), by name.
Set<String> builtClasses(AstNode? builder) {
  final out = <String>{};
  builder?.accept(_BuiltClasses(out));
  return out;
}

class _BuiltClasses extends RecursiveAstVisitor<void> {
  _BuiltClasses(this.out);
  final Set<String> out;

  void _add(AstNode node) {
    final name = callOf(node)?.name;
    if (name != null && RegExp('^[A-Z]').hasMatch(name)) out.add(name);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    _add(node);
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _add(node);
    super.visitInstanceCreationExpression(node);
  }
}

/// [route] (a `GoRoute(...)` call) and its `routes:` children, flattened.
List<RouteFacts> routeTree(
  AstNode route,
  String parentPath,
  Set<String> inherited,
) {
  final call = callOf(route)!;
  final pathArg = namedArgument(call.args, 'path');
  final segment = pathArg is SimpleStringLiteral
      ? pathArg.value
      : '?${pathArg?.toSource()}';
  final path = segment.startsWith('/') || parentPath.isEmpty
      ? segment
      : '${parentPath == '/' ? '' : parentPath}/$segment';
  final owners = {
    ...inherited,
    ...redirectOwners(namedArgument(call.args, 'redirect')),
  };
  final out = [
    RouteFacts(path, owners, {
      ...builtClasses(namedArgument(call.args, 'builder')),
      ...builtClasses(namedArgument(call.args, 'pageBuilder')),
    }),
  ];
  final children = namedArgument(call.args, 'routes');
  if (children is ListLiteral) {
    for (final element in children.elements) {
      if (callOf(element)?.name == 'GoRoute') {
        out.addAll(routeTree(element, path, owners));
      }
    }
  }
  return out;
}

/// The repo-relative file an import of [from] names, or null when it is
/// outside `lib/` (`dart:`, another package).
String? importedFile(String from, String uri) {
  if (uri.startsWith('package:deskilo/')) {
    return 'lib/${uri.substring('package:deskilo/'.length)}';
  }
  if (uri.contains(':')) return null;
  final parts = from.split('/')..removeLast();
  for (final seg in uri.split('/')) {
    if (seg == '..') {
      parts.removeLast();
    } else if (seg != '.') {
      parts.add(seg);
    }
  }
  return parts.join('/');
}

/// `owner>gate`: every client surface of `gate` sits inside screens a guard
/// on `owner` owns, and neither is in the other's `requires` chain. The
/// hypothesis is that `gate` needs `owner` and should say so (`calendarHub`
/// inside the calendar tab was one, #2656), never a verdict. A gate with
/// one surface (`isSurface`) outside such screens (the shell, a route file,
/// `core/`, a screen whose route no feature guards, a `PageSpec` page) is
/// not a candidate.
///
/// The map from screen to feature is derived, not listed: every `GoRoute`
/// of `lib/` with its full path, the features its guard and its parents'
/// guards ask (`redirectOwners`), and the classes its builder constructs;
/// a guard counts when a `RouteRule` classes the path `workspace`. From
/// each screen's file the walk follows `part`s, and `import`s into files
/// under `/presentation/`. An import of a file holding another route's page
/// is followed only when it uses something else that file declares (a sheet,
/// a widget: `showConversationThread` beside `ConversationThreadPage`); one
/// that only names the page is a way there, judged by that page's route
/// (`openMemberPage` building `MemberPage`). A file reached by several
/// routes is owned only by what all their guards share. Of two owners where
/// one requires the other, only the nearer is named.
List<String> screenGates(AuditRegistry registry, List<FileGates> files) =>
    screenOwnership(registry, files).candidates;

/// What each registered route's guard asks, `workspace` routes only, the
/// features sorted (an empty list: no feature owns the route).
Map<String, List<String>> routeOwners(
  AuditRegistry registry,
  List<FileGates> files,
) {
  final rules = {for (final f in files) ...f.routeRules};
  final out = <String, Set<String>>{};
  for (final f in files) {
    for (final r in f.routes) {
      if (rules[r.path] != 'workspace') continue;
      out.putIfAbsent(r.path, () => {}).addAll(r.owners);
    }
  }
  return {
    for (final path in out.keys.toList()..sort())
      path: out[path]!.toList()..sort(),
  };
}

/// Whether a gate in [path] is a place a person meets the feature. The
/// layers that decide or fetch (`domain/`, `application/`, `data/`,
/// `providers/`) gate for a screen that is a surface itself; a catalogue in
/// `domain/` that lists features per setup level shows nothing.
bool isSurface(String path) => !RegExp(
  r'/(domain|application|data|providers)/',
).hasMatch(path);

/// The owner sets per presentation file and the candidates built on them.
({Map<String, Set<String>> owners, List<String> candidates}) screenOwnership(
  AuditRegistry registry,
  List<FileGates> files,
) {
  final byPath = {for (final f in files) f.path: f};
  final declaredIn = <String, Set<String>>{};
  final rules = <String, String>{};
  final routes = <RouteFacts>[];
  for (final f in files) {
    for (final c in f.classes) {
      declaredIn.putIfAbsent(c, () => {}).add(f.path);
    }
    rules.addAll(f.routeRules);
    routes.addAll(f.routes);
  }
  final screens = {for (final r in routes) ...r.screens};
  // A library with its parts: what it declares, and its route screens.
  Iterable<String> library(String path) => [
    path,
    for (final uri in byPath[path]?.parts ?? const <String>[])
      ?importedFile(path, uri),
  ];
  Set<String> offered(String path) => {
    for (final p in library(path)) ...?byPath[p]?.declared,
  }.difference(screens);
  bool holdsScreen(String path) => library(
    path,
  ).any((p) => byPath[p]?.classes.any(screens.contains) ?? false);
  // file -> what every route reaching it asks (intersection).
  final owned = <String, Set<String>>{};
  for (final route in routes) {
    final owners = rules[route.path] == 'workspace'
        ? route.owners.where(registry.requires.containsKey).toSet()
        : <String>{};
    final start = {for (final s in route.screens) ...?declaredIn[s]};
    final seen = <String>{};
    final queue = [...start];
    while (queue.isNotEmpty) {
      final at = queue.removeLast();
      if (!seen.add(at)) continue;
      final file = byPath[at];
      if (file == null) continue;
      for (final uri in file.parts) {
        final next = importedFile(at, uri);
        if (next != null) queue.add(next);
      }
      for (final uri in file.imports) {
        final next = importedFile(at, uri);
        if (next == null || seen.contains(next)) continue;
        if (!next.contains('/presentation/')) continue;
        // An import that only names another route's page is a way there,
        // judged by that route; one that uses a sheet or a widget the
        // file also holds embeds it.
        if (holdsScreen(next) &&
            offered(next).intersection(file.referenced).isEmpty) {
          continue;
        }
        queue.add(next);
      }
    }
    for (final at in seen) {
      final held = owned[at];
      owned[at] = held == null ? {...owners} : held.intersection(owners);
    }
  }
  final consumers = <String, Set<String>>{};
  for (final f in files) {
    if (!isSurface(f.path)) continue;
    for (final g in f.gates) {
      consumers.putIfAbsent(g, () => {}).add(f.path);
    }
  }
  final out = <String>[];
  for (final gate in consumers.keys.toList()..sort()) {
    if (!registry.requires.containsKey(gate)) continue;
    Set<String>? shared;
    for (final file in consumers[gate]!) {
      final here = owned[file] ?? const <String>{};
      shared = shared == null ? {...here} : shared.intersection(here);
    }
    final owners = (shared ?? const <String>{})
        .where((o) => o != gate && !registry.related(o, gate))
        .toSet();
    for (final o in owners.toList()..sort()) {
      // A nearer owner already requires this one: name the nearer.
      if (owners.any((n) => n != o && registry.chain(n).contains(o))) {
        continue;
      }
      out.add('$o>$gate');
    }
  }
  return (owners: owned, candidates: out..sort());
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
    required this.screenGates,
    required this.routeOwners,
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
  final List<String> screenGates;
  final Map<String, List<String>> routeOwners;
  final List<String> serverOnlyFlags;
  final List<String> platformDefaultOn;
  final List<String> singleCapabilitySubprocesses;
  final List<String> processHomeErrors;

  /// The ratcheted findings, by kind. Sorted; the baseline holds exactly these.
  Map<String, List<String>> get findings => {
    'deadFlags': deadFlags,
    'doubleGates': doubleGates,
    'screenGates': screenGates,
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
      'routeOwners': routeOwners,
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
    screenGates: screenGates(registry, files),
    routeOwners: routeOwners(registry, files),
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
  list(
    'Gates inside screens another feature owns (candidates)',
    r.screenGates,
  );
  b
    ..writeln(
      'Workspace routes: ${r.routeOwners.length}, '
      '${r.routeOwners.values.where((o) => o.isEmpty).length} owned by no '
      'feature (information, see --json)',
    )
    ..writeln();
  list('Gated by the server only', r.serverOnlyFlags);
  b
    ..writeln(
      'Platform tier, default on: ${r.platformDefaultOn.length}, '
      '${r.platformDefaultOn.where((f) => !_reasonNames.contains(f)).length} '
      'without a stated reason (platform_default_reasons.dart; '
      'information, see --json)',
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
